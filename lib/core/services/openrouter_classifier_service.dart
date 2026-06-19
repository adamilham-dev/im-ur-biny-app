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
  const CloudClassification(this.category, this.confidence);
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
/// The prompt offers only kaca/kertas/logam/organik/plastik (+ lainnya) — so
/// "residu" simply never appears, no model surgery required.
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

  /// Categories the model is allowed to choose. NOTE: no `residu`.
  static const List<String> _allowed = [
    'kaca',
    'kertas',
    'logam',
    'organik',
    'plastik',
    'lainnya',
  ];

  String get _apiKey => dotenv.maybeGet('OPENROUTER_API_KEY') ?? '';

  bool get isConfigured =>
      _apiKey.isNotEmpty && !_apiKey.contains('YOUR_') && _apiKey != 'sk-or-...';

  String get _prompt =>
      'Kamu pemilah sampah. Pada gambar ini fokus HANYA pada objek sampah yang '
      'paling menonjol di tengah; ABAIKAN latar belakang dan benda lain '
      '(meja, lantai, tangan, dinding, dll). Klasifikasikan objek utama itu '
      'ke TEPAT SATU kategori: ${_allowed.where((c) => c != 'lainnya').join(', ')}. '
      'Kalau tidak jelas atau bukan salah satunya, jawab "lainnya". '
      'JANGAN gunakan kategori "residu". '
      'Balas HANYA JSON valid tanpa teks lain, format: '
      '{"kategori":"<salah satu kategori>","yakin":<angka 0..1>}';

  /// Prompt for detecting MULTIPLE objects (mixed mode).
  String get _multiPrompt =>
      'Kamu detektor sampah. Temukan SEMUA objek sampah yang berbeda pada gambar '
      '(maksimal 5). ABAIKAN latar belakang, pakaian, tangan, meja, dan lantai. '
      'Untuk tiap objek beri kategori: ${_allowed.where((c) => c != 'lainnya').join(', ')}. '
      'Kalau satu objek tidak yakin, pakai "lainnya". JANGAN pakai "residu". '
      'Bounding box WAJIB dalam koordinat ternormalisasi 0..1000 (bilangan bulat), '
      'origin di pojok KIRI-ATAS, format [x1,y1,x2,y2] = kiri,atas,kanan,bawah, '
      'dan harus SEPAS mungkin mengikuti tepi objek (jangan kelebaran). '
      'Balas HANYA JSON array valid tanpa teks lain, contoh: '
      '[{"kategori":"plastik","yakin":0.9,"box":[120,200,400,700]}]';

  /// Classify the single main object in [imageBytes]. Null if not configured
  /// or on failure — caller falls back to the on-device classifier.
  Future<CloudClassification?> classify(Uint8List imageBytes) async {
    if (!isConfigured) return null;
    final b64 = _downscaledJpegBase64(imageBytes);
    if (b64 == null) return null;
    final content = await _postChat(_prompt, b64, maxTokens: 60);
    if (content == null) return null;
    return _parseSingle(content);
  }

  /// Detect + classify ALL waste objects in [imageBytes] in one call (mixed
  /// mode). Null if not configured / on failure; empty list if no waste seen.
  Future<List<CloudDetection>?> classifyMultiple(Uint8List imageBytes) async {
    if (!isConfigured) return null;
    // Higher resolution for multi-object localization (boxes are sharper when
    // the model sees more detail). Single-object classify stays at 512.
    final b64 = _downscaledJpegBase64(imageBytes, maxDim: 1024);
    if (b64 == null) return null;
    final content = await _postChat(_multiPrompt, b64, maxTokens: 600);
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
      req.headers.set('HTTP-Referer', 'https://trashscan.local');
      req.headers.set('X-Title', 'TrashScan');
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

  /// Extract a single {kategori,yakin} JSON object from [content].
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
      final label = (obj['kategori'] as String?)?.toLowerCase().trim() ?? '';
      final conf = (obj['yakin'] as num?)?.toDouble() ?? 0.0;
      if (!_allowed.contains(label)) {
        return const CloudClassification(WasteCategory.lainnya, 0.0);
      }
      return CloudClassification(
        WasteCategory.fromStableId(label),
        conf.clamp(0.0, 1.0),
      );
    } catch (e) {
      debugPrint('[OpenRouter] parse error: $e');
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
      final out = <CloudDetection>[];
      for (final e in arr.take(5)) {
        if (e is! Map) continue;
        final label = (e['kategori'] as String?)?.toLowerCase().trim() ?? '';
        // Keep every detected object: an unknown/foreign category becomes
        // "lainnya" (a "Tidak dikenali" card) instead of being silently dropped.
        final cat = _allowed.contains(label)
            ? WasteCategory.fromStableId(label)
            : WasteCategory.lainnya;
        final conf = (e['yakin'] as num?)?.toDouble() ?? 0.0;
        List<double>? box;
        final b = e['box'];
        if (b is List && b.length == 4 && b.every((v) => v is num)) {
          final raw = b.map((v) => (v as num).toDouble()).toList();
          // Gemma returns boxes in 0..1000 normalized coords (not 0..1). Scale
          // down to 0..1 when any value exceeds 1.
          final maxv = raw.reduce((a, c) => a > c ? a : c);
          final scale = maxv > 1.0 ? 1000.0 : 1.0;
          box = raw.map((v) => (v / scale).clamp(0.0, 1.0)).toList();
        }
        out.add(CloudDetection(cat, conf.clamp(0.0, 1.0), box));
      }
      debugPrint('[OpenRouter] parsed ${out.length} of ${arr.length} entries');
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
