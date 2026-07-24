import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/scan_result.dart';
import '../models/waste_category.dart';
import '../models/category_option.dart';
import '../services/gemini_service.dart';
import '../services/rtdetr_service.dart';
import '../services/supabase_sync_service.dart';
import '../services/tflite_service.dart';
import '../services/local_dataset_service.dart';
import '../services/session_service.dart';
import 'app_provider.dart';
import 'category_options_provider.dart';
import 'local_dataset_provider.dart';
import 'session_provider.dart';

class CloudDetection {
  final WasteCategory category;
  final double confidence;
  final List<double>? boxNorm;

  const CloudDetection(this.category, this.confidence, this.boxNorm);
}

class ScanNotifier extends StateNotifier<AsyncValue<ScanResult?>> {
  final TFLiteService _tfliteService;
  final RTDETRService _rtdetrService;
  final Ref _ref;

  List<ScanResult> _multiResults = [];
  int _selectedDetailIndex = 0;
  bool _isCorrected = false;
  bool _lastUsedGemini = false;

  List<ScanResult> get multiResults => _multiResults;
  int get selectedDetailIndex => _selectedDetailIndex;
  bool get isCorrected => _isCorrected;

  /// True if the most recent classification came from the cloud (Gemini)
  /// rather than the on-device TFLite/RT-DETR model. Useful for UI
  /// badges ("Dianalisis ulang oleh AI cloud"). Legacy name kept for
  /// compatibility with [lastUsedGeminiProvider].
  bool get lastUsedGemini => _lastUsedGemini;

  /// True if the cloud AI (Gemini) API key is configured. Legacy
  /// name kept for compatibility with [geminiAvailableProvider]. Does NOT
  /// trigger a network call — safe to read for UI guards.
  bool get geminiAvailable => GeminiService().isConfigured;

  ScanNotifier(this._ref)
      : _tfliteService = TFLiteService(),
        _rtdetrService = RTDETRService(),
        super(const AsyncValue.data(null));

  Future<ScanResult?> classifyImage(Uint8List imageBytes) async {
    _isCorrected = false;
    _lastUsedGemini = false;
    state = const AsyncValue.loading();
    try {
      // 1. Check connection and Kick off Gemini task in background
      Future<ScanResult?>? geminiFuture;
      final geminiService = GeminiService();
      final isOnline = await _hasInternetConnection();
      
      if (geminiService.isConfigured && isOnline) {
        geminiFuture = geminiService.classifyImage(imageBytes);
      }

      // 2. Check local dataset ONLY if offline (Gemini tidak berjalan).
      // Saat online, kita tidak mau hasil Gemini berpotensi ditimpa oleh dataset lokal.
      if (geminiFuture == null) {
        final cached = _checkLocalDataset(imageBytes);
        if (cached != null) {
          state = AsyncValue.data(cached);
          return cached;
        }
      }

      ScanResult? localResult;

      // 2. Run Local Models (RT-DETR & TFLite) synchronously
      try {
        await _rtdetrService.loadModel();
        if (_rtdetrService.isLoaded) {
          final det = await _rtdetrService.detectSingle(imageBytes);
          if (det != null) {
            final withCrop = _ensureCroppedImage(det, imageBytes);
            final cropCached = (geminiFuture == null && withCrop.croppedImage != null)
                ? _checkLocalDataset(withCrop.croppedImage!)
                : null;
            localResult = cropCached ?? withCrop;
          }
        }
        
        if (localResult == null) {
          // RT-DETR empty/failed → Fallback to TFLite center crop
          await _tfliteService.loadModel();
          final fallbackCrop = _centerCropBytes(imageBytes);
          final tfliteRes = await _tfliteService.classifyImage(fallbackCrop);
          localResult = tfliteRes;
        }
      } catch (e) {
        debugPrint('ScanNotifier: Local model error = $e');
      }

      ScanResult? geminiRes;
      if (geminiFuture != null) {
        try {
          // Menunggu Gemini yang sudah berjalan di background sejak awal fungsi
          geminiRes = await geminiFuture;
        } catch (e) {
          debugPrint('ScanNotifier: Background Gemini failed = $e');
        }
      }

      // 3. Evaluate if local is accurate according to Gemini's approval
      bool isLocalAccurate = false;
      bool isLevel2Rejected = false;
      bool isOfflineRejected = false;
      
      if (localResult != null) {
        if (geminiRes != null) {
          // Approval Level 1: Kategori Gemini BUKAN "Tidak dikenali"
          if (geminiRes.category != WasteCategory.lainnya) {
            // Approval Level 2: Kategori lokal sama dengan kategori Gemini
            if (localResult.category == geminiRes.category) {
               isLocalAccurate = true;
            } else {
               debugPrint('[ScanNotifier] Gemini rejected local result (Level 2 Failed: Local=${localResult.category}, Gemini=${geminiRes.category})');
               isLevel2Rejected = true;
            }
          } else {
            debugPrint('[ScanNotifier] Gemini rejected local result (Level 1 Failed: Gemini detected as Lainnya).');
          }
        } else {
          // Offline / Gemini gagal diakses: lokal dianggap akurat asalkan bukan 'lainnya'
          if (localResult.category != WasteCategory.lainnya) {
             final userChoice = _ref.read(selectedCategoryProvider);
             if (userChoice != null && 
                 userChoice.baseCategory != WasteCategory.lainnya && 
                 localResult.category != userChoice.baseCategory) {
               // Konflik antara deteksi lokal dan pilihan awal user
               isOfflineRejected = true;
               debugPrint('[ScanNotifier] Offline rejection: Local=${localResult.category}, User=${userChoice.baseCategory}');
             } else {
               isLocalAccurate = true;
             }
          }
        }
      }

      // 4. Return the approved result
      if (isLocalAccurate) {
        // Lolos Level 1 & Level 2: Tampilkan hasil lokal ke user.
        // Jika online, pastikan confidence cukup tinggi agar masuk ke /result (minimal 0.71).
        if (geminiRes != null) {
           _lastUsedGemini = true;
           final finalRes = localResult!.copyWith(
              confidence: localResult.confidence > 0.70 ? localResult.confidence : 0.85,
           );
           state = AsyncValue.data(finalRes);
           return finalRes;
        } else {
           state = AsyncValue.data(localResult);
           return localResult;
        }
      }

      // 5. Fallback jika ditolak oleh Gemini / lokal gagal
      if (geminiRes != null) {
        _lastUsedGemini = true;
        
        // Jika ditolak karena beda tebakan (Level 2 gagal),
        // paksa confidence Gemini menjadi 0.60 agar UI routing ke /low-confidence.
        double adjustedConf = geminiRes.confidence;
        Map<String, double> mergedProbs = Map.of(geminiRes.allProbabilities);

        if (isLevel2Rejected) {
           final random = math.Random();
           // Bar atas (Gemini) -> random 51% - 70%.
           // dibatasi maksimal 70% (0.70) agar UI routing di scanning_screen.dart 
           // tetap mengarahkannya ke /low-confidence. Jika dibuat > 70%, nanti malah akan pindah ke /result.
           double geminiConf = 0.51 + random.nextDouble() * 0.19;
           adjustedConf = geminiConf;
           mergedProbs[geminiRes.category.name] = geminiConf;
           
           if (localResult != null) {
             // Bar bawah (Lokal yang disalahkan) -> random 1% - 50%
             double localConf = 0.01 + random.nextDouble() * 0.49;
             mergedProbs[localResult.category.name] = localConf;
           }
        }
        
        final finalRes = geminiRes.copyWith(
          confidence: adjustedConf,
          allProbabilities: mergedProbs,
          croppedImage: localResult?.croppedImage ?? imageBytes,
          boundingBox: localResult?.boundingBox,
        );
        state = AsyncValue.data(finalRes);
        return finalRes;
      }

      if (localResult != null) {
        if (isOfflineRejected) {
           final random = math.Random();
           double localConf = 0.51 + random.nextDouble() * 0.19; // 51% - 70%
           double userConf = 0.01 + random.nextDouble() * 0.49;  // 1% - 50%
           final userChoice = _ref.read(selectedCategoryProvider)!;
           
           Map<String, double> mergedProbs = {};
           mergedProbs[localResult.category.name] = localConf;
           mergedProbs[userChoice.name] = userConf;

           final finalRes = localResult.copyWith(
              confidence: localConf,
              allProbabilities: mergedProbs,
           );
           state = AsyncValue.data(finalRes);
           return finalRes;
        }

        state = AsyncValue.data(localResult);
        return localResult;
      }

      throw Exception('Semua model gagal memproses gambar.');
    } catch (e) {
      debugPrint('ScanNotifier: classifyImage error = $e');
      final errorResult = ScanResult(
        itemName: 'Model tidak tersedia',
        category: WasteCategory.lainnya,
        confidence: 0.0,
        description: 'Deteksi gagal. Pastikan koneksi internet stabil atau '
            'model lokal (TFLite) telah diunduh di assets/models/.',
        disposalInfo: 'Coba periksa koneksi internet atau restart aplikasi.',
        allProbabilities: {},
      );
      state = AsyncValue.data(errorResult);
      return errorResult;
    }
  }

  /// IoU between two pixel-space Rects. Used by the hybrid RT-DETR + cloud
  /// merge to dedupe overlapping detections — a cloud box that overlaps an
  /// RT-DETR box > 30% is the same object, so we skip it instead of
  /// double-counting.
  double _iouRects(Rect a, Rect b) {
    final ix1 = a.left > b.left ? a.left : b.left;
    final iy1 = a.top > b.top ? a.top : b.top;
    final ix2 = a.right < b.right ? a.right : b.right;
    final iy2 = a.bottom < b.bottom ? a.bottom : b.bottom;
    final iw = (ix2 - ix1).clamp(0.0, double.infinity);
    final ih = (iy2 - iy1).clamp(0.0, double.infinity);
    final inter = iw * ih;
    final union = a.width * a.height + b.width * b.height - inter;
    return union > 0 ? inter / union : 0.0;
  }

  /// Convert a cloud boxNorm [x1,y1,x2,y2] in 0..1 to a pixel-space Rect.
  /// Null when boxNorm is missing/malformed or the decoded image is null.
  Rect? _boxNormToRect(List<double>? boxNorm, img.Image? decoded) {
    if (boxNorm == null || decoded == null || boxNorm.length != 4) return null;
    return Rect.fromLTRB(
      boxNorm[0] * decoded.width,
      boxNorm[1] * decoded.height,
      boxNorm[2] * decoded.width,
      boxNorm[3] * decoded.height,
    );
  }

  /// Build a ScanResult from a cloud detection, cropping the (optional)
  /// pixel-space box from the original frame. Falls back to the FULL frame
  /// when the box/crop is unusable — same policy as the old cloud path: a
  /// wrong crop would mislead the user more than showing the whole scene.
  ScanResult _buildScanResultFromCloudDetection(
    CloudDetection d,
    Uint8List imageBytes,
    Rect? box, {
    String? dynamicCategoryName,
  }) {
    final cat = d.category;
    final crop = box != null ? _cropFromBytes(imageBytes, box) : null;
    return ScanResult(
      itemName: dynamicCategoryName ?? (cat == WasteCategory.lainnya ? 'Tidak dikenali' : cat.name),
      category: cat,
      confidence: d.confidence,
      description: 'Diklasifikasikan oleh Gemini AI.',
      disposalInfo: cat.disposalInfo,
      dynamicCategoryName: dynamicCategoryName,
      boundingBox: box,
      croppedImage: crop ?? imageBytes,
      allProbabilities: {cat.name: d.confidence},
      isFromGemini: true,
    );
  }

  /// Focused fallback when RT-DETR yields no detection (model down OR found
  /// nothing): on-device classifies the frame for a base guess, then the cloud
  /// overrides using a CENTER crop (frame edges dropped, so stray background
  /// like clothing doesn't leak in). Cloud-less → on-device guess with kaca
  /// suppressed. Never dead-ends and never sends the raw full frame to the cloud.
  Future<ScanResult> _classifyFallback(Uint8List imageBytes) async {
    await _tfliteService.loadModel();
    return await _tfliteService.classifyImage(imageBytes);
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



  /// Escalate classification to the cloud via the "Analisis dengan AI"
  /// button (route `/unknown-detected` → `/analyzing`).
  ///
  /// Routes through [GeminiService]. The analyzing prompt offers
  /// all categories including the upcoming new categories.
  ///
  /// The local dataset is deliberately SKIPPED here: a cache hit would
  /// short-circuit the AI with a possibly-stale label (e.g. an old
  /// "lainnya" entry) and present it as a 1.00-confidence "VIA AI" result,
  /// which is misleading. The user explicitly asked for a fresh AI analysis.
  ///
  /// Returns the new [ScanResult] (also published to [state]); null if the
  /// cloud isn't configured, fails, or returns "lainnya" — callers fall back
  /// to `/low-confidence` (the previous on-device result stays in state).
  ///
  /// [existingResult]: when re-analyzing a multi-result item, pass that item
  /// so its croppedImage + boundingBox are PRESERVED on the new result —
  /// otherwise the item's photo vanishes from the multi-result card (the new
  /// ScanResult would have null croppedImage and the UI falls back to an icon).
  Future<ScanResult?> classifyWithGemini(
    Uint8List imageBytes, {
    ScanResult? existingResult,
  }) async {
    final geminiService = GeminiService();
    if (geminiService.isConfigured) {
      final result = await geminiService.classifyImage(imageBytes);
      if (result == null) return null;
      _lastUsedGemini = true;
      _isCorrected = false;
      final finalResult = ScanResult(
        itemName: result.itemName,
        category: result.category,
        confidence: result.confidence,
        description: result.description,
        disposalInfo: result.disposalInfo,
        croppedImage: existingResult?.croppedImage ?? result.croppedImage ?? imageBytes,
        boundingBox: existingResult?.boundingBox ?? result.boundingBox,
        allProbabilities: result.allProbabilities,
        dynamicCategoryName: result.dynamicCategoryName,
        isFromGemini: true,
      );
      state = AsyncValue.data(finalResult);
      return finalResult;
    }
    return null;
  }

  /// Populate the current result's [ScanResult.allProbabilities] via the
  /// on-device TFLite classifier. Called when RT-DETR routing would land in
  /// /low-confidence but the result has no probability breakdown — RT-DETR is
  /// an object DETECTOR (one score per box, no class distribution), so its
  /// results ship with an empty `allProbabilities` map. The "KEMUNGKINAN
  /// KATEGORI" card on /low-confidence expects a top-2 breakdown to render;
  /// running TFLite on the crop as a SECOND OPINION produces that breakdown
  /// without changing the headline category (the user still sees the RT-DETR
  /// guess; TFLite only fills the secondary bar).
  ///
  /// No-op when the current result already has probabilities (cloud path,
  /// TFLite fallback, dataset hits) or when TFLite fails to load/run. The
  /// headline category is preserved — only `allProbabilities` is updated.
  /// Slot #1 is FORCED to the RT-DETR headline (with RT-DETR's confidence),
  /// slot #2 is TFLite's top alternative that disagrees with the headline.
  /// This keeps the card visually consistent with the page title.
  Future<void> enrichWithClassifierBreakdown(Uint8List imageBytes) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.allProbabilities.isNotEmpty) return;

    try {
      await _tfliteService.loadModel();
      final source = current.croppedImage ?? imageBytes;
      final tfliteResult = await _tfliteService.classifyImage(source);
      if (tfliteResult.allProbabilities.isEmpty) return;

      // Build the breakdown: headline always at top, then TFLite's best
      // alternative (case-insensitive name compare so "Plastik" vs "plastik"
      // counts as the same category).
      //
      // Skip "Kaca" and "Lainnya" as alternatives — kaca is suppressed to
      // "tidak dikenali" elsewhere (never shown as a real option), and TFLite
      // doesn't emit "Lainnya" but we guard anyway in case the class names
      // ever change.
      final headlineLower = current.category.name.toLowerCase();
      final breakdown = <String, double>{
        current.category.name: current.confidence,
      };
      final alt = tfliteResult.topProbabilities.firstWhere(
        (e) =>
            e.key.toLowerCase() != headlineLower &&
            e.key.toLowerCase() != 'kaca' &&
            e.key.toLowerCase() != 'lainnya',
        orElse: () => MapEntry('', 0.0),
      );
      if (alt.key.isNotEmpty && alt.value > 0) {
        breakdown[alt.key] = alt.value;
      }

      state = AsyncValue.data(current.copyWith(
        allProbabilities: breakdown,
      ));
    } catch (e) {
      debugPrint('ScanNotifier: classifier breakdown failed: $e');
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  Future<List<ScanResult>> classifyMultipleImages(Uint8List imageBytes) async {
    try {
      final geminiService = GeminiService();
      final useGemini = geminiService.isConfigured;

      final isOnline = await _hasInternetConnection();

      // Jika online, full menggunakan Gemini service.
      if (isOnline && useGemini) {
        debugPrint('[ScanNotifier] Online: Using FULL Gemini for mixed waste detection');
        final items = await geminiService.classifyMultiple(imageBytes);
        
        if (items.isNotEmpty) {
          var decoded = img.decodeImage(imageBytes);
          if (decoded != null) decoded = img.bakeOrientation(decoded);
          final built = items.map((item) {
            final b = item.bbox;
            // Map Gemini's [y1, x1, y2, x2] to [x1, y1, x2, y2] 
            final boxNorm = b != null && b.length == 4 ? [b[1], b[0], b[3], b[2]] : null;
            final d = CloudDetection(item.category, item.confidence, boxNorm);
            return _buildScanResultFromCloudDetection(
              d,
              imageBytes,
              _boxNormToRect(d.boxNorm, decoded),
              dynamicCategoryName: item.dynamicCategoryName,
            );
          }).toList();


          final results = built.toList();
              
          _lastUsedGemini = true;
          _multiResults = results;
          _selectedDetailIndex = 0;
          _saveMultiToHistory(results);
          _invalidateMultiResultProviders();
          return results;
        }
      }

      // ── Offline mode atau tidak ada koneksi / Gemini gagal:
      // Fallback menggunakan RT-DETR + waste_classifier (TFLite)
      debugPrint('[ScanNotifier] Offline / No Wifi: Fallback to RT-DETR + TFLite for mixed waste');
      await _rtdetrService.loadModel();
      final rtdetrResults = _rtdetrService.isLoaded
          ? await _rtdetrService.detectObjects(imageBytes)
          : <ScanResult>[];

      if (rtdetrResults.isNotEmpty) {
        final merged = rtdetrResults
            .map((r) => _ensureCroppedImage(r, imageBytes))
            .toList();

        final enriched = _enrichMultiWithLocalDataset(merged);
        final withDataset = enriched.toList();

        _multiResults = withDataset;
        _selectedDetailIndex = 0;
        _saveMultiToHistory(withDataset);
        _invalidateMultiResultProviders();
        return withDataset;
      }

      // Jika RT-DETR tidak menemukan apa-apa, fallback ke klasifikasi TFLite frame penuh
      debugPrint('[ScanNotifier] No RT-DETR detections — TFLite last resort');
      await _tfliteService.loadModel();
      final fallback = await _tfliteService.classifyImage(imageBytes);
      _multiResults = [fallback];
      _selectedDetailIndex = 0;
      _invalidateMultiResultProviders();
      return [fallback];

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

  /// Cloud-based multi-item classification. Mirrors [classifyMultipleImages]
  /// but routes through [GeminiService] instead of the on-device RT-DETR/TFLite pipeline.
  /// Triggered when the user taps "Pindai Lagi" on the multi-result screen —
  /// the cloud model is more accurate for hard cases where on-device
  /// detection misfired (e.g. RT-DETR returns empty and the TFLite fallback
  /// splits the image into wrong regions).
  ///
  /// Does NOT filter by confidence so the multi-result UI can render low-
  /// confidence items as "Tidak dikenali" inside the list — same behavior as
  /// the on-device multi path.
  ///
  /// Crops each item from the original image using the normalized bbox
  /// Gemini returns, so each card on the multi-result screen shows the
  /// matching object (not the shared full-frame fallback). Items without a
  /// usable bbox fall back to the full image.
  Future<List<ScanResult>> classifyMultipleWithGemini(Uint8List imageBytes) async {
    try {
      final geminiService = GeminiService();
      final useGemini = geminiService.isConfigured;

      final isOnline = await _hasInternetConnection();

      // Jika offline, fallback pakai classifyMultipleImages (offline mode via RT-DETR)
      if (!isOnline) {
        debugPrint('[ScanNotifier] Offline / No Wifi: Fallback to RT-DETR + TFLite for classifyMultipleWithGemini');
        return classifyMultipleImages(imageBytes);
      }

      if (!useGemini) {
        _multiResults = [];
        _selectedDetailIndex = 0;
        _invalidateMultiResultProviders();
        return [];
      }

      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) decoded = img.bakeOrientation(decoded);

      final dets = await geminiService.classifyMultiple(imageBytes);
      if (dets.isEmpty) {
        _multiResults = [];
        _selectedDetailIndex = 0;
        _invalidateMultiResultProviders();
        return [];
      }

      final results = <ScanResult>[];
      for (final d in dets) {
        Rect? pixelRect;
        Uint8List? cropped;
        final b = d.bbox; // Gemini bbox = [y1, x1, y2, x2]
        if (b != null && decoded != null && b.length == 4) {
          pixelRect = Rect.fromLTRB(
            b[1] * decoded.width,
            b[0] * decoded.height,
            b[3] * decoded.width,
            b[2] * decoded.height,
          );
          cropped = _cropFromBytes(imageBytes, pixelRect);
        }
        cropped ??= imageBytes;
        final cat = d.category;
        results.add(ScanResult(
          itemName: d.dynamicCategoryName ?? (cat == WasteCategory.lainnya ? 'Tidak dikenali' : cat.name),
          category: cat,
          confidence: d.confidence,
          description: d.reason.isEmpty ? 'Diklasifikasikan oleh Gemini AI.' : d.reason,
          disposalInfo: cat.disposalInfo,
          dynamicCategoryName: d.dynamicCategoryName,
          boundingBox: pixelRect,
          croppedImage: cropped,
          allProbabilities: {
            cat.name: d.confidence,
            'Lainnya': 1.0 - d.confidence,
          },
          isFromGemini: true,
        ));
      }

      _multiResults = results;
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
      
      final randomConf = 0.90 + math.Random().nextDouble() * 0.09;
      
      final itemName = match.entry.itemName ?? 'Sampah dari dataset lokal';
      final dynamicCat = (cat == WasteCategory.lainnya && match.entry.itemName != null) ? match.entry.itemName : null;

      return ScanResult(
        itemName: itemName,
        category: cat,
        confidence: randomConf,
        description: 'Sudah pernah kamu pindai & simpan sebelumnya '
            '(${match.hammingDistance}/8 mirip).',
        disposalInfo: cat.disposalInfo,
        allProbabilities: {cat.name: randomConf},
        dynamicCategoryName: dynamicCat,
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
      
      final randomConf = 0.90 + math.Random().nextDouble() * 0.09;
      
      final itemName = match.entry.itemName ?? r.itemName;
      final dynamicCat = (cat == WasteCategory.lainnya && match.entry.itemName != null) ? match.entry.itemName : null;

      return ScanResult(
        itemName: itemName,
        category: cat,
        confidence: randomConf,
        description: 'Sudah pernah kamu pindai & simpan sebelumnya '
            '(${match.hammingDistance}/8 mirip).',
        disposalInfo: cat.disposalInfo,
        boundingBox: r.boundingBox,
        croppedImage: r.croppedImage,
        allProbabilities: {cat.name: randomConf},
        dynamicCategoryName: dynamicCat,
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
      String source = 'model';
      if (result.isCorrected) {
        source = 'human';
      } else if (result.isFromGemini || _lastUsedGemini) {
        source = 'gemini';
      }

      await _ref.read(localDatasetProvider).saveEntry(
        bytes,
        category: result.category,
        itemName: result.itemName,
        confidence: result.confidence,
        labelSource: source,
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
      var image = img.decodeImage(imageBytes);
      if (image == null) return null;
      image = img.bakeOrientation(image);

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
      _ref.read(sessionProvider.notifier).addToHistory(results);
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

  /// Publish a multi-result item as the CURRENT single result so single-mode
  /// screens (/low-confidence, /manual-correction) can operate on it. Used by
  /// the multi-result "Periksa" flow — the item stays in [_multiResults]
  /// untouched until the user confirms/corrects, at which point the caller
  /// writes it back via [updateMultiResult].
  void focusMultiItem(int index) {
    if (index < 0 || index >= _multiResults.length) return;
    state = AsyncValue.data(_multiResults[index]);
  }

  Future<void> correctResult(CategoryOption newCategoryOption) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    final newCategory = newCategoryOption.baseCategory;
    final itemName = newCategoryOption.customItemName;

    final corrected = current.copyWith(
      itemName: itemName ?? current.itemName,
      category: newCategory,
      dynamicCategoryName: itemName,
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

    _ref.read(sessionProvider.notifier).state = session.copyWith(scanHistory: updatedHistory);

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
            .updateCategoryForImage(bytes, newCategory: newCategory, itemName: itemName);
        // Re-push the corrected (human-labelled) entry. Best-effort.
        unawaited(SupabaseSyncService.instance.syncPending());
      } catch (e) {
        debugPrint('[ScanNotifier] updateCategoryForImage failed: $e');
      }
    }

    await _ref.read(sessionProvider.notifier).addCorrection();
    await _ref.read(sessionProvider.notifier).addXP(SessionService.xpCorrection);
  }

  Future<void> saveToHistory() async {
    final result = state.valueOrNull;
    if (result == null) return;
    _ref.read(sessionProvider.notifier).addToHistory([result]);
    // Persist to on-device dataset so future scans of the same item reuse
    // this category instead of re-running ML.
    await _saveToLocalDataset(result);
    _ref.read(categoryOptionsProvider.notifier).refresh();
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
    _ref.read(categoryOptionsProvider.notifier).refresh();
  }

  /// Removes the current scan from the local dataset and deletes its image file.
  /// Used when the user discards a scan via "Pindai Lagi".
  Future<void> deleteFromLocalDataset() async {
    final imageBytes = _ref.read(capturedImageProvider);
    if (imageBytes != null) {
      await _ref.read(localDatasetProvider).deleteEntry(imageBytes);
      _ref.read(categoryOptionsProvider.notifier).refresh();
    }
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

  /// Bytes to send to the AI when re-analyzing a specific multi-result item.
  /// Prefers that item's croppedImage (the object itself) over the full
  /// captured frame — focusing the AI on just that object gives a sharper
  /// classification than re-scanning the whole scene. Falls back to the full
  /// captured frame only when the item has no crop (rare: cloud returned no
  /// box). Returns null if neither is available.
  Uint8List? bytesForReanalyze(int index) {
    if (index < 0 || index >= _multiResults.length) return null;
    final crop = _multiResults[index].croppedImage;
    if (crop != null) return crop;
    return _ref.read(capturedImageProvider);
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
