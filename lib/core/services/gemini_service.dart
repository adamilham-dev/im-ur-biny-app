import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/scan_result.dart';
import '../models/waste_category.dart';

/// Result of a single Gemini multi-item prediction.
///
/// Unlike [ScanResult], this carries the bounding box in NORMALIZED 0..1
/// coordinates (as returned by Gemini) — conversion to pixel coords + crop
/// happens in the caller, which has the image dimensions.
class GeminiMultiItem {
  final WasteCategory category;
  final double confidence;
  final String reason;

  /// Normalized bounding box `[y1, x1, y2, x2]` in 0..1, or `null` if Gemini
  /// didn't return a usable box for this item.
  final List<double>? bbox;

  const GeminiMultiItem({
    required this.category,
    required this.confidence,
    required this.reason,
    this.bbox,
  });
}

/// Cloud-based waste classifier using Google Gemini 1.5 Flash.
///
/// Used as an escalation path when the on-device TFLite/RT-DETR model is
/// uncertain (low-confidence band) or returns "unknown". The Gemini call is
/// slower (network) and not free, so it's reserved for retries — not the
/// initial classification.
///
/// ⚠️  SECURITY: The API key is loaded from .env, which is bundled into the
///     APK. Anyone who installs the app can extract it. Move to a backend
///     proxy before shipping to production.
class GeminiService {
  static const String _modelName = 'gemini-3.1-flash-lite';

  /// Minimum confidence to accept a Gemini prediction. Gemini tends to be
  /// well-calibrated, so we use the same 0.50 floor as the on-device path.
  static const double _confidenceThreshold = 0.50;

  GenerativeModel? _model;
  bool _initialized = false;
  String? _initError;

  /// True when an API key was found in .env and the client was built.
  bool get isAvailable => _model != null;

  /// True when an API key looks configured in .env. Cheaper than
  /// [isAvailable] — does NOT trigger model init. Use this for UI guards
  /// (e.g. before showing the progress dialog) so we don't penalise the
  /// first call just because lazy-init hasn't happened yet.
  bool get isConfigured {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY') ?? '';
    return apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY_HERE';
  }

  /// Reason the service couldn't initialize (e.g. missing key), if any.
  String? get initError => _initError;

  /// Lazily initialize the model. Safe to call multiple times.
  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    final apiKey = dotenv.maybeGet('GEMINI_API_KEY') ?? '';
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _initError = 'GEMINI_API_KEY not set in .env';
      debugPrint('[Gemini] $_initError');
      return;
    }

    try {
      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          // Force JSON output so we can parse reliably.
          responseMimeType: 'application/json',
          temperature: 0.1,
          topP: 0.95,
        ),
      );
      debugPrint('[Gemini] Initialized with model=$_modelName');
    } catch (e) {
      _initError = 'Failed to init Gemini: $e';
      debugPrint('[Gemini] $_initError');
    }
  }

  /// Classify a single waste image.
  ///
  /// Returns a [ScanResult] on success, or `null` if:
  ///   - the API key isn't configured
  ///   - the call fails
  ///   - Gemini is itself uncertain (< [_confidenceThreshold])
  Future<ScanResult?> classifyImage(Uint8List imageBytes) async {
    _ensureInitialized();
    if (_model == null) {
      debugPrint('[Gemini] Not available: ${_initError ?? "unknown"}');
      return null;
    }

    try {
      final prompt = TextPart(_buildPrompt());
      final image = DataPart('image/jpeg', imageBytes);
      final response = await _model!.generateContent([
        Content.multi([prompt, image]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('[Gemini] Empty response');
        return null;
      }

      return _parseResponse(text);
    } catch (e, st) {
      debugPrint('[Gemini] classifyImage error: $e');
      debugPrint('[Gemini] stack: $st');
      return null;
    }
  }

  /// Classify ALL waste items visible in the image (mixed-mode escalation).
  ///
  /// Returns a [List<GeminiMultiItem>] — possibly empty if:
  ///   - the API key isn't configured / call fails
  ///   - Gemini sees no waste in the image
  ///
  /// Unlike [classifyImage], this does NOT filter by confidence — every
  /// detected item is returned so the multi-result UI can render
  /// low-confidence ones as "Tidak dikenali" inside the list (mirrors the
  /// on-device RT-DETR/TFLite multi path). Capped at 5 items.
  ///
  /// Each item carries a normalized `bbox` `[y1, x1, y2, x2]` (0..1) when
  /// Gemini returns one — the caller converts to pixel coords + crops. Null
  /// bbox means Gemini couldn't localize the object; the caller should fall
  /// back to the full image.
  Future<List<GeminiMultiItem>> classifyMultiple(Uint8List imageBytes) async {
    _ensureInitialized();
    if (_model == null) {
      debugPrint('[Gemini] Not available: ${_initError ?? "unknown"}');
      return [];
    }

    try {
      final prompt = TextPart(_buildMultiPrompt());
      final image = DataPart('image/jpeg', imageBytes);
      final response = await _model!.generateContent([
        Content.multi([prompt, image]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('[Gemini] Empty response (multi)');
        return [];
      }

      return _parseMultiResponse(text);
    } catch (e, st) {
      debugPrint('[Gemini] classifyMultiple error: $e');
      debugPrint('[Gemini] stack: $st');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Prompt engineering
  // ─────────────────────────────────────────────────────────────────────

  String _buildPrompt() {
    return '''
Kamu adalah asisten klasifikasi sampah untuk aplikasi daur ulang Indonesia.

Tugasmu: lihat gambar yang diberikan dan tentukan SATU kategori sampah yang paling tepat.

PENTING — WAJIB pilih salah satu dari 6 kategori di bawah. JANGAN PERNAH keluar dari daftar ini:
- "Plastik"  → botol plastik, kantong plastik, kemasan plastik, atau benda berbahan plastik.
- "Kertas"   → kardus, koran, kertas tulis, buku, atau benda berbahan kertas/kayu olahan.
- "Organik"  → sisa makanan, daun, ranting, kayu alami, kulit buah, bahan biodegradable.
- "Logam"    → kaleng minuman/makanan, besi, aluminium, perkakas, atau benda berbahan logam.
- "Kaca"     → botol kaca, pecahan kaca, toples, cermin, atau benda berbahan kaca.
- "Residu"   → popok, tisu bekas, puntung rokok, styrofoam kotor, kabel, elektronik, karet, keramik, atau sampah yang TIDAK bisa didaur ulang.

ATURAN KHUSUS UNTUK OBJEK NON-SAMPAH:
Jika gambar menampilkan objek yang BUKAN sampah (mis. meja, kursi, furnitur, kendaraan, orang, hewan, pakaian, sepatu, peralatan rumah), TETAP pilih kategori sampah yang paling masuk akal jika objek tersebut AKAN dibuang/didaur ulang. Contoh:
- Meja/kursi kayu → "Organik" (kayu alami) atau "Residu" (kalau dicampur bahan lain)
- Sepatu/sandal → "Residu"
- Pakaian/kain → "Residu" (kecuali kertas/karton yang jelas)
- Elektronik/HP → "Residu"
- Botol/kemasan walaupun masih utuh → sesuaikan dengan bahannya

Pertimbangan:
1. Pilih kategori berdasarkan BAHAN utama objek, bukan fungsinya.
2. Jika bahan utama bisa didaur ulang → masukkan ke kategori bahan tersebut.
3. Jika bahan utama TIDAK bisa didaur ulang → "Residu".
4. Berikan confidence 0.0-1.0 yang jujur berdasarkan seberapa yakin dengan bahan dan kecocokan kategori.

WAJIB jawab HANYA dengan JSON pada format ini, tanpa markdown, tanpa penjelasan tambahan:
{
  "category": "Plastik|Kertas|Organik|Logam|Kaca|Residu",
  "confidence": 0.85,
  "reason": "Alasan singkat 1 kalimat dalam Bahasa Indonesia mengapa kategori ini dipilih."
}
''';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Response parsing
  // ─────────────────────────────────────────────────────────────────────

  ScanResult? _parseResponse(String text) {
    try {
      // Gemini may occasionally wrap output in ```json fences despite the
      // response_mime=application/json setting — strip them defensively.
      var cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final categoryStr = (json['category'] as String?)?.trim() ?? '';
      final confidence = ((json['confidence'] as num?)?.toDouble() ?? 0.0)
          .clamp(0.0, 1.0);
      final reason = (json['reason'] as String?)?.trim() ?? '';

      final category = _parseCategory(categoryStr);
      if (category == null) {
        debugPrint('[Gemini] Unknown category in response: "$categoryStr"');
        return null;
      }
      // The Gemini path is the "learn a new category" escalation flow
      // (Analisis dengan AI → /conclusion-new), so we let it return ANY of the
      // 6 trained categories, including Kaca, as a learnable result. We only
      // reject `lainnya` (Gemini gave up) so the caller falls back to
      // /low-confidence instead of presenting "tidak dikenali" as a new type.
      if (category == WasteCategory.lainnya) {
        debugPrint('[Gemini] Returned "lainnya" — rejecting (no real guess)');
        return null;
      }

      if (confidence < _confidenceThreshold) {
        debugPrint(
          '[Gemini] Below threshold '
          '(${(confidence * 100).toStringAsFixed(1)}% < '
          '${(_confidenceThreshold * 100).toStringAsFixed(1)}%) — rejecting',
        );
        return null;
      }

      debugPrint(
        '[Gemini] Predicted ${category.name} '
        '(${(confidence * 100).toStringAsFixed(1)}%) — $reason',
      );

      return ScanResult(
        itemName: _itemNameFor(category),
        category: category,
        confidence: confidence,
        description: reason.isEmpty
            ? 'Terdeteksi sebagai ${category.name} (via AI cloud).'
            : reason,
        disposalInfo: category.disposalInfo,
        // Gemini doesn't expose class probabilities — synthesize a small map
        // so the low-confidence UI can still render a top-2 breakdown if
        // the user lands there. The other slot is a flat residual.
        allProbabilities: {
          category.name: confidence,
          'Lainnya': 1.0 - confidence,
        },
      );
    } catch (e) {
      debugPrint('[Gemini] Failed to parse response: $e');
      debugPrint('[Gemini] Raw response was: $text');
      return null;
    }
  }

  String _buildMultiPrompt() {
    return '''
Kamu adalah asisten klasifikasi sampah untuk aplikasi daur ulang Indonesia.

Tugasmu: lihat gambar yang diberikan dan identifikasi SEMUA objek sampah yang terlihat secara terpisah. Untuk setiap objek, tentukan SATU kategori yang paling tepat DAN berikan bounding box yang menandai posisi objek di gambar.

PENTING — setiap objek WAJIB diberikan salah satu dari 6 kategori di bawah. JANGAN PERNAH keluar dari daftar ini:
- "Plastik"  → botol plastik, kantong plastik, kemasan plastik, atau benda berbahan plastik.
- "Kertas"   → kardus, koran, kertas tulis, buku, atau benda berbahan kertas/kayu olahan.
- "Organik"  → sisa makanan, daun, ranting, kayu alami, kulit buah, bahan biodegradable.
- "Logam"    → kaleng minuman/makanan, besi, aluminium, perkakas, atau benda berbahan logam.
- "Kaca"     → botol kaca, pecahan kaca, toples, cermin, atau benda berbahan kaca.
- "Residu"   → popok, tisu bekas, puntung rokok, styrofoam kotor, kabel, elektronik, karet, keramik, atau sampah yang TIDAK bisa didaur ulang.

ATURAN KHUSUS UNTUK OBJEK NON-SAMPAH:
Jika gambar menampilkan objek yang BUKAN sampah (mis. meja, kursi, furnitur, kendaraan, orang, hewan, pakaian, sepatu, peralatan rumah), TETAP pilih kategori sampah yang paling masuk akal jika objek tersebut AKAN dibuang/didaur ulang.

Pertimbangan:
1. Maksimal 5 objek. Jika lebih dari 5, pilih 5 yang paling jelas terlihat.
2. Pilih kategori berdasarkan BAHAN utama objek, bukan fungsinya.
3. Jika TIDAK ada sampah terlihat sama sekali, kembalikan array "items" kosong.
4. Berikan confidence 0.0-1.0 yang jujur berdasarkan seberapa yakin dengan bahan dan kecocokan kategori.
5. Setiap objek dihitung terpisah — jangan gabungkan objek serupa menjadi satu entri.
6. WAJIB berikan "bbox" untuk setiap objek: array 4 angka [y1, x1, y2, x2] yang dinormalisasi ke rentang 0.0-1.0 relatif terhadap ukuran gambar, di mana (0,0) = pojok kiri-atas dan (1,1) = pojok kanan-bawah. y1 = batas atas, x1 = batas kiri, y2 = batas bawah, x2 = batas kanan. Pastikan y2 > y1 dan x2 > x1. Box harus cukup ketat mengelilingi objek (jangan termasuk background luas).

WAJIB jawab HANYA dengan JSON pada format ini, tanpa markdown, tanpa penjelasan tambahan:
{
  "items": [
    {"category": "Plastik", "confidence": 0.92, "reason": "Alasan singkat 1 kalimat dalam Bahasa Indonesia.", "bbox": [0.10, 0.05, 0.85, 0.45]},
    {"category": "Kertas", "confidence": 0.88, "reason": "Alasan singkat 1 kalimat dalam Bahasa Indonesia.", "bbox": [0.15, 0.55, 0.80, 0.95]}
  ]
}
''';
  }

  List<GeminiMultiItem> _parseMultiResponse(String text) {
    try {
      // Same defensive fence-stripping as the single-item parser.
      var cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }

      // Gemini may return either {"items": [...]} or a bare [...].
      final decoded = jsonDecode(cleaned);
      final List<dynamic> rawItems;
      if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        rawItems = decoded['items'] as List;
      } else if (decoded is List) {
        rawItems = decoded;
      } else {
        debugPrint('[Gemini] Multi response unexpected shape: $decoded');
        return [];
      }

      final results = <GeminiMultiItem>[];
      for (final entry in rawItems.take(5)) {
        if (entry is! Map<String, dynamic>) continue;
        final categoryStr = (entry['category'] as String?)?.trim() ?? '';
        final confidence = ((entry['confidence'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 1.0);
        final reason = (entry['reason'] as String?)?.trim() ?? '';

        final category = _parseCategory(categoryStr);
        if (category == null) {
          debugPrint(
              '[Gemini] Skipping unknown category in multi: "$categoryStr"');
          continue;
        }
        // Multi path mirrors single: accept any of the 6 trained categories
        // (incl. Kaca as a learnable type) but skip "lainnya" so uncertain
        // items don't surface as a "Tidak dikenali" card.
        if (category == WasteCategory.lainnya) {
          debugPrint('[Gemini] Skipping "lainnya" item in multi');
          continue;
        }

        final bbox = _parseBbox(entry['bbox']);

        results.add(GeminiMultiItem(
          category: category,
          confidence: confidence,
          reason: reason.isEmpty
              ? 'Terdeteksi sebagai ${category.name} (via AI cloud).'
              : reason,
          bbox: bbox,
        ));
      }

      debugPrint('[Gemini] Multi predicted ${results.length} items '
          '(${results.where((r) => r.bbox != null).length} with bbox)');
      return results;
    } catch (e) {
      debugPrint('[Gemini] Failed to parse multi response: $e');
      debugPrint('[Gemini] Raw response was: $text');
      return [];
    }
  }

  /// Parse Gemini bbox into normalized `[y1, x1, y2, x2]` (0..1), or null if
  /// the field is missing/malformed. Validates order (y2>y1, x2>x1) and clamps
  /// to [0, 1]. Rejects degenerate boxes (< 2% of image in either dimension).
  List<double>? _parseBbox(dynamic raw) {
    if (raw is! List || raw.length != 4) return null;
    final nums = raw.whereType<num>().toList();
    if (nums.length != 4) return null;
    var y1 = nums[0].toDouble();
    var x1 = nums[1].toDouble();
    var y2 = nums[2].toDouble();
    var x2 = nums[3].toDouble();
    // Clamp to valid range
    y1 = y1.clamp(0.0, 1.0);
    x1 = x1.clamp(0.0, 1.0);
    y2 = y2.clamp(0.0, 1.0);
    x2 = x2.clamp(0.0, 1.0);
    // Reject degenerate / too-small boxes (likely hallucinated coordinates)
    if (y2 - y1 < 0.02) return null;
    if (x2 - x1 < 0.02) return null;
    return [y1, x1, y2, x2];
  }

  WasteCategory? _parseCategory(String value) {
    final lower = value.toLowerCase();
    for (final cat in WasteCategory.values) {
      if (cat.name.toLowerCase() == lower) return cat;
    }
    return null;
  }

  String _itemNameFor(WasteCategory category) {
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
}
