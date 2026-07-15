import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;

import '../models/waste_category.dart';

/// Result of a single-object cloud classification attempt.
class CloudClassification {
  final WasteCategory category;
  final double confidence;

  /// Top-N probability breakdown keyed by display name (e.g. {'Plastik': 0.8,
  /// 'Logam': 0.15}). Empty when the model returned only a single candidate
  /// (legacy format) — callers fall back to `{category.name: confidence}`.
  /// Used by /low-confidence "KEMUNGKINAN KATEGORI" to render the top-2 bars.
  final Map<String, double> probabilities;
  const CloudClassification(
    this.category,
    this.confidence, {
    this.probabilities = const {},
  });
}

/// One object found by the multi-object cloud detector.
class CloudDetection {
  final WasteCategory category;
  final double confidence;

  /// Normalized box [x1, y1, x2, y2] in 0..1 (left, top, right, bottom), or
  /// null if the model returned no box. Used only to crop a thumbnail for the
  /// UI — the category comes from the model seeing the whole image.
  final List<double>? boxNorm;
  const CloudDetection(this.category, this.confidence, this.boxNorm);
}

/// Classifies a waste image via a multimodal LLM on OpenRouter (Gemma).
///
/// Why cloud: lets us change the label set with a PROMPT instead of retraining.
/// The prompt offers kaca/kertas/logam/organik/plastik/residu (+ lainnya).
/// `kaca` is intentionally included so glass items surface during the initial
/// scan — the caller (ScanNotifier._suppressKaca) then normalizes kaca to
/// "lainnya"/"Tidak dikenali" for the UI. Without allowing kaca here, glass
/// would either be misclassified as a wrong high-confidence category (residu,
/// logam, etc.) or skipped entirely, never reaching the "Tidak dikenali"
/// state the user expects.
///
/// Transport: plain OpenAI-compatible chat/completions over [HttpClient] — no
/// new dependency. **Inert** until `OPENROUTER_API_KEY` is set in `.env`
/// ([isConfigured] is false → callers fall back to the on-device classifier).
/// Never throws to callers; returns null on any failure so the caller can fall
/// back gracefully.
class OpenRouterClassifierService {
  OpenRouterClassifierService._();
  static final OpenRouterClassifierService instance =
      OpenRouterClassifierService._();

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'google/gemma-4-26b-a4b-it';

  /// Categories the model is allowed to choose. `kaca` is included so glass
  /// objects can surface during scan; downstream `_suppressKaca` (scan_provider)
  /// normalizes them to "Tidak dikenali" for the user-facing UI.
  static const List<String> _allowed = [
    'kaca',
    'kertas',
    'logam',
    'organik',
    'plastik',
    'residu',
    'lainnya',
  ];

  String get _apiKey => dotenv.maybeGet('OPENROUTER_API_KEY') ?? '';

  bool get isConfigured =>
      _apiKey.isNotEmpty && !_apiKey.contains('YOUR_') && _apiKey != 'sk-or-...';

  String get _prompt =>
      'Kamu pemilah sampah. Pada gambar ini fokus HANYA pada objek sampah yang '
      'paling menonjol di tengah; ABAIKAN latar belakang dan benda lain '
      '(meja, lantai, tangan, dinding, dll). Klasifikasikan objek utama itu '
      'ke TEPAT SATU kategori utama: ${_allowed.where((c) => c != 'lainnya').join(', ')}. '
      'Bila benda berbahan kaca (botol kaca, pecahan kaca, toples, cermin, '
      'gelas/cangkir kaca), jawab "kaca". '
      'Kalau tidak jelas atau bukan salah satunya, jawab "lainnya". '
      'Selain kategori utama, berikan JUGA kategori kedua yang paling mungkin. '
      'Kategori kedua WAJIB salah satu dari 5 kategori daur ulang yang '
      'terlihat di aplikasi: plastik, kertas, logam, organik, residu. '
      'DILARANG menggunakan "lainnya" atau "kaca" sebagai kategori kedua. '
      'Balas HANYA JSON valid tanpa teks lain, format: '
      '{"kandidat":[{"kategori":"<kategori paling mungkin>","yakin":<0..1>},'
      '{"kategori":"<kategori kedua paling mungkin>","yakin":<0..1>}]}';

  /// Prompt for detecting MULTIPLE objects (mixed mode).
  String get _multiPrompt =>
      'Kamu detektor sampah yang TELITI. Hitung SEMUA objek sampah yang terlihat '
      'pada gambar (maksimal 5). ATURAN PALING PENTING: SETIAP objek sampah yang '
      'terlihat WAJIB di-output sebagai entri terpisah — JANGAN PERNAH dilewati. '
      'ABAIKAN latar belakang (lantai, dinding, meja, langit) dan anggota tubuh '
      '(tangan, kaki, pakaian). Untuk tiap objek WAJIB pilih TEPAT SATU dari '
      '6 kategori ini: ${_allowed.where((c) => c != 'lainnya').join(', ')}. '
      'Bila benda berbahan kaca (botol kaca, pecahan kaca, toples, cermin, '
      'gelas/cangkir kaca), jawab "kaca". '
      'Pilih yang paling mendekati meskipun ragu — JANGAN pakai kategori lain '
      'selain 6 di atas (tidak ada "lainnya"). Tulis yakin '
      '0.0-1.0 sesuai keyakinanmu; sistem akan menandai sendiri jika keyakinan '
      'terlalu rendah. '
      'Bounding box WAJIB untuk setiap objek (jangan kosong), dalam koordinat '
      'ternormalisasi 0..1000 (bilangan bulat), origin di pojok KIRI-ATAS, '
      'format [x1,y1,x2,y2] = kiri,atas,kanan,bawah, dan harus SEPAS mungkin '
      'mengikuti tepi objek (jangan kelebaran). '
      'Sebelum jawab, hitung ulang jumlah objek yang kamu temukan dan pastikan '
      'semua sudah ada di output. '
      'Balas HANYA JSON array valid tanpa teks lain, contoh: '
      '[{"kategori":"plastik","yakin":0.9,"box":[120,200,400,700]},'
      '{"kategori":"kaca","yakin":0.8,"box":[500,300,700,800]}]';

  /// The 5 user-facing "daur" categories (what's selectable in manual
  /// correction). Used to filter the top-2 breakdown shown on the
  /// /low-confidence "KEMUNGKINAN KATEGORI" card — excludes "kaca"
  /// (suppressed elsewhere, never shown to the user as a real option) and
  /// "lainnya" (not a real classification, just a fallback signal).
  static const List<String> _userFacing = [
    'plastik',
    'kertas',
    'logam',
    'organik',
    'residu',
  ];

  /// Categories allowed in the ANALYZING escalation path (the "Analisis
  /// dengan AI" button from /unknown-detected). Unlike the fast path, this
  /// INCLUDES "kaca" — when the AI confidently returns glass here, it flows
  /// to /conclusion-new → /dataset-saved as a learnable 6th category.
  static const List<String> _analyzingAllowed = [
    'kaca',
    'kertas',
    'logam',
    'organik',
    'plastik',
    'residu',
  ];

  /// Prompt for the ANALYZING escalation path. Offers all 6 trained
  /// categories (incl. kaca) because this is the "AI learns a new type"
  /// flow — glass can surface as a new category here, unlike the fast path.
  /// "lainnya" is NOT offered: a non-guess becomes a parse-null → /low-confidence.
  String get _analyzingPrompt =>
      'Kamu asisten pemilah sampah yang sedang belajar kategori baru. Lihat '
      'gambar ini dengan teliti dan tentukan SATU kategori sampah yang paling '
      'tepat untuk objek utama di tengah; ABAIKAN latar belakang. Pilih TEPAT '
      'SATU dari: ${_analyzingAllowed.join(', ')}. Bila benda berbahan kaca '
      '(botol kaca, pecahan kaca, toples, cermin), jawab "kaca". Bila tidak '
      'yakin sama sekali atau bukan sampah, jawab "lainnya". '
      'Selain kategori utama, berikan JUGA kategori kedua yang paling mungkin. '
      'Kategori kedua WAJIB salah satu dari 5 kategori daur ulang yang '
      'terlihat di aplikasi: plastik, kertas, logam, organik, residu. '
      'DILARANG menggunakan "lainnya" atau "kaca" sebagai kategori kedua. '
      'Balas HANYA JSON valid tanpa teks lain, format: '
      '{"kandidat":[{"kategori":"<kategori paling mungkin>","yakin":<0..1>},'
      '{"kategori":"<kategori kedua paling mungkin>","yakin":<0..1>}],'
      '"alasan":"<alasan singkat 1 kalimat dalam Bahasa Indonesia>"}';

  /// Classify the single main object in [imageBytes]. Null if not configured
  /// or on failure — caller falls back to the on-device classifier.
  Future<CloudClassification?> classify(Uint8List imageBytes) async {
    if (!isConfigured) return null;
    final b64 = _downscaledJpegBase64(imageBytes);
    if (b64 == null) return null;
    final content = await _postChat(_prompt, b64, maxTokens: 120);
    if (content == null) return null;
    return _parseSingle(content);
  }

  /// Escalation-path classify (the "Analisis dengan AI" button). Unlike
  /// [classify], this OFFERS "kaca" as a valid category — a confident glass
  /// result flows to /conclusion-new as a learnable new type. "lainnya" is
  /// rejected (returns null) so the caller routes to /low-confidence rather
  /// than presenting "tidak dikenali" as a new category. Null on failure.
  Future<CloudClassification?> classifyAnalyzing(Uint8List imageBytes) async {
    if (!isConfigured) return null;
    final b64 = _downscaledJpegBase64(imageBytes);
    if (b64 == null) return null;
    final content = await _postChat(_analyzingPrompt, b64, maxTokens: 200);
    if (content == null) return null;
    return _parseAnalyzing(content);
  }

  /// Detect + classify ALL waste objects in [imageBytes] in one call (mixed
  /// mode). Null if not configured / on failure; empty list if no waste seen.
  Future<List<CloudDetection>?> classifyMultiple(Uint8List imageBytes) async {
    if (!isConfigured) return null;
    // Higher resolution for multi-object localization (boxes are sharper when
    // the model sees more detail). Single-object classify stays at 512.
    final b64 = _downscaledJpegBase64(imageBytes, maxDim: 1024);
    if (b64 == null) return null;
    final content = await _postChat(_multiPrompt, b64, maxTokens: 800);
    if (content == null) return null;
    return _parseMulti(content);
  }

  /// POST one vision message to OpenRouter; returns the model's message content
  /// string, or null on any failure (never throws).
  Future<String?> _postChat(
    String prompt,
    String b64, {
    required int maxTokens,
  }) async {
    try {
      final body = jsonEncode({
        'model': _model,
        'temperature': 0,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64'},
              },
            ],
          },
        ],
      });
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('HTTP-Referer', 'https://imurbiny.local');
      req.headers.set('X-Title', 'ImUrBiny');
      req.add(utf8.encode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      client.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('[OpenRouter] HTTP ${resp.statusCode}: $text');
        return null;
      }
      final root = jsonDecode(text) as Map<String, dynamic>;
      return ((root['choices'] as List).first
          as Map<String, dynamic>)['message']['content'] as String;
    } catch (e) {
      debugPrint('[OpenRouter] request error: $e');
      return null;
    }
  }

  /// Extract a top-2 breakdown from [content]. Accepts the new
  /// `{"kandidat":[{kategori,yakin},...]}` format AND the legacy
  /// `{"kategori":"...","yakin":0.x}` single-object format for backward
  /// compatibility with older model responses.
  CloudClassification? _parseSingle(String content) {
    try {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start < 0 || end <= start) {
        debugPrint('[OpenRouter] no JSON object in: $content');
        return null;
      }
      final obj =
          jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;

      // New format: {"kandidat": [{kategori, yakin}, ...]}
      final kandidat = obj['kandidat'];
      if (kandidat is List && kandidat.isNotEmpty) {
        final probs = <String, double>{};
        for (final e in kandidat) {
          if (e is! Map) continue;
          final label = (e['kategori'] as String?)?.toLowerCase().trim() ?? '';
          final conf = (e['yakin'] as num?)?.toDouble() ?? 0.0;
          if (_allowed.contains(label)) {
            // Last-write-wins on duplicate labels — keeps the highest if the
            // model lists the same category twice.
            probs[label] = conf.clamp(0.0, 1.0);
          }
        }
        if (probs.isEmpty) {
          return const CloudClassification(WasteCategory.lainnya, 0.0);
        }
        final sorted = probs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.first;
        // Card breakdown: only the 5 user-facing daur categories. "kaca" and
        // "lainnya" are dropped even if the AI returned them — kaca is
        // suppressed elsewhere (never shown as a real option), lainnya is a
        // fallback signal, not a classification. If top-1 itself is kaca /
        // lainnya, the probabilities map will be empty and the caller falls
        // back to the single-entry shape; that's fine because such results
        // route to /unknown-detected, never reaching the card.
        final cardProbs = {
          for (final e
              in sorted.where((e) => _userFacing.contains(e.key)).take(2))
            e.key: e.value,
        };
        return CloudClassification(
          WasteCategory.fromStableId(top.key),
          top.value,
          probabilities: cardProbs,
        );
      }

      // Legacy fallback: single {kategori, yakin}
      final label = (obj['kategori'] as String?)?.toLowerCase().trim() ?? '';
      final conf = (obj['yakin'] as num?)?.toDouble() ?? 0.0;
      if (!_allowed.contains(label)) {
        return const CloudClassification(WasteCategory.lainnya, 0.0);
      }
      return CloudClassification(
        WasteCategory.fromStableId(label),
        conf.clamp(0.0, 1.0),
        probabilities: _userFacing.contains(label)
            ? {label: conf.clamp(0.0, 1.0)}
            : const {},
      );
    } catch (e) {
      debugPrint('[OpenRouter] parse error: $e');
      return null;
    }
  }

  /// Parser for the ANALYZING escalation path. Accepts the 6 trained
  /// categories incl. "kaca" (a learnable new type). A foreign label or
  /// "lainnya" → treated as "tidak dikenali" (WasteCategory.lainnya, conf 0.0)
  /// so the item still resolves — NOT null. Returning null here was a bug: it
  /// made the re-analyzed item always fall through to "tidak dikenali"
  /// regardless of what the AI actually answered, because the previous
  /// on-device result stayed in state.
  ///
  /// Supports the new `{"kandidat":[...]}` top-2 format AND the legacy
  /// single-object format.
  CloudClassification? _parseAnalyzing(String content) {
    try {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start < 0 || end <= start) {
        debugPrint('[OpenRouter] analyzing: no JSON object in: $content');
        return null;
      }
      final obj =
          jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;

      // New format: {"kandidat": [{kategori, yakin}, ...]}
      final kandidat = obj['kandidat'];
      if (kandidat is List && kandidat.isNotEmpty) {
        final probs = <String, double>{};
        for (final e in kandidat) {
          if (e is! Map) continue;
          final label = (e['kategori'] as String?)?.toLowerCase().trim() ?? '';
          final conf = (e['yakin'] as num?)?.toDouble() ?? 0.0;
          // _analyzingAllowed excludes "lainnya" — a "lainnya" answer in any
          // slot is treated as a foreign label and dropped here. If ALL slots
          // drop, we fall through to the lainnya sentinel below.
          if (_analyzingAllowed.contains(label)) {
            probs[label] = conf.clamp(0.0, 1.0);
          }
        }
        if (probs.isEmpty) {
          debugPrint('[OpenRouter] analyzing: all kandidat foreign/lainnya → lainnya');
          return const CloudClassification(WasteCategory.lainnya, 0.0);
        }
        final sorted = probs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.first;
        // Same user-facing filter as _parseSingle — see comment there.
        final cardProbs = {
          for (final e
              in sorted.where((e) => _userFacing.contains(e.key)).take(2))
            e.key: e.value,
        };
        return CloudClassification(
          WasteCategory.fromStableId(top.key),
          top.value,
          probabilities: cardProbs,
        );
      }

      // Legacy fallback: single {kategori, yakin}
      final label = (obj['kategori'] as String?)?.toLowerCase().trim() ?? '';
      final conf = (obj['yakin'] as num?)?.toDouble() ?? 0.0;
      if (!_analyzingAllowed.contains(label)) {
        // Unknown / "lainnya" — resolve as tidakedikenali (conf 0.0) but still
        // RETURN it so the caller can update the item. Do not null-out.
        debugPrint('[OpenRouter] analyzing: foreign/unknown label "$label" → lainnya');
        return const CloudClassification(WasteCategory.lainnya, 0.0);
      }
      return CloudClassification(
        WasteCategory.fromStableId(label),
        conf.clamp(0.0, 1.0),
        probabilities: _userFacing.contains(label)
            ? {label: conf.clamp(0.0, 1.0)}
            : const {},
      );
    } catch (e) {
      debugPrint('[OpenRouter] analyzing parse error: $e');
      return null;
    }
  }

  /// Extract a JSON array of detections from [content].
  List<CloudDetection> _parseMulti(String content) {
    try {
      final start = content.indexOf('[');
      final end = content.lastIndexOf(']');
      if (start < 0 || end <= start) {
        debugPrint('[OpenRouter] no JSON array in: $content');
        return const [];
      }
      final arr = jsonDecode(content.substring(start, end + 1)) as List;
      debugPrint('[OpenRouter] multi raw response: $arr');
      final out = <CloudDetection>[];
      for (final e in arr.take(5)) {
        if (e is! Map) continue;
        final label = (e['kategori'] as String?)?.toLowerCase().trim() ?? '';
        // The prompt forces the model to pick from the 6 trained categories
        // (kaca/kertas/logam/organik/plastik/residu — no "lainnya"). If the
        // model still returns a foreign label or the forbidden "lainnya",
        // coerce to the catch-all "residu" so the item still resolves. Kaca
        // IS a valid label here — downstream `_suppressKaca` (scan_provider)
        // normalizes kaca to "Tidak dikenali" for the UI.
        final cat = _allowed.contains(label) && label != 'lainnya'
            ? WasteCategory.fromStableId(label)
            : WasteCategory.residu;
        // Use the model's own confidence. The UI threshold (< 0.45) decides
        // whether the card shows as readable / unsure / "Tidak dikenali".
        final conf = (e['yakin'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
        List<double>? box;
        final b = e['box'];
        if (b is List && b.length == 4 && b.every((v) => v is num)) {
          final raw = b.map((v) => (v as num).toDouble()).toList();
          // Gemma returns boxes in 0..1000 normalized coords (not 0..1). Scale
          // down to 0..1 when any value exceeds 1.
          final maxv = raw.reduce((a, c) => a > c ? a : c);
          final scale = maxv > 1.0 ? 1000.0 : 1.0;
          box = raw.map((v) => (v / scale).clamp(0.0, 1.0)).toList();
        } else {
          debugPrint('[OpenRouter] entry "$label" has missing/invalid box: $b');
        }
        debugPrint('[OpenRouter] entry → ${cat.name} conf=${conf.toStringAsFixed(2)} '
            'box=${box != null ? "yes" : "null"}');
        out.add(CloudDetection(cat, conf.clamp(0.0, 1.0), box));
      }
      debugPrint('[OpenRouter] parsed ${out.length} of ${arr.length} entries '
          '(${out.where((d) => d.boxNorm != null).length} with box)');
      return out;
    } catch (e) {
      debugPrint('[OpenRouter] parseMulti error: $e');
      return const [];
    }
  }

  /// Decode → resize so the longest side ≤ [maxDim] → JPEG → base64. Smaller =
  /// faster + cheaper; larger = better localization for box detection.
  String? _downscaledJpegBase64(Uint8List imageBytes, {int maxDim = 512}) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;
    final maxSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = maxSide > maxDim
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDim : null,
            height: decoded.height > decoded.width ? maxDim : null,
          )
        : decoded;
    return base64Encode(img.encodeJpg(resized, quality: 85));
  }
}
