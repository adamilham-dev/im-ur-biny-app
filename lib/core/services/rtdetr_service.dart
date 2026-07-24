import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/scan_result.dart';
import '../models/waste_category.dart';
import 'interpreter_factory.dart';

/// On-device waste object detector using RT-DETR via TensorFlow Lite.
///
/// Replaces the two-step pipeline (brightness detection + crop + classify)
/// with a single RT-DETR inference that detects all objects and classifies
/// them in one forward pass.
class RTDETRService {
  static const String _modelPath = 'assets/models/rtdetr_best_fp32.tflite';

  /// Minimum confidence to accept a detection.
  /// Below this, the detection is rejected and treated as "unknown".
  /// RT-DETR uses sigmoid outputs which are overconfident at low scores,
  /// so 0.50 is a reasonable floor before considering a result "unknown".
  static const double _confidenceThreshold = 0.35;

  /// IoU threshold for Non-Maximum Suppression.
  static const double _nmsIouThreshold = 0.45;

  /// Maximum number of objects to return.
  static const int _maxDetections = 5;

  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _loadAttempted = false;

  /// Cached input/output tensor details (populated on first load).
  List<int> _inputShape = [];
  int _inputHeight = 640;
  int _inputWidth = 640;
  List<List<int>> _outputShapes = [];

  bool get isLoaded => _isLoaded;

  /// Load the RT-DETR model. Idempotent — safe to call multiple times.
  Future<void> loadModel() async {
    if (_isLoaded) return;
    if (_loadAttempted) return;
    _loadAttempted = true;

    try {
      // GPU delegate is REQUIRED for this model file: despite the `fp32` name
      // its tensors are float16, which the CPU CONV_2D kernel rejects
      // (`Node 1 (CONV_2D) failed to prepare`) — so the CPU fallback inside
      // InterpreterFactory will fail too and loadModel ends with
      // _isLoaded=false, same as before. Verify box quality on the target
      // device (RT-DETR post-processing ops may compute differently on GPU);
      // the permanent fix is re-exporting a true FP32/INT8 model.
      _interpreter = await InterpreterFactory.create(_modelPath, tryGpu: true);
      _isLoaded = true;

      _cacheTensorDetails();
    } catch (e) {
      debugPrint('[RTDETR] Failed to load model: $e');
      _isLoaded = false;
    }
  }

  void _cacheTensorDetails() {
    // Input tensor
    final inputTensors = _interpreter!.getInputTensors();
    if (inputTensors.isNotEmpty) {
      _inputShape = inputTensors[0].shape;
      // Typically [1, H, W, 3] (NHWC) or [1, 3, H, W] (NCHW)
      if (_inputShape.length == 4) {
        if (_inputShape[3] == 3) {
          // NHWC: [1, H, W, 3]
          _inputHeight = _inputShape[1];
          _inputWidth = _inputShape[2];
        } else if (_inputShape[1] == 3) {
          // NCHW: [1, 3, H, W]
          _inputHeight = _inputShape[2];
          _inputWidth = _inputShape[3];
        }
      }
    }

    // Output tensors
    final outputTensors = _interpreter!.getOutputTensors();
    _outputShapes = outputTensors.map((t) => t.shape).toList();

    // Log tensor details for discovery
    debugPrint('[RTDETR] === Model Loaded ===');
    debugPrint('[RTDETR] Input shape: $_inputShape -> ${_inputWidth}x$_inputHeight');
    for (int i = 0; i < outputTensors.length; i++) {
      debugPrint('[RTDETR] Output[$i]: name=${outputTensors[i].name}, shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
    }
  }

  /// Detect all waste objects in the image.
  Future<List<ScanResult>> detectObjects(Uint8List imageBytes) async {
    await loadModel();
    if (!_isLoaded) return [];

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return [];

      final pre = _preprocessLetterbox(image);
      final outputs = _allocateOutputBuffers();

      _interpreter!.runForMultipleInputs([pre.tensor], outputs);

      final detections = _postprocess(
        outputs,
        image.width,
        image.height,
        image,
        scale: pre.scale,
        padX: pre.padX,
        padY: pre.padY,
      );
      return detections;
    } catch (e) {
      debugPrint('[RTDETR] Detection error: $e');
      return [];
    }
  }

  /// Detect the single highest-confidence object.
  Future<ScanResult?> detectSingle(Uint8List imageBytes) async {
    final results = await detectObjects(imageBytes);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.first;
  }

  // ── Preprocessing ──

  /// Letterbox preprocessing: resize preserving aspect ratio, then pad the
  /// shorter side with gray (114,114,114) to fill the model's square input.
  ///
  /// Returns the input tensor along with `scale`, `padX`, `padY` so that
  /// postprocess can reverse-map model-space boxes back to original-image
  /// pixel coordinates via `(modelCoord - pad) / scale`.
  ///
  /// This replaces the previous stretch-resize, which distorted the image
  /// and caused box/crop misalignment — especially visible with >3 objects
  /// because small edge boxes suffer the largest relative displacement.
  _LetterboxResult _preprocessLetterbox(img.Image image) {
    final scale = math.min(
      _inputWidth / image.width,
      _inputHeight / image.height,
    );
    final newW = (image.width * scale).round();
    final newH = (image.height * scale).round();
    final padX = ((_inputWidth - newW) / 2).round();
    final padY = ((_inputHeight - newH) / 2).round();

    final resized = img.copyResize(image, width: newW, height: newH);

    // Compose onto a gray-padded canvas. RT-DETR conventionally pads with
    // 114 gray (same as YOLOv5 letterbox), so the model sees the same
    // border it was trained against.
    final canvas = img.Image(width: _inputWidth, height: _inputHeight);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

    return _LetterboxResult(
      tensor: _toTensor(canvas),
      scale: scale,
      padX: padX,
      padY: padY,
    );
  }

  /// Convert a model-input-sized image to a normalized tensor in the layout
  /// (NHWC or NCHW) expected by the interpreter, with ImageNet normalization.
  List<dynamic> _toTensor(img.Image resized) {
    final isNHWC = _inputShape.length == 4 && _inputShape[3] == 3;

    if (isNHWC) {
      // NHWC: [1, H, W, 3]
      return [
        List.generate(_inputHeight, (y) =>
          List.generate(_inputWidth, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r / 255.0 - 0.485) / 0.229,
              (pixel.g / 255.0 - 0.456) / 0.224,
              (pixel.b / 255.0 - 0.406) / 0.225,
            ];
          }),
        ),
      ];
    } else {
      // NCHW: [1, 3, H, W]
      final r = List.generate(_inputHeight, (y) =>
        List.generate(_inputWidth, (x) =>
          (resized.getPixel(x, y).r / 255.0 - 0.485) / 0.229));
      final g = List.generate(_inputHeight, (y) =>
        List.generate(_inputWidth, (x) =>
          (resized.getPixel(x, y).g / 255.0 - 0.456) / 0.224));
      final b = List.generate(_inputHeight, (y) =>
        List.generate(_inputWidth, (x) =>
          (resized.getPixel(x, y).b / 255.0 - 0.406) / 0.225));
      return [
        [r, g, b],
      ];
    }
  }

  // ── Output allocation ──

  Map<int, List<dynamic>> _allocateOutputBuffers() {
    final buffers = <int, List<dynamic>>{};
    for (int i = 0; i < _outputShapes.length; i++) {
      buffers[i] = _allocateForShape(_outputShapes[i]);
    }
    return buffers;
  }

  List<dynamic> _allocateForShape(List<int> shape) {
    if (shape.isEmpty) return [0.0];
    if (shape.length == 1) return List.filled(shape[0], 0.0);
    if (shape.length == 2) {
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    }
    if (shape.length == 3) {
      return List.generate(shape[0], (_) =>
        List.generate(shape[1], (_) => List.filled(shape[2], 0.0)));
    }
    return List.generate(shape[0], (_) =>
      List.generate(shape[1], (_) =>
        List.generate(shape[2], (_) => List.filled(shape[3], 0.0))));
  }

  // ── Post-processing ──

  List<ScanResult> _postprocess(
    Map<int, List<dynamic>> outputs,
    int imgW,
    int imgH,
    img.Image originalImage, {
    required double scale,
    required int padX,
    required int padY,
  }) {
    // The post-processing depends on the RT-DETR output format.
    // Common formats:
    // 1. Single tensor [1, N, 6] where each row is [x1, y1, x2, y2, classId, score]
    // 2. Single tensor [1, N, numClasses+4] where first 4 are box coords, rest are class scores
    // 3. Multiple tensors: boxes [1, N, 4], scores [1, N, numClasses], etc.
    //
    // We handle all three cases based on discovered output shapes.

    final detections = <_RawDetection>[];

    if (_outputShapes.length == 1) {
      // Single output tensor
      final data = outputs[0]!;
      final shape = _outputShapes[0];

      if (shape.length == 3) {
        final n = shape[1]; // max detections
        final cols = shape[2]; // columns per detection

        for (int i = 0; i < n; i++) {
          final row = (data[0][i] as List).cast<double>();

          if (cols == 6) {
            // Format: [x1, y1, x2, y2, classId, score]
            final score = row[5];
            if (score < _confidenceThreshold) continue;
            final rawClassIdx = row[4].toInt();
            if (rawClassIdx == 0) continue; // Drop former Kaca
            final classIdx = rawClassIdx - 1; // Shift indices (1->0, 2->1, etc.)
            final mapped = _mapIndexToCategory(classIdx);
            detections.add(_RawDetection(
              x1: row[0], y1: row[1], x2: row[2], y2: row[3],
              classIndex: classIdx,
              category: mapped.$1,
              dynamicCategoryName: mapped.$2,
              confidence: score,
            ));
          } else if (cols >= 6) {
            // Format: [x1, y1, x2, y2, score0, score1, ..., scoreN]
            // Class scores start at index 4
            final rawClassScores = row.sublist(4);
            final classScores = rawClassScores.sublist(1); // Drop former Kaca
            final bestIdx = _argmax(classScores);
            final bestScore = classScores[bestIdx];
            if (bestScore < _confidenceThreshold) continue;
            final mapped = _mapIndexToCategory(bestIdx);
            detections.add(_RawDetection(
              x1: row[0], y1: row[1], x2: row[2], y2: row[3],
              classIndex: bestIdx,
              category: mapped.$1,
              dynamicCategoryName: mapped.$2,
              confidence: bestScore,
            ));
          }
        }
      }
    } else if (_outputShapes.length >= 2) {
      // Multiple output tensors: boxes + scores
      final boxData = outputs[0]!;
      final scoreData = outputs[1]!;
      final boxShape = _outputShapes[0];
      final scoreShape = _outputShapes[1];

      if (boxShape.length == 3 && scoreShape.length >= 2) {
        final n = boxShape[1];
        for (int i = 0; i < n; i++) {
          final box = (boxData[0][i] as List).cast<double>();
          List<double> scores;
          if (scoreShape.length == 2) {
            scores = (scoreData[0] as List).cast<double>();
            if (i < scores.length) {
              final score = scores[i];
              if (score < _confidenceThreshold) continue;
              final mapped = _mapIndexToCategory(i);
              detections.add(_RawDetection(
                x1: box[0], y1: box[1], x2: box[2], y2: box[3],
                classIndex: i,
                category: mapped.$1,
                dynamicCategoryName: mapped.$2,
                confidence: score,
              ));
            }
          } else if (scoreShape.length == 3) {
            scores = (scoreData[0][i] as List).cast<double>();
            final bestIdx = _argmax(scores);
            final bestScore = scores[bestIdx];
            if (bestScore < _confidenceThreshold) continue;
            final mapped = _mapIndexToCategory(bestIdx);
            detections.add(_RawDetection(
              x1: box[0], y1: box[1], x2: box[2], y2: box[3],
              classIndex: bestIdx,
              category: mapped.$1,
              dynamicCategoryName: mapped.$2,
              confidence: bestScore,
            ));
          }
        }
      }
    }

    // Apply NMS
    var kept = _applyNMS(detections, _nmsIouThreshold);

    // Limit to max detections
    if (kept.length > _maxDetections) {
      kept = kept.sublist(0, _maxDetections);
    }

    // Detect once whether model outputs boxes in 0..1 normalized space or in
    // input pixel space (0..640). Most RT-DETR TFLite exports use pixel
    // space; the previous `d.x1 <= 1.0` heuristic per-detection was fragile
    // because any single box with a coord > 1 flipped interpretation.
    final isNormalized = _isNormalizedOutput(kept);

    // Convert to ScanResult with cropped image
    return kept.map((d) {
      // Step 1: model-space pixels (0.._inputWidth/_inputHeight)
      final mx1 = isNormalized ? d.x1 * _inputWidth : d.x1;
      final my1 = isNormalized ? d.y1 * _inputHeight : d.y1;
      final mx2 = isNormalized ? d.x2 * _inputWidth : d.x2;
      final my2 = isNormalized ? d.y2 * _inputHeight : d.y2;

      // Step 2: reverse letterbox — strip padding then un-scale to original
      // image pixels. Clamp to original image bounds.
      final x1 = ((mx1 - padX) / scale).clamp(0.0, imgW.toDouble());
      final y1 = ((my1 - padY) / scale).clamp(0.0, imgH.toDouble());
      final x2 = ((mx2 - padX) / scale).clamp(0.0, imgW.toDouble());
      final y2 = ((my2 - padY) / scale).clamp(0.0, imgH.toDouble());

      // Crop the detected region from the original image
      Uint8List? croppedBytes;
      try {
        final cx1 = x1.round().clamp(0, imgW);
        final cy1 = y1.round().clamp(0, imgH);
        final cx2 = x2.round().clamp(0, imgW);
        final cy2 = y2.round().clamp(0, imgH);
        final cropW = cx2 - cx1;
        final cropH = cy2 - cy1;
        if (cropW > 10 && cropH > 10) {
          final cropped = img.copyCrop(originalImage,
              x: cx1, y: cy1, width: cropW, height: cropH);
          croppedBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
        }
      } catch (e) {
        debugPrint('[RTDETR] Crop error: $e');
      }

      return ScanResult(
        itemName: d.dynamicCategoryName != null ? 'Sampah ${d.dynamicCategoryName}' : 'Sampah ${d.category.name}',
        category: d.category,
        confidence: d.confidence,
        disposalInfo: d.category.disposalInfo,
        description: d.category.subtitle,
        boundingBox: Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)),
        croppedImage: croppedBytes,
      );
    }).toList();
  }

  /// Returns true if all detections fit in [0..1] — i.e. the model emits
  /// normalized coordinates. Otherwise treats them as input pixel space.
  /// The 1.5 threshold leaves margin so a box edge exactly at 1.0 doesn't
  /// flip the interpretation ambiguously.
  bool _isNormalizedOutput(List<_RawDetection> detections) {
    if (detections.isEmpty) return false;
    for (final d in detections) {
      if (d.x1 > 1.5 || d.y1 > 1.5 || d.x2 > 1.5 || d.y2 > 1.5) {
        return false;
      }
    }
    return true;
  }

  // ── NMS ──

  List<_RawDetection> _applyNMS(List<_RawDetection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <_RawDetection>[];
    final suppressed = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      kept.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i], detections[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return kept;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final x1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final y1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final x2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final y2 = a.y2 < b.y2 ? a.y2 : b.y2;

    final intersection = (x2 - x1).clamp(0, double.infinity) *
                         (y2 - y1).clamp(0, double.infinity);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final union = areaA + areaB - intersection;

    return union > 0 ? intersection / union : 0;
  }

  // ── Helpers ──

  int _argmax(List<double> values) {
    int best = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  (WasteCategory, String?) _mapIndexToCategory(int index) {
    // Match the class name order: Kertas=0, Logam=1, Organik=2, Plastik=3, Residu=4
    switch (index) {
      case 0: return (WasteCategory.kertas, null);
      case 1: return (WasteCategory.logam, null);
      case 2: return (WasteCategory.organik, null);
      case 3: return (WasteCategory.plastik, null);
      case 4: return (WasteCategory.residu, null);
      default: return (WasteCategory.lainnya, null);
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _loadAttempted = false;
  }
}

class _RawDetection {
  final double x1, y1, x2, y2, confidence;
  final WasteCategory category;
  final String? dynamicCategoryName;
  final int classIndex;

  _RawDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidence,
    required this.category,
    this.dynamicCategoryName,
    required this.classIndex,
  });
}

class RTDETRBoundingBox {
  final double y1;
  final double x1;
  final double y2;
  final double x2;
  final WasteCategory category;
  final String? dynamicCategoryName;
  final double confidence;

  RTDETRBoundingBox({
    required this.y1,
    required this.x1,
    required this.y2,
    required this.x2,
    required this.category,
    this.dynamicCategoryName,
    required this.confidence,
  });
}

/// Output of letterbox preprocessing — the model input tensor plus the
/// geometry needed to reverse-map model-space boxes back to original
/// image pixel coordinates.
class _LetterboxResult {
  final List<dynamic> tensor;
  final double scale;
  final int padX;
  final int padY;

  _LetterboxResult({
    required this.tensor,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}
