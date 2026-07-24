import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/scan_result.dart';
import '../models/waste_category.dart';
import 'interpreter_factory.dart';

/// On-device waste classifier using TensorFlow Lite.
class TFLiteService {
  static const String _modelPath = 'assets/models/waste_classifier.tflite';

  static const List<String> _classNames = [
    'Kertas',
    'Logam',
    'Organik',
    'Plastik',
    'Residu',
  ];

  /// Minimum confidence to accept a prediction.
  /// Below this, the prediction is rejected and returned as "unknown"
  /// (category: lainnya) so the UI can route to /unknown-detected.
  static const double _confidenceThreshold = 0.50;

  /// Lightweight classification for real-time preview.
  /// Returns category name and confidence, or null if model not ready.
  ({String name, double confidence})? classifyFrameQuick(Uint8List imageBytes) {
    if (!_isLoaded || _interpreter == null) return null;

    try {
      final input = _preprocess(imageBytes);
      final output = List.filled(1 * 6, 0.0) // Model has 6 outputs
          .reshape([1, 6]);
      _interpreter!.run(input, output);

      final rawProbs = List<double>.from((output[0] as List).cast<double>());
      final probs = rawProbs.sublist(1); // Drop index 0 (formerly Kaca)
      
      final maxIdx = _argmax(probs);
      return (name: _classNames[maxIdx], confidence: probs[maxIdx]);
    } catch (_) {
      return null;
    }
  }

  /// Mean and std for ImageNet normalization.
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Load the TFLite model from assets.
  Future<void> loadModel() async {
    if (_isLoaded) return;

    try {
      // Classifier is a standard CNN — GPU-delegate-friendly. Falls back to CPU
      // automatically if the delegate can't load.
      _interpreter = await InterpreterFactory.create(_modelPath, tryGpu: true);
      _isLoaded = true;
      debugPrint('TFLiteService: Model loaded from $_modelPath');
    } catch (e) {
      debugPrint('TFLiteService: Failed to load model — $e');
      rethrow;
    }
  }

  /// Classify a single image and return a [ScanResult].
  ///
  /// [imageBytes] should be raw image bytes (JPEG/PNG).
  Future<ScanResult> classifyImage(Uint8List imageBytes) async {
    if (!_isLoaded || _interpreter == null) {
      await loadModel();
    }

    try {
      // 1. Preprocess
      final input = _preprocess(imageBytes);

      // 2. Run inference
      final output = List.filled(1 * 6, 0.0)
          .reshape([1, 6]);
      _interpreter!.run(input, output);

      // 3. Read probabilities
      final rawProbs = List<double>.from((output[0] as List).cast<double>());
      final probs = rawProbs.sublist(1); // Drop index 0
      debugPrint('TFLiteService: Probabilities = ${_formatProbs(probs)}');

      // 4. Build probability map for all classes
      final probMap = <String, double>{};
      for (int i = 0; i < _classNames.length; i++) {
        probMap[_classNames[i]] = probs[i];
      }

      // 5. Find best class — return unknown if below confidence threshold
      final maxIdx = _argmax(probs);
      final maxProb = probs[maxIdx];

      if (maxProb <= _confidenceThreshold) {
        // Model is too uncertain — return an "unknown" result so the UI can
        // route to /unknown-detected instead of guessing wrong.
        debugPrint(
          'TFLiteService: Below threshold '
          '(${(maxProb * 100).toStringAsFixed(1)}% < '
          '${(_confidenceThreshold * 100).toStringAsFixed(1)}%) — unknown',
        );
        return ScanResult(
          itemName: 'Tidak dikenali',
          category: WasteCategory.lainnya,
          confidence: maxProb,
          description: 'Objek tidak dikenali oleh model.',
          disposalInfo: WasteCategory.lainnya.disposalInfo,
          allProbabilities: probMap,
        );
      }

      // 6. Map index to category — confident prediction
      final mapped = _mapIndexToCategory(maxIdx);
      final category = mapped.$1;
      final dynamicName = mapped.$2;
      
      final itemName = dynamicName != null ? 'Sampah $dynamicName' : _generateItemName(category);

      debugPrint(
        'TFLiteService: Predicted ${dynamicName ?? category.name} '
        '(${(maxProb * 100).toStringAsFixed(1)}%)',
      );

      return ScanResult(
        itemName: itemName,
        category: category,
        dynamicCategoryName: dynamicName,
        confidence: maxProb,
        description: dynamicName != null 
            ? 'Sampah kategori $dynamicName yang terdeteksi.' 
            : 'Sampah kategori ${category.name} yang terdeteksi.',
        disposalInfo: category.disposalInfo,
        allProbabilities: probMap,
      );
    } catch (e, st) {
      debugPrint('TFLiteService: ERROR = $e');
      debugPrint('TFLiteService: StackTrace = $st');

      return ScanResult(
        itemName: 'Gagal menganalisis',
        category: WasteCategory.lainnya,
        confidence: 0.0,
        description: 'Terjadi kesalahan: $e',
        disposalInfo: 'Coba scan ulang.',
        allProbabilities: {},
      );
    }
  }

  /// Luminance threshold to detect dark (black board) pixels.
  static const int _darkThreshold = 60;

  /// Preprocess image bytes into a [1, 256, 256, 3] float32 tensor.
  ///
  /// Steps: decode → detect dark background → brighten if needed →
  /// resize 256x256 → normalize (ImageNet mean/std).
  List<List<List<List<double>>>> _preprocess(Uint8List imageBytes) {
    // Decode image
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw FormatException('Failed to decode image bytes');
    }

    // Resize to working size
    final workSize = 256;
    final working = img.copyResize(decoded, width: workSize, height: workSize);

    // Detect if image has dark background (black board)
    final brightCount = _countBrightPixels(working);
    final totalPixels = workSize * workSize;
    final brightRatio = brightCount / totalPixels;

    img.Image processed;

    if (brightRatio < 0.7) {
      // Dark background detected — brighten entire image globally.
      // This shifts dark pixels (black board) toward medium gray,
      // making the image distribution closer to training data.
      // Bright pixels (the object) also get brighter but remain dominant.
      processed = _brightenImage(working, factor: 1.8, addPerChannel: 70);
    } else {
      // Normal image — use as-is
      processed = working;
    }

    // Normalize and build tensor [1, H, W, C] (NHWC for TFLite)
    final tensor = List.generate(
      1,
      (_) => List.generate(
        256,
        (y) => List.generate(
          256,
          (x) {
            final pixel = processed.getPixel(x, y);
            final r = _pixelChannel(pixel, 0);
            final g = _pixelChannel(pixel, 1);
            final b = _pixelChannel(pixel, 2);
            return [
              (r - _mean[0]) / _std[0],
              (g - _mean[1]) / _std[1],
              (b - _mean[2]) / _std[2],
            ];
          },
        ),
      ),
    );

    return tensor;
  }

  /// Count bright pixels in an image (luminance > [_darkThreshold]).
  int _countBrightPixels(img.Image image) {
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final lum = _luminance(pixel);
        if (lum > _darkThreshold) count++;
      }
    }
    return count;
  }

  /// Brighten an image by multiplying channels and adding a constant.
  ///
  /// This is a global operation — every pixel gets brighter equally.
  /// Dark backgrounds (black board ~0) become medium gray (~70-100).
  /// Bright objects (already 150-255) become slightly brighter but
  /// don't clip because they're capped at 255.
  img.Image _brightenImage(img.Image source, {double factor = 1.8, int addPerChannel = 70}) {
    final result = img.Image(width: source.width, height: source.height);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final r = _clampChannel(((pixel.r is int ? (pixel.r as int) : ((pixel.r as double) * 255).round()) * factor + addPerChannel).round());
        final g = _clampChannel(((pixel.g is int ? (pixel.g as int) : ((pixel.g as double) * 255).round()) * factor + addPerChannel).round());
        final b = _clampChannel(((pixel.b is int ? (pixel.b as int) : ((pixel.b as double) * 255).round()) * factor + addPerChannel).round());
        result.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return result;
  }

  /// Clamp a channel value to [0, 255].
  int _clampChannel(int value) {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value;
  }

  /// Compute pixel luminance (0-255).
  int _luminance(img.Pixel pixel) {
    final r = pixel.r is int ? pixel.r as int : ((pixel.r as double) * 255).round();
    final g = pixel.g is int ? pixel.g as int : ((pixel.g as double) * 255).round();
    final b = pixel.b is int ? pixel.b as int : ((pixel.b as double) * 255).round();
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }

  /// Extract a single channel value from a Pixel, normalizing to [0, 1].
  double _pixelChannel(img.Pixel pixel, int channel) {
    // img.Pixel exposes r, g, b as num (int 0-255 or double 0.0-1.0)
    final raw = channel == 0
        ? pixel.r
        : channel == 1
            ? pixel.g
            : pixel.b;
    if (raw is int) {
      return raw / 255.0;
    }
    return (raw as double).clamp(0.0, 1.0);
  }

  /// Map class index to WasteCategory.
  ///
  /// Order: ["Kaca", "Kertas", "Logam", "Organik", "Plastik", "Residu"]
  (WasteCategory, String?) _mapIndexToCategory(int index) {
    switch (index) {
      case 0:
        return (WasteCategory.kertas, null);
      case 1:
        return (WasteCategory.logam, null);
      case 2:
        return (WasteCategory.organik, null);
      case 3:
        return (WasteCategory.plastik, null);
      case 4:
        return (WasteCategory.residu, null);
      default:
        return (WasteCategory.lainnya, null);
    }
  }

  /// Generate a descriptive item name based on category.
  String _generateItemName(WasteCategory category) {
    switch (category) {
      case WasteCategory.plastik:
        return 'Sampah Plastik';
      case WasteCategory.kertas:
        return 'Sampah Kertas';
      case WasteCategory.organik:
        return 'Sampah Organik';
      case WasteCategory.logam:
        return 'Sampah Logam';
      case WasteCategory.residu:
        return 'Sampah Residu';
      case WasteCategory.lainnya:
        return 'Sampah Tidak Dikenali';
    }
  }

  int _argmax(List<double> values) {
    int best = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  String _formatProbs(List<double> probs) {
    final parts = <String>[];
    for (int i = 0; i < _classNames.length; i++) {
      parts.add('${_classNames[i]}=${(probs[i] * 100).toStringAsFixed(1)}%');
    }
    return parts.join(', ');
  }

  /// Classify multiple waste items by cropping each detected region
  /// from the full image and classifying individually.
  ///
  /// [imageBytes] — the full camera capture (JPEG/PNG).
  /// [regions] — bounding rectangles of detected objects in original image coords.
  Future<List<ScanResult>> classifyMultipleImages(
    Uint8List imageBytes, {
    List<Rect>? regions,
  }) async {
    if (!_isLoaded || _interpreter == null) {
      await loadModel();
    }

    try {
      // If no regions provided, fall back to whole-image classification
      if (regions == null || regions.isEmpty) {
        debugPrint('TFLiteService: No regions — classifying whole image');
        final result = await classifyImage(imageBytes);
        return [result];
      }

      // Decode image once
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        debugPrint('TFLiteService: Failed to decode image for multi-classify');
        return [];
      }

      debugPrint(
        'TFLiteService: Classifying ${regions.length} cropped regions',
      );

      final results = <ScanResult>[];

      for (int i = 0; i < regions.length; i++) {
        final rect = regions[i];

        // Crop the region from the original image
        final cropX = rect.left.round().clamp(0, decoded.width - 1);
        final cropY = rect.top.round().clamp(0, decoded.height - 1);
        final cropW = (rect.width).round().clamp(1, decoded.width - cropX);
        final cropH = (rect.height).round().clamp(1, decoded.height - cropY);

        final cropped = img.copyCrop(
          decoded,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );

        // Encode cropped region to PNG bytes for preprocessing
        final cropBytes = Uint8List.fromList(img.encodePng(cropped));

        // Classify this individual crop
        final input = _preprocess(cropBytes);
        final output = List.filled(1 * 6, 0.0) // Model has 6 outputs
            .reshape([1, 6]);
        _interpreter!.run(input, output);

        final rawProbs = List<double>.from((output[0] as List).cast<double>());
        final probs = rawProbs.sublist(1); // Drop index 0 (formerly Kaca)
        debugPrint(
          'TFLiteService: Region $i probs = ${_formatProbs(probs)}',
        );

        // Build probability map
        final probMap = <String, double>{};
        for (int j = 0; j < _classNames.length; j++) {
          probMap[_classNames[j]] = probs[j];
        }

        final maxIdx = _argmax(probs);
        final maxProb = probs[maxIdx];

        if (maxProb <= _confidenceThreshold) {
          // Below threshold — unknown
          results.add(ScanResult(
            itemName: 'Tidak dikenali #${i + 1}',
            category: WasteCategory.lainnya,
            confidence: maxProb,
            description: 'Objek #${i + 1} tidak dikenali.',
            disposalInfo: WasteCategory.lainnya.disposalInfo,
            allProbabilities: probMap,
          ));
        } else {
          final mapped = _mapIndexToCategory(maxIdx);
          final category = mapped.$1;
          final dynamicName = mapped.$2;
          final itemName = dynamicName != null ? 'Sampah $dynamicName' : _generateItemName(category);
          
          results.add(ScanResult(
            itemName: itemName,
            category: category,
            dynamicCategoryName: dynamicName,
            confidence: maxProb,
            description: dynamicName != null ? 'Sampah kategori $dynamicName yang terdeteksi.' : 'Sampah kategori ${category.name} yang terdeteksi.',
            disposalInfo: category.disposalInfo,
            allProbabilities: probMap,
          ));
        }
      }

      debugPrint(
        'TFLiteService: Detected ${results.length} items: '
        '${results.map((r) => '${r.itemName}(${(r.confidence * 100).toStringAsFixed(1)}%)').join(', ')}',
      );

      return results;
    } catch (e, st) {
      debugPrint('TFLiteService: Multi-item ERROR = $e');
      debugPrint('TFLiteService: StackTrace = $st');
      return [];
    }
  }

  /// Release interpreter resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    debugPrint('TFLiteService: Interpreter closed');
  }
}

class _DetectedItem {
  final int index;
  final double confidence;
  _DetectedItem(this.index, this.confidence);
}
