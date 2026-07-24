import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/waste_category.dart';

/// One persisted entry in the kiosk's local scan dataset.
///
/// Stored in a Hive box keyed by the image's SHA-256 hex (so identical bytes
/// dedupe naturally). A perceptual hash is stored alongside for fast similarity
/// lookup when a NEW photo of an already-scanned object comes in.
///
/// Serialization notes:
/// - The category is stored as a STABLE string id ([WasteCategory.stableId]),
///   NOT the enum index. The enum declaration order differs from the model
///   class order, so index-based storage was brittle and silently mislabeled
///   data on any reorder.
/// - [labelSource] distinguishes a model guess (`model`) from a human
///   correction (`human`). Human labels are gold for retraining and should be
///   weighted higher downstream.
/// - [synced] is the outbox flag: false means "not yet uploaded to Supabase".
class LocalDatasetEntry {
  final String sha256Hex;
  final int pHash;
  final WasteCategory category;
  final String? itemName;
  final double? confidence;
  final DateTime capturedAt;
  final String imageFileName;
  final String labelSource; // 'model' | 'human'
  final bool synced;

  const LocalDatasetEntry({
    required this.sha256Hex,
    required this.pHash,
    required this.category,
    required this.imageFileName,
    required this.capturedAt,
    this.itemName,
    this.confidence,
    this.labelSource = 'model',
    this.synced = false,
  });

  LocalDatasetEntry copyWith({
    WasteCategory? category,
    String? itemName,
    String? labelSource,
    bool? synced,
  }) {
    return LocalDatasetEntry(
      sha256Hex: sha256Hex,
      pHash: pHash,
      category: category ?? this.category,
      itemName: itemName ?? this.itemName,
      confidence: confidence,
      capturedAt: capturedAt,
      imageFileName: imageFileName,
      labelSource: labelSource ?? this.labelSource,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() => {
        'sha256': sha256Hex,
        'phash': pHash,
        // Stable string id — survives enum reordering. See class doc.
        'label': category.stableId,
        'label_source': labelSource,
        'item_name': itemName,
        'confidence': confidence,
        'image': imageFileName,
        'captured_at': capturedAt.toIso8601String(),
        'synced': synced,
      };

  factory LocalDatasetEntry.fromMap(Map<dynamic, dynamic> map) {
    return LocalDatasetEntry(
      sha256Hex: map['sha256'] as String,
      pHash: map['phash'] as int,
      category: _categoryFromMap(map),
      itemName: map['item_name'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      imageFileName: map['image'] as String,
      capturedAt: DateTime.parse(
        (map['captured_at'] ?? map['created_at']) as String,
      ),
      labelSource: (map['label_source'] as String?) ?? 'model',
      synced: (map['synced'] as bool?) ?? false,
    );
  }
}

/// Resolve a [WasteCategory] from a stored map, newest format first.
///
/// 1. `label` (stable string id)              — current format
/// 2. `category_index` (int, legacy)          — pre-stableId format
/// 3. `category` (string, legacy)             — oldest format (display or id)
WasteCategory _categoryFromMap(Map<dynamic, dynamic> map) {
  final label = map['label'];
  if (label is String && label.isNotEmpty) {
    return WasteCategory.fromStableId(label);
  }
  final idx = map['category_index'];
  if (idx is int && idx >= 0 && idx < WasteCategory.values.length) {
    return WasteCategory.values[idx];
  }
  final raw = map['category'];
  if (raw is String) {
    final byStable = WasteCategory.fromStableId(raw);
    if (byStable != WasteCategory.lainnya || raw.toLowerCase() == 'lainnya') {
      return byStable;
    }
    // Capitalized display name (custom .name getter), e.g. "Residu"
    for (final c in WasteCategory.values) {
      if (c.name == raw) return c;
    }
  }
  return WasteCategory.lainnya;
}

/// Result of a similarity search against the local dataset.
class LocalDatasetMatch {
  final LocalDatasetEntry entry;
  final int hammingDistance;

  const LocalDatasetMatch({
    required this.entry,
    required this.hammingDistance,
  });
}

/// On-device dataset of confirmed scans. Each entry = a Hive row with its
/// perceptual hash and final category, plus an image file on disk that only
/// lives until the entry is synced to Supabase.
///
/// Disk policy: the JPEG exists solely to be uploaded. [findMatch] never
/// reads it (matching is pure pHash from the Hive row), so once
/// `SupabaseSyncService` confirms the upload it deletes the file via
/// [deleteImageFile] — disk usage stays bounded no matter how many scans
/// accumulate. Offline devices keep their JPEGs until a sync succeeds; with
/// Supabase unconfigured the files are kept forever (nothing else to hold
/// the bytes).
///
/// Storage location is **Application Support**, not Documents — this is app
/// data (a training buffer), not user-facing documents, and should not be
/// surfaced in the Files app or bloat the user's iCloud backup.
///
/// Layout: `<AppSupport>/ml_dataset/v1/images/<sha16>.jpg` + Hive box
/// `ml_dataset_index_v1`. The `v1` namespace lets the schema evolve without
/// corrupting old data.
///
/// Lifecycle:
/// - [init] opens the Hive box and ensures the image dir exists.
/// - [saveEntry] writes the JPEG + Hive row. Dedupes by SHA-256.
/// - [updateCategoryForImage] applies a human correction.
/// - [findMatch] returns the closest entry within a Hamming-distance threshold.
/// - [unsyncedEntries] / [markSynced] drive the Supabase outbox.
/// - [deleteImageFile] reclaims a synced entry's JPEG (Hive row stays).
///
/// Hashing: 8x8 grayscale aHash (64-bit). Threshold default = 8 bits.
class LocalDatasetService {
  LocalDatasetService._();
  static final LocalDatasetService instance = LocalDatasetService._();

  static const String _boxName = 'ml_dataset_index_v1';
  static const String _datasetDirName = 'ml_dataset/v1/images';
  static const int _defaultThreshold = 8;

  late final Box<dynamic> _box;
  late final Directory _imageDir;
  bool _initialized = false;

  /// Idempotent. Must be called once at app start (see `main.dart`).
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    final support = await getApplicationSupportDirectory();
    _imageDir = Directory('${support.path}/$_datasetDirName');
    if (!_imageDir.existsSync()) {
      _imageDir.createSync(recursive: true);
    }
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
    _initialized = true;
    debugPrint('[LocalDataset] initialized at ${_imageDir.path} '
        'with ${_box.length} entries '
        '(${unsyncedEntries().length} pending sync)');
    _reclaimSyncedImages();
  }

  /// One-time-per-launch sweep: delete JPEGs left behind by entries that were
  /// synced BEFORE the delete-after-sync policy existed. New entries are
  /// reclaimed inline by the sync loop; this only migrates old installs.
  void _reclaimSyncedImages() {
    var reclaimed = 0;
    for (final raw in _box.values) {
      final entry =
          LocalDatasetEntry.fromMap(raw as Map<dynamic, dynamic>);
      if (!entry.synced) continue;
      final f = File('${_imageDir.path}/${entry.imageFileName}');
      if (!f.existsSync()) continue;
      try {
        f.deleteSync();
        reclaimed++;
      } catch (e) {
        debugPrint('[LocalDataset] reclaim failed for '
            '${entry.imageFileName}: $e');
      }
    }
    if (reclaimed > 0) {
      debugPrint('[LocalDataset] reclaimed $reclaimed synced image(s)');
    }
  }

  /// Delete the on-disk JPEG for [entry], keeping its Hive row. Safe to call
  /// for a file that's already gone. Only call once the bytes are safe in the
  /// Supabase bucket — the local file is the sole copy until then.
  Future<void> deleteImageFile(LocalDatasetEntry entry) async {
    if (!_initialized) return;
    try {
      final f = File('${_imageDir.path}/${entry.imageFileName}');
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('[LocalDataset] deleteImageFile failed for '
          '${entry.imageFileName}: $e');
    }
  }

  /// Persist a confirmed scan. Dedupes by SHA-256 (same exact bytes →
  /// overwrite). [labelSource] is `model` for an automatic classification or
  /// `human` for a user-confirmed one.
  ///
  /// Returns the persisted entry, or null if [imageBytes] couldn't be hashed.
  Future<LocalDatasetEntry?> saveEntry(
    Uint8List imageBytes, {
    required WasteCategory category,
    String? itemName,
    double? confidence,
    String labelSource = 'model',
  }) async {
    if (!_initialized) {
      debugPrint('[LocalDataset] saveEntry called before init — skipping');
      return null;
    }

    final shaHex = sha256.convert(imageBytes).toString();

    // Never downgrade a human-labelled entry back to a model guess: a later
    // automatic save of the same bytes (e.g. saveToHistory after the user
    // already corrected this image) must not erase the human label — it is
    // the most valuable training signal we collect.
    final existingRaw = _box.get(shaHex);
    if (existingRaw != null && labelSource == 'model') {
      final existing = LocalDatasetEntry.fromMap(
          Map<dynamic, dynamic>.from(existingRaw as Map));
      if (existing.labelSource == 'human') {
        debugPrint('[LocalDataset] kept human label for $shaHex '
            '(model re-save ignored)');
        return existing;
      }
    }

    final phash = _pHash(imageBytes);
    if (phash == 0) {
      debugPrint('[LocalDataset] image decode failed — skipping save');
      return null;
    }

    final imageFileName = '${shaHex.substring(0, 16)}.jpg';
    final imageFile = File('${_imageDir.path}/$imageFileName');
    await imageFile.writeAsBytes(imageBytes, flush: true);

    final entry = LocalDatasetEntry(
      sha256Hex: shaHex,
      pHash: phash,
      category: category,
      itemName: itemName,
      confidence: confidence,
      imageFileName: imageFileName,
      capturedAt: DateTime.now(),
      labelSource: labelSource,
      synced: false,
    );

    await _box.put(shaHex, entry.toMap());
    debugPrint('[LocalDataset] saved ${entry.category.stableId} '
        '($labelSource, total=${_box.length})');
    return entry;
  }

  /// Apply a human correction to an existing entry's category.
  ///
  /// Writes the new label to the `label` field (the source of truth that
  /// [LocalDatasetEntry.fromMap] reads first), marks it `human`, and resets
  /// `synced` so the correction re-uploads. No-op if no entry matches.
  ///
  /// Previously this wrote a `category` field that `fromMap` ignored in favour
  /// of the stale `category_index`, so corrections silently vanished. Fixed.
  Future<void> updateCategoryForImage(
    Uint8List imageBytes, {
    required WasteCategory newCategory,
    String? itemName,
  }) async {
    if (!_initialized) return;
    final shaHex = sha256.convert(imageBytes).toString();
    final existing = _box.get(shaHex);
    if (existing == null) return;
    final entry =
        LocalDatasetEntry.fromMap(Map<dynamic, dynamic>.from(existing as Map));
    final updated = entry.copyWith(
      category: newCategory,
      itemName: itemName ?? entry.itemName,
      labelSource: 'human',
      synced: false,
    );
    await _box.put(shaHex, updated.toMap());
    debugPrint('[LocalDataset] corrected $shaHex → ${newCategory.stableId} '
        '(human, will re-sync)');
  }

  /// Deletes an entry from the local dataset and removes its associated image file.
  /// Used when the user discards a scan via "Pindai Lagi" after it was saved.
  Future<void> deleteEntry(Uint8List imageBytes) async {
    if (!_initialized) return;
    final shaHex = sha256.convert(imageBytes).toString();
    final existing = _box.get(shaHex);
    if (existing != null) {
      final entry = LocalDatasetEntry.fromMap(Map<dynamic, dynamic>.from(existing as Map));
      await deleteImageFile(entry);
      await _box.delete(shaHex);
      debugPrint('[LocalDataset] deleted entry and image for $shaHex');
    }
  }

  /// Returns the nearest match within [threshold] Hamming bits, or null.
  LocalDatasetMatch? findMatch(
    Uint8List imageBytes, {
    int threshold = _defaultThreshold,
  }) {
    if (!_initialized || _box.isEmpty) return null;
    final phash = _pHash(imageBytes);
    if (phash == 0) return null;

    LocalDatasetEntry? bestEntry;
    int bestDistance = threshold + 1;

    for (final raw in _box.values) {
      final map = raw as Map<dynamic, dynamic>;
      final entry = LocalDatasetEntry.fromMap(map);
      
      // Strict Supervised Learning: Guru (Human/Gemini) validate only
      // Jangan biarkan murid (Model) menyontek jawaban yang belum disahkan
      if (entry.labelSource != 'human' && entry.labelSource != 'gemini') continue;

      final distance = _hammingDistance(phash, entry.pHash);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestEntry = entry;
      }
    }

    if (bestEntry == null) return null;
    return LocalDatasetMatch(entry: bestEntry, hammingDistance: bestDistance);
  }

  /// All entries, newest first.
  List<LocalDatasetEntry> allEntries() {
    if (!_initialized) return const [];
    return _box.values
        .map((raw) => LocalDatasetEntry.fromMap(raw as Map<dynamic, dynamic>))
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  /// Watch the underlying Hive box for changes (adds, updates, deletes).
  Stream<BoxEvent> watch() {
    if (!_initialized) return const Stream.empty();
    return _box.watch();
  }

  /// Entries not yet synced to Supabase (the outbox). Newest first.
  List<LocalDatasetEntry> unsyncedEntries() {
    if (!_initialized) return const [];
    return _box.values
        .map((raw) => LocalDatasetEntry.fromMap(raw as Map<dynamic, dynamic>))
        .where((e) => !e.synced)
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  /// Raw image bytes for [entry], or null if the file is missing.
  Future<Uint8List?> imageBytesFor(LocalDatasetEntry entry) async {
    if (!_initialized) return null;
    final f = File('${_imageDir.path}/${entry.imageFileName}');
    if (!f.existsSync()) return null;
    return f.readAsBytes();
  }

  /// Mark an entry as successfully uploaded. No-op if it's gone.
  Future<void> markSynced(String sha256Hex) async {
    if (!_initialized) return;
    final existing = _box.get(sha256Hex);
    if (existing == null) return;
    final entry =
        LocalDatasetEntry.fromMap(Map<dynamic, dynamic>.from(existing as Map));
    await _box.put(sha256Hex, entry.copyWith(synced: true).toMap());
  }

  /// Compute an 8x8 grayscale aHash (64-bit). Returns 0 on decode failure.
  int _pHash(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return 0;

    final small = img.copyResize(decoded, width: 8, height: 8);
    final lumens = List<int>.filled(64, 0);
    var sum = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final p = small.getPixel(x, y);
        final luma = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
        lumens[y * 8 + x] = luma;
        sum += luma;
      }
    }
    final mean = sum ~/ 64;

    var hash = 0;
    for (var i = 0; i < 64; i++) {
      if (lumens[i] > mean) hash |= (1 << i);
    }
    return hash;
  }

  /// Bit-count of XOR — number of differing bits between two 64-bit hashes.
  int _hammingDistance(int a, int b) {
    var x = a ^ b;
    var count = 0;
    while (x != 0) {
      count += x & 1;
      x = x >>> 1;
    }
    return count;
  }
}
