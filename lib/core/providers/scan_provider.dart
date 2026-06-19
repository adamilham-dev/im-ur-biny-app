import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/scan_result.dart';
import '../models/waste_category.dart';
import '../services/gemini_service.dart';
import '../services/openrouter_classifier_service.dart';
import '../services/rtdetr_service.dart';
import '../services/supabase_sync_service.dart';
import '../services/tflite_service.dart';
import '../services/session_service.dart';
import 'local_dataset_provider.dart';
import 'session_provider.dart';

class ScanNotifier extends StateNotifier<AsyncValue<ScanResult?>> {
  final TFLiteService _tfliteService;
  final RTDETRService _rtdetrService;
  final GeminiService _geminiService;
  final Ref _ref;

  List<ScanResult> _multiResults = [];
  int _selectedDetailIndex = 0;
  bool _isCorrected = false;
  bool _lastUsedGemini = false;

  List<ScanResult> get multiResults => _multiResults;
  int get selectedDetailIndex => _selectedDetailIndex;
  bool get isCorrected => _isCorrected;

  /// True if the most recent classification came from the Gemini cloud API
  /// rather than the on-device TFLite/RT-DETR model. Useful for UI badges
  /// ("Dianalisis ulang oleh AI cloud").
  bool get lastUsedGemini => _lastUsedGemini;

  /// True if a Gemini API key is configured. Use this for UI guards —
  /// does NOT trigger model init, so it's safe to call before the first
  /// classification.
  bool get geminiAvailable => _geminiService.isConfigured;

  ScanNotifier(this._ref)
      : _tfliteService = TFLiteService(),
        _rtdetrService = RTDETRService(),
        _geminiService = GeminiService(),
        super(const AsyncValue.data(null));

  Future<ScanResult?> classifyImage(Uint8List imageBytes) async {
    _isCorrected = false;
    _lastUsedGemini = false;
    state = const AsyncValue.loading();
    try {
      // ── Local dataset lookup ──
      // Skip ML entirely if a perceptually similar image is already in the
      // user's on-device dataset. The dataset only contains user-confirmed
      // results (accepted AI prediction or manually-corrected category), so
      // a hit is treated as ground truth.
      final cached = _checkLocalDataset(imageBytes);
      if (cached != null) {
        state = AsyncValue.data(cached);
        return cached;
      }

      if (_rtdetrService.isLoaded || !_rtdetrService.isLoaded) {
        await _rtdetrService.loadModel();
      }
      if (_rtdetrService.isLoaded) {
        final result = await _rtdetrService.detectSingle(imageBytes);
        if (result != null) {
          final withCrop = _ensureCroppedImage(result, imageBytes);
          // Re-check dataset against the cropped object — handles the case
          // where the whole image didn't match but the detected object does.
          final cropCached = withCrop.croppedImage != null
              ? _checkLocalDataset(withCrop.croppedImage!)
              : null;
          // Dataset hit = user-confirmed ground truth, don't override.
          // Otherwise let the cloud LLM decide the type (residu suppressed).
          final final_ = cropCached ??
              await _applyCloudType(withCrop, fallbackBytes: imageBytes);
          state = AsyncValue.data(final_);
          return final_;
        }
        // RT-DETR loaded but found nothing → fall through to the focused
        // center-crop fallback below (don't dead-end at "tidak terdeteksi").
      }

      // No usable RT-DETR detection (model down OR found nothing). Classify a
      // CENTER crop of the frame: keeps the centered object, drops the edges so
      // stray background (e.g. clothing) doesn't leak in.
      final result = await _classifyFallback(imageBytes);
      state = AsyncValue.data(result);
      return result;
    } catch (e) {
      debugPrint('ScanNotifier: classifyImage error = $e');
      final errorResult = ScanResult(
        itemName: 'Model tidak tersedia',
        category: WasteCategory.lainnya,
        confidence: 0.0,
        description: 'File model TFLite belum ditemukan. '
            'Jalankan export_tflite.py lalu taruh waste_classifier.tflite di assets/models/',
        disposalInfo: 'Hubungi developer untuk setup model.',
        allProbabilities: {},
      );
      state = AsyncValue.data(errorResult);
      return errorResult;
    }
  }

  /// Normalize an on-device "residu" prediction to "lainnya" (Tidak dikenali).
  /// Residu was dropped as a user-facing category; the on-device model still
  /// emits it, so we map it away here for a consistent UX.
  ScanResult _suppressResidu(ScanResult r) {
    if (r.category != WasteCategory.residu) return r;
    return r.copyWith(
      category: WasteCategory.lainnya,
      itemName: 'Tidak dikenali',
      disposalInfo: WasteCategory.lainnya.disposalInfo,
      description: 'Tidak termasuk kategori daur ulang yang dikenali.',
    );
  }

  /// Multi-object detection via the cloud (Gemma) when RT-DETR is unavailable.
  /// Gemma lists every waste object + (optional) normalized box; we crop each
  /// from the original frame for the UI card. Falls back to a single focused
  /// classification if the cloud is off or sees no waste.
  Future<List<ScanResult>> _classifyMultiWithCloud(Uint8List imageBytes) async {
    final dets =
        await OpenRouterClassifierService.instance.classifyMultiple(imageBytes);
    if (dets == null || dets.isEmpty) {
      return [await _classifyFallback(imageBytes)];
    }
    _lastUsedGemini = true;
    final im = img.decodeImage(imageBytes);
    final results = dets.map((d) {
      Rect? boxPx;
      Uint8List? crop;
      final b = d.boxNorm;
      if (b != null && im != null) {
        boxPx = Rect.fromLTRB(
          b[0] * im.width,
          b[1] * im.height,
          b[2] * im.width,
          b[3] * im.height,
        );
        crop = _cropFromBytes(imageBytes, boxPx);
      }
      final cat = d.category;
      return ScanResult(
        itemName: cat == WasteCategory.lainnya ? 'Tidak dikenali' : cat.name,
        category: cat,
        confidence: d.confidence,
        description: 'Diklasifikasikan oleh AI cloud (Gemma via OpenRouter).',
        disposalInfo: cat.disposalInfo,
        boundingBox: boxPx,
        croppedImage: crop,
        allProbabilities: {cat.name: d.confidence},
      );
    }).toList();
    // Collect mixed-mode detections to the local dataset + Supabase right away
    // (don't wait for the "Selesai" button), so every scan is captured.
    unawaited(saveMultiToLocalDataset(results));
    return results;
  }

  /// Focused fallback when RT-DETR yields no detection (model down OR found
  /// nothing): on-device classifies the frame for a base guess, then the cloud
  /// overrides using a CENTER crop (frame edges dropped, so stray background
  /// like clothing doesn't leak in). Cloud-less → on-device guess with residu
  /// suppressed. Never dead-ends and never sends the raw full frame to the cloud.
  Future<ScanResult> _classifyFallback(Uint8List imageBytes) async {
    await _tfliteService.loadModel();
    return _applyCloudType(
      await _tfliteService.classifyImage(imageBytes),
      fallbackBytes: _centerCropBytes(imageBytes),
    );
  }

  /// Center-crop [bytes] to [fraction] of each side, re-encoded as JPEG. Used
  /// as a FOCUSED fallback when RT-DETR can't load: keeps the centered object
  /// (kiosk drop-zone) and drops the frame edges so background doesn't reach
  /// the classifier.
  Uint8List _centerCropBytes(Uint8List bytes, {double fraction = 0.7}) {
    final im = img.decodeImage(bytes);
    if (im == null) return bytes;
    final w = (im.width * fraction).round();
    final h = (im.height * fraction).round();
    final x = ((im.width - w) / 2).round();
    final y = ((im.height - h) / 2).round();
    final cropped = img.copyCrop(im, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }

  /// Decide the waste TYPE via the OpenRouter (Gemma) cloud LLM when configured;
  /// otherwise keep the on-device guess with residu normalized away.
  ///
  /// The on-device pipeline still supplies the bounding box / crop — the cloud
  /// only overrides the category. The prompt offers no "residu" class, so a
  /// cloud result never produces residu.
  Future<ScanResult> _applyCloudType(
    ScanResult base, {
    required Uint8List fallbackBytes,
  }) async {
    if (!OpenRouterClassifierService.instance.isConfigured) {
      return _suppressResidu(base);
    }
    final crop = base.croppedImage ?? fallbackBytes;
    final cloud = await OpenRouterClassifierService.instance.classify(crop);
    if (cloud == null) return _suppressResidu(base);
    _lastUsedGemini = true; // reuse the "analysed by cloud AI" UI flag
    final cat = cloud.category;
    return base.copyWith(
      category: cat,
      confidence: cloud.confidence,
      itemName: cat == WasteCategory.lainnya ? 'Tidak dikenali' : cat.name,
      disposalInfo: cat.disposalInfo,
      description: 'Diklasifikasikan oleh AI cloud (Gemma via OpenRouter).',
      allProbabilities: {cat.name: cloud.confidence},
    );
  }

  /// Cloud-classify EACH detected object's crop via OpenRouter, in parallel
  /// (N objects ≈ one round-trip, not N×). Dataset hits (user-confirmed,
  /// confidence == 1.0) and crop-less items are left as-is. Falls back to
  /// on-device + residu suppression when the cloud isn't configured.
  Future<List<ScanResult>> _applyCloudTypeMulti(List<ScanResult> items) async {
    if (!OpenRouterClassifierService.instance.isConfigured) {
      return items.map(_suppressResidu).toList();
    }
    _lastUsedGemini = true;
    return Future.wait(items.map((r) async {
      if (r.confidence == 1.0) return _suppressResidu(r); // dataset hit
      final crop = r.croppedImage;
      if (crop == null) return _suppressResidu(r);
      final cloud = await OpenRouterClassifierService.instance.classify(crop);
      if (cloud == null) return _suppressResidu(r);
      final cat = cloud.category;
      return r.copyWith(
        category: cat,
        confidence: cloud.confidence,
        itemName: cat == WasteCategory.lainnya ? 'Tidak dikenali' : cat.name,
        disposalInfo: cat.disposalInfo,
        description: 'Diklasifikasikan oleh AI cloud (Gemma via OpenRouter).',
        allProbabilities: {cat.name: cloud.confidence},
      );
    }));
  }

  /// Escalate classification to the Gemini cloud API.
  ///
  /// Returns the new [ScanResult] (also published to [state]) if Gemini is
  /// available AND confident; otherwise returns `null` and leaves the
  /// previous on-device result in [state] so callers can fall back to the
  /// original behaviour (e.g. show the low-confidence screen).
  Future<ScanResult?> classifyWithGemini(Uint8List imageBytes) async {
    // ── Local dataset lookup ──
    // Same rationale as classifyImage — if the user has already confirmed
    // a category for a perceptually similar image, skip the cloud call.
    final cached = _checkLocalDataset(imageBytes);
    if (cached != null) {
      _lastUsedGemini = false;
      _isCorrected = false;
      state = AsyncValue.data(cached);
      return cached;
    }

    if (!_geminiService.isAvailable) {
      // Trigger lazy init so subsequent checks have an accurate flag.
      final result = await _geminiService.classifyImage(imageBytes);
      if (result == null) return null;
      _lastUsedGemini = true;
      _isCorrected = false;
      state = AsyncValue.data(result);
      return result;
    }

    final result = await _geminiService.classifyImage(imageBytes);
    if (result == null) {
      // Gemini rejected or unavailable — keep the existing on-device result.
      return null;
    }

    _lastUsedGemini = true;
    _isCorrected = false;
    state = AsyncValue.data(result);
    return result;
  }

  Future<List<ScanResult>> classifyMultipleImages(Uint8List imageBytes) async {
    try {
      // Try RT-DETR first
      await _rtdetrService.loadModel();
      if (_rtdetrService.isLoaded) {
        final results = await _rtdetrService.detectObjects(imageBytes);
        if (results.isNotEmpty) {
          debugPrint('[ScanNotifier] RT-DETR found ${results.length} objects');
          // Ensure all have cropped images
          final enriched = results
              .map((r) => _ensureCroppedImage(r, imageBytes))
              .toList();
          // Per-item dataset lookup — replaces any item whose crop matches
          // a previously-confirmed entry with the cached category.
          final withDataset =
              await _applyCloudTypeMulti(_enrichMultiWithLocalDataset(enriched));
          _multiResults = withDataset;
          _selectedDetailIndex = 0;
          _saveMultiToHistory(withDataset);
          _invalidateMultiResultProviders();
          return withDataset;
        }
      }

      // RT-DETR unavailable (it fails to load on some devices). Use the cloud
      // (Gemma) to detect & classify ALL objects in one call instead of the
      // dead on-device detector.
      debugPrint('[ScanNotifier] RT-DETR unavailable in mixed — Gemma multi-detect');
      _multiResults = await _classifyMultiWithCloud(imageBytes);
      _selectedDetailIndex = 0;
      _saveMultiToHistory(_multiResults);
      _invalidateMultiResultProviders();
      return _multiResults;
    } catch (e) {
      debugPrint('ScanNotifier: classifyMultipleImages error = $e');

      try {
        await _tfliteService.loadModel();
        final fallback = await _tfliteService.classifyImage(imageBytes);
        _multiResults = [fallback];
        _selectedDetailIndex = 0;
        _invalidateMultiResultProviders();
        return [fallback];
      } catch (e2) {
        debugPrint('ScanNotifier: Last resort classify error = $e2');
        _multiResults = [];
        _invalidateMultiResultProviders();
        return [];
      }
    }
  }

  /// Cloud-based multi-item classification via Gemini. Mirrors
  /// [classifyMultipleImages] but routes through [GeminiService.classifyMultiple]
  /// instead of the on-device RT-DETR/TFLite pipeline. Triggered when the user
  /// taps "Pindai Lagi" on the multi-result screen — the cloud model is more
  /// accurate for hard cases where on-device detection misfired (e.g. RT-DETR
  /// returns empty and the TFLite fallback splits the image into wrong regions).
  ///
  /// Does NOT filter by confidence so the multi-result UI can render low-
  /// confidence items as "Tidak dikenali" inside the list — same behavior as
  /// the on-device multi path.
  ///
  /// Crops each item from the original image using the normalized bbox Gemini
  /// returns, so each card on the multi-result screen shows the matching
  /// object (not the shared full-frame fallback). Items without a usable bbox
  /// fall back to the full image.
  Future<List<ScanResult>> classifyMultipleWithGemini(Uint8List imageBytes) async {
    try {
      final predictions = await _geminiService.classifyMultiple(imageBytes);

      // Decode once + reuse for all per-item crops. Falls back to no-crop
      // path if the bytes can't be decoded (rare, but guards the UI).
      final decoded = img.decodeImage(imageBytes);

      final results = <ScanResult>[];
      for (final p in predictions) {
        Rect? pixelRect;
        Uint8List? cropped;
        if (decoded != null && p.bbox != null) {
          pixelRect = Rect.fromLTWH(
            p.bbox![1] * decoded.width,
            p.bbox![0] * decoded.height,
            (p.bbox![3] - p.bbox![1]) * decoded.width,
            (p.bbox![2] - p.bbox![0]) * decoded.height,
          );
          cropped = _cropFromBytes(imageBytes, pixelRect);
        }

        results.add(ScanResult(
          itemName: _itemNameForGemini(p.category),
          category: p.category,
          confidence: p.confidence,
          description: p.reason,
          disposalInfo: p.category.disposalInfo,
          boundingBox: pixelRect,
          croppedImage: cropped,
          allProbabilities: {
            p.category.name: p.confidence,
            'Residu': 1.0 - p.confidence,
          },
        ));
      }

      _multiResults = _enrichMultiWithLocalDataset(results);
      _selectedDetailIndex = 0;
      if (_multiResults.isNotEmpty) {
        _lastUsedGemini = true;
        _saveMultiToHistory(_multiResults);
      }
      _invalidateMultiResultProviders();
      return results;
    } catch (e) {
      debugPrint('ScanNotifier: classifyMultipleWithGemini error = $e');
      _multiResults = [];
      _selectedDetailIndex = 0;
      _invalidateMultiResultProviders();
      return [];
    }
  }

  /// Item-name helper that mirrors [GeminiService]'s private `_itemNameFor`
  /// without forcing this class to import the service's private member.
  String _itemNameForGemini(WasteCategory category) {
    switch (category) {
      case WasteCategory.plastik:
        return 'Sampah Plastik';
      case WasteCategory.kertas:
        return 'Sampah Kertas';
      case WasteCategory.organik:
        return 'Sampah Organik';
      case WasteCategory.logam:
        return 'Sampah Logam';
      case WasteCategory.kaca:
        return 'Sampah Kaca';
      case WasteCategory.residu:
        return 'Sampah Residu';
      case WasteCategory.lainnya:
        return 'Sampah Tidak Dikenali';
    }
  }

  /// Force [multiResultsProvider] and [selectedDetailProvider] to recompute
  /// on next read. Both providers wrap `_multiResults` via `ref.read` (so
  /// they don't subscribe to notifier mutations) and would otherwise return
  /// STALE results across navigations — e.g. after a "Pindai Lagi" rescan
  /// the multi-result screen and the detail dialog would still show the
  /// previous TFLite/RT-DETR items instead of the freshly-classified ones.
  /// Must be called whenever `_multiResults` changes.
  void _invalidateMultiResultProviders() {
    _ref.invalidate(multiResultsProvider);
    _ref.invalidate(selectedDetailProvider);
  }

  /// Look the image up in the user's on-device dataset. Returns a synthetic
  /// high-confidence [ScanResult] if a perceptually similar image has been
  /// confirmed before; otherwise null. Bypasses ML entirely on hit.
  ScanResult? _checkLocalDataset(Uint8List imageBytes) {
    try {
      final match = _ref.read(localDatasetProvider).findMatch(imageBytes);
      if (match == null) return null;
      debugPrint('[ScanNotifier] local dataset hit '
          '(distance=${match.hammingDistance}) → ${match.entry.category.name}');
      final cat = match.entry.category;
      return ScanResult(
        itemName: match.entry.itemName ?? 'Sampah dari dataset lokal',
        category: cat,
        confidence: 1.0,
        description: 'Sudah pernah kamu pindai & simpan sebelumnya '
            '(${match.hammingDistance}/8 mirip).',
        disposalInfo: cat.disposalInfo,
        allProbabilities: {cat.name: 1.0},
      );
    } catch (e) {
      debugPrint('[ScanNotifier] local dataset lookup failed: $e');
      return null;
    }
  }

  /// Per-item dataset enrichment for multi-mode. Replaces each result whose
  /// cropped image perceptually matches a stored entry with a synthetic
  /// 100%-confidence result for that entry's category. Items without a
  /// cropped image or without a match pass through unchanged.
  List<ScanResult> _enrichMultiWithLocalDataset(List<ScanResult> results) {
    final dataset = _ref.read(localDatasetProvider);
    var hitCount = 0;
    final enriched = results.map((r) {
      final crop = r.croppedImage;
      if (crop == null) return r;
      final match = dataset.findMatch(crop);
      if (match == null) return r;
      hitCount++;
      final cat = match.entry.category;
      return ScanResult(
        itemName: match.entry.itemName ?? r.itemName,
        category: cat,
        confidence: 1.0,
        description: 'Sudah pernah kamu pindai & simpan sebelumnya '
            '(${match.hammingDistance}/8 mirip).',
        disposalInfo: cat.disposalInfo,
        boundingBox: r.boundingBox,
        croppedImage: r.croppedImage,
        allProbabilities: {cat.name: 1.0},
      );
    }).toList();
    if (hitCount > 0) {
      debugPrint('[ScanNotifier] multi dataset enrichment: '
          '$hitCount/${results.length} items matched local dataset');
    }
    return enriched;
  }

  /// Persist a single confirmed result to the on-device dataset. Prefers the
  /// cropped image (the object itself) over the full captured frame so
  /// future scans of just that object match cleanly.
  Future<void> _saveToLocalDataset(ScanResult result) async {
    final crop = result.croppedImage;
    final full = _ref.read(capturedImageProvider);
    final bytes = crop ?? full;
    if (bytes == null) {
      debugPrint('[ScanNotifier] saveToLocalDataset skipped — no image bytes');
      return;
    }
    try {
      await _ref.read(localDatasetProvider).saveEntry(
        bytes,
        category: result.category,
        itemName: result.itemName,
        confidence: result.confidence,
      );
      // Best-effort push to Supabase. Never awaited, never blocks the scan;
      // no-op when Supabase isn't configured.
      unawaited(SupabaseSyncService.instance.syncPending());
    } catch (e) {
      debugPrint('[ScanNotifier] saveToLocalDataset error: $e');
    }
  }

  /// Ensure a ScanResult has a croppedImage by cropping from the original
  /// image bytes using the bounding box if available.
  ScanResult _ensureCroppedImage(ScanResult result, Uint8List originalBytes) {
    if (result.croppedImage != null) return result;
    if (result.boundingBox == null) return result;

    final cropped = _cropFromBytes(originalBytes, result.boundingBox!);
    if (cropped == null) return result;

    return result.copyWith(croppedImage: cropped);
  }

  /// Crop a region from image bytes. Returns JPEG bytes or null on failure.
  Uint8List? _cropFromBytes(Uint8List imageBytes, Rect rect) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final x1 = rect.left.round().clamp(0, image.width);
      final y1 = rect.top.round().clamp(0, image.height);
      final x2 = rect.right.round().clamp(0, image.width);
      final y2 = rect.bottom.round().clamp(0, image.height);
      final w = x2 - x1;
      final h = y2 - y1;

      if (w < 10 || h < 10) return null;

      final cropped = img.copyCrop(image, x: x1, y: y1, width: w, height: h);
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
    } catch (e) {
      debugPrint('[ScanNotifier] Crop failed: $e');
      return null;
    }
  }

  void _saveMultiToHistory(List<ScanResult> results) {
    if (results.isNotEmpty) {
      final session = _ref.read(sessionProvider);
      final updatedHistory = [...session.scanHistory, ...results];
      _ref.read(sessionProvider.notifier).state = session.copyWith(
        scanHistory: updatedHistory,
      );
      // NOTE: local-dataset persistence for multi-mode happens on the
      // "Selesai" handler in multi_result_screen, NOT here, because
      // classification runs before the user has reviewed the items.
    }
  }

  /// Bulk-save multi-mode items to the on-device dataset. Called by the
  /// multi-result screen's "Selesai" button after the user accepts the
  /// (possibly corrected) per-item categories. Each item's croppedImage
  /// is saved as its own dataset entry so future single- or multi-scans
  /// match it individually.
  Future<void> saveMultiToLocalDataset(List<ScanResult> results) async {
    for (final r in results) {
      // Save every item. _saveToLocalDataset falls back to the full captured
      // frame when an item has no crop (e.g. the cloud returned no box), so
      // boxless detections are still collected + synced instead of skipped.
      await _saveToLocalDataset(r);
    }
  }

  void selectDetail(int index) {
    if (index >= 0 && index < _multiResults.length) {
      _selectedDetailIndex = index;
    }
  }

  Future<void> correctResult(WasteCategory newCategory) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final corrected = current.copyWith(
      category: newCategory,
      disposalInfo: newCategory.disposalInfo,
      isCorrected: true,
      originalCategory: current.category,
    );

    state = AsyncValue.data(corrected);
    _isCorrected = true;

    final session = _ref.read(sessionProvider);
    final updatedHistory = session.scanHistory.map((r) {
      if (r.itemName == current.itemName &&
          r.confidence == current.confidence) {
        return corrected;
      }
      return r;
    }).toList();

    _ref.read(sessionProvider.notifier).state =
        session.copyWith(scanHistory: updatedHistory);

    // If the original image is already in the on-device dataset (saved
    // before the user opened manual correction), update its category too
    // so future scans reflect the corrected label. If it's not yet in the
    // dataset, the manual-correction screen will save the corrected entry
    // on "Simpan Koreksi".
    final crop = current.croppedImage;
    final full = _ref.read(capturedImageProvider);
    final bytes = crop ?? full;
    if (bytes != null) {
      try {
        await _ref
            .read(localDatasetProvider)
            .updateCategoryForImage(bytes, newCategory: newCategory);
        // Re-push the corrected (human-labelled) entry. Best-effort.
        unawaited(SupabaseSyncService.instance.syncPending());
      } catch (e) {
        debugPrint('[ScanNotifier] updateCategoryForImage failed: $e');
      }
    }

    await _ref.read(sessionProvider.notifier).addCorrection();
    await _ref.read(sessionProvider.notifier).addXP(SessionService.xpCorrection);
  }

  void saveToHistory() {
    final result = state.valueOrNull;
    if (result == null) return;
    final session = _ref.read(sessionProvider);
    final updatedHistory = [...session.scanHistory, result];
    _ref.read(sessionProvider.notifier).state = session.copyWith(
      scanHistory: updatedHistory,
    );
    // Persist to on-device dataset so future scans of the same item reuse
    // this category instead of re-running ML.
    _saveToLocalDataset(result);
  }

  /// Public wrapper around [_saveToLocalDataset] for flows that bypass
  /// [saveToHistory] — most notably the manual-correction screen's
  /// "Simpan Koreksi" handler, which calls [correctResult] (an in-place
  /// update) but never calls [saveToHistory] itself. Without this call,
  /// a correction made directly from the result screen wouldn't reach the
  /// on-device dataset.
  Future<void> saveCorrectedToLocalDataset() async {
    final result = state.valueOrNull;
    if (result == null) return;
    await _saveToLocalDataset(result);
  }

  void clearResult() {
    state = const AsyncValue.data(null);
    _multiResults = [];
    _selectedDetailIndex = 0;
    _isCorrected = false;
    _lastUsedGemini = false;
    _invalidateMultiResultProviders();
  }

  /// Update a specific item in multi-results (used after re-analyzing an unknown item).
  void updateMultiResult(int index, ScanResult newResult) {
    if (index < 0 || index >= _multiResults.length) return;
    _multiResults[index] = newResult;
    // Also update the single result state so analyzing screen can read it
    state = AsyncValue.data(newResult);
    _invalidateMultiResultProviders();
  }
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, AsyncValue<ScanResult?>>((ref) {
  return ScanNotifier(ref);
});

final scanResultProvider = Provider<ScanResult?>((ref) {
  return ref.watch(scanProvider).valueOrNull;
});

final isScanningProvider = Provider<bool>((ref) {
  return ref.watch(scanProvider).isLoading;
});

final isCorrectedProvider = Provider<bool>((ref) {
  return ref.read(scanProvider.notifier).isCorrected;
});

/// When true, the next classification in scanning_screen will use the
/// Gemini cloud API instead of the on-device TFLite/RT-DETR model.
/// Set by retry buttons ("Pindai Lagi", "Analisis AI") and reset by
/// scanning_screen after the classification runs.
final useGeminiProvider = StateProvider<bool>((ref) => false);

/// True if the current result was produced by the Gemini cloud API
/// (vs the on-device TFLite/RT-DETR model).
final lastUsedGeminiProvider = Provider<bool>((ref) {
  return ref.read(scanProvider.notifier).lastUsedGemini;
});

/// True if the Gemini API key is configured and the service initialised.
final geminiAvailableProvider = Provider<bool>((ref) {
  return ref.read(scanProvider.notifier).geminiAvailable;
});

final multiResultsProvider = Provider<List<ScanResult>>((ref) {
  return ref.read(scanProvider.notifier).multiResults;
});

final capturedImageProvider = StateProvider<Uint8List?>((ref) => null);

final selectedDetailIndexProvider = StateProvider<int>((ref) => 0);

/// When set, the analyzing screen is re-analyzing a specific multi-result item.
/// After analysis, it navigates back to /multi-result instead of /result.
final reanalyzeMultiIndexProvider = StateProvider<int?>((ref) => null);

final selectedDetailProvider = Provider<ScanResult?>((ref) {
  final results = ref.read(scanProvider.notifier).multiResults;
  final index = ref.watch(selectedDetailIndexProvider);
  if (index >= 0 && index < results.length) {
    return results[index];
  }
  return null;
});

final tfliteServiceProvider = Provider<TFLiteService>((ref) {
  final service = TFLiteService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final rtdetrServiceProvider = Provider<RTDETRService>((ref) {
  final service = RTDETRService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
