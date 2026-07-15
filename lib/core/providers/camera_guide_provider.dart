import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/camera_service.dart';
import '../services/object_validator_service.dart';
import '../services/tflite_service.dart';
import 'app_provider.dart';
import 'camera_provider.dart';

export '../services/object_validator_service.dart'
    show ObjectValidation, MixedObjectValidation;

/// Per-object status label shown on bounding box.
enum ObjectStatus {
  /// Object is properly detected and within boundary.
  readable,

  /// Object is too close to another object.
  tooClose,

  /// Object is partially outside the boundary area.
  outsideBoundary,

  /// Object confidence too low — unsure classification.
  unsure,
}

/// Single detected object on the camera preview.
class DetectedObject {
  /// Padded classification rect in normalized coordinates.
  final Rect rect;

  /// Display rect in normalized coordinates — used for UI borders.
  final Rect displayRect;

  /// Classified category name (e.g. "Plastik", "Kaca").
  final String categoryName;

  /// Classification confidence (0.0–1.0).
  final double confidence;

  /// Per-object status for label display.
  final ObjectStatus status;

  /// Aspect ratio (width / height) of the source image used for detection.
  /// Needed by the UI to compute BoxFit.cover transformation.
  final double sourceAspectRatio;

  const DetectedObject({
    required this.rect,
    required this.displayRect,
    required this.categoryName,
    required this.confidence,
    this.status = ObjectStatus.readable,
    this.sourceAspectRatio = 1.0,
  });
}

/// Sealed union type for camera guide state — single or mixed mode.
sealed class CameraGuideState {
  const CameraGuideState();
}

class CameraGuideSingle extends CameraGuideState {
  final ObjectValidation validation;
  const CameraGuideSingle(this.validation);
}

class CameraGuideMixed extends CameraGuideState {
  final MixedObjectValidation validation;
  final int objectCount;
  const CameraGuideMixed(this.validation, this.objectCount);
}

/// Notifier that periodically captures camera frames, validates
/// object presence, AND runs real-time per-object TFLite classification
/// to show bounding boxes with waste type labels on the camera preview.
class CameraGuideNotifier extends StateNotifier<CameraGuideState> {
  final CameraService _cameraService;
  final ObjectValidatorService _validator = ObjectValidatorService();
  final TFLiteService _tflite = TFLiteService();
  final Ref _ref;
  Timer? _timer;
  bool _modelLoaded = false;
  int _frameCount = 0;

  /// Only run TFLite classification every N-th validation frame to reduce lag.
  static const int _classifyEveryN = 3;

  CameraGuideNotifier(this._cameraService, this._ref)
      : super(const CameraGuideSingle(ObjectValidation.idle));

  /// Start periodic validation + real-time per-object classification.
  void startValidation() {
    if (_timer != null) return;
    _loadModelAsync();
    _validateFrame();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _validateFrame(),
    );
  }

  Future<void> _loadModelAsync() async {
    try {
      await _tflite.loadModel();
      _modelLoaded = true;
      debugPrint('CameraGuideNotifier: TFLite model loaded for realtime');
    } catch (e) {
      debugPrint('CameraGuideNotifier: Failed to load model: $e');
    }
  }

  /// Stop periodic validation.
  void stopValidation() {
    _timer?.cancel();
    _timer = null;
    _frameCount = 0;
    _ref.read(detectedObjectsProvider.notifier).state = [];
    if (state is! CameraGuideSingle ||
        (state as CameraGuideSingle).validation != ObjectValidation.idle) {
      state = const CameraGuideSingle(ObjectValidation.idle);
    }
  }

  Future<void> _validateFrame() async {
    if (!_cameraService.isInitialized) return;

    final bytes = await _cameraService.captureSmallFrame();
    if (bytes == null) return;

    _frameCount++;
    final scanMode = _ref.read(scanModeProvider);

    try {
      // --- Step 1: Run lightweight validation (pixel counting) ---
      if (scanMode == 'mixed') {
        final result = await _validator.validateMixed(bytes);
        if (mounted) {
          state = CameraGuideMixed(result.state, result.objectCount);
        }
      } else {
        final result = await _validator.validate(bytes);
        if (mounted) {
          state = CameraGuideSingle(result.state);
        }
      }

      // --- Step 2: Run heavy classification on every N-th frame ---
      final shouldClassify =
          _modelLoaded && mounted && _frameCount % _classifyEveryN == 0;
      if (!shouldClassify) return;

      // Detect object regions — returns correctly oriented image dimensions
      final detection = await _validator.detectObjectRegions(bytes);
      if (detection.regions.isEmpty || detection.imageWidth == 0) {
        _ref.read(detectedObjectsProvider.notifier).state = [];
        return;
      }

      final imgW = detection.imageWidth.toDouble();
      final imgH = detection.imageHeight.toDouble();
      final regions = detection.regions;

      // --- Step 3: Limit objects based on scan mode ---
      List<DetectedRegion> targetRegions;
      if (scanMode != 'mixed') {
        // Single mode: only the largest region
        targetRegions = [regions.first];
      } else {
        // Mixed mode: up to 5 regions
        targetRegions = regions.take(5).toList();
      }

      // --- Step 4: Classify ---
      List<DetectedObject> detected;

      if (targetRegions.length == 1) {
        // Single object: use whole-image classification (fast)
        final result = _tflite.classifyFrameQuick(bytes);
        if (result == null) {
          _ref.read(detectedObjectsProvider.notifier).state = [];
          return;
        }

        final region = targetRegions.first;
        final normDisplayRect = _normalizeRect(region.displayRect, imgW, imgH);
        final normClassifyRect = _normalizeRect(region.classificationRect, imgW, imgH);

        final sourceAspect = imgW / imgH;

        detected = [
          DetectedObject(
            rect: normClassifyRect,
            displayRect: normDisplayRect,
            categoryName: result.name,
            confidence: result.confidence,
            status: _singleObjectStatus(normDisplayRect, result.confidence),
            sourceAspectRatio: sourceAspect,
          ),
        ];
      } else {
        // Multiple objects: classify each crop
        detected = await _classifyRegions(
          bytes,
          targetRegions,
          imgW,
          imgH,
        );
        if (detected.isEmpty) {
          // Fallback to whole-image classification for each region
          final result = _tflite.classifyFrameQuick(bytes);
          if (result == null) {
            _ref.read(detectedObjectsProvider.notifier).state = [];
            return;
          }
          final sourceAspect = imgW / imgH;
          detected = targetRegions.map((region) {
            final normDisplayRect = _normalizeRect(region.displayRect, imgW, imgH);
            final normClassifyRect = _normalizeRect(region.classificationRect, imgW, imgH);
            return DetectedObject(
              rect: normClassifyRect,
              displayRect: normDisplayRect,
              categoryName: result.name,
              confidence: result.confidence,
              sourceAspectRatio: sourceAspect,
            );
          }).toList();
        }
      }

      // --- Step 5: Assign per-object statuses for mixed mode ---
      if (scanMode == 'mixed' && detected.length > 1) {
        detected = _assignMixedObjectStatuses(detected);
      } else if (scanMode == 'mixed' && detected.length == 1) {
        // Single object in mixed mode: check boundary
        final first = detected.first;
        detected = [
          DetectedObject(
            rect: first.rect,
            displayRect: first.displayRect,
            categoryName: first.categoryName,
            confidence: first.confidence,
            status: _boundaryStatus(first.displayRect),
            sourceAspectRatio: first.sourceAspectRatio,
          ),
        ];
      }

      if (mounted) {
        _ref.read(detectedObjectsProvider.notifier).state = detected;
      }
    } catch (e) {
      debugPrint('CameraGuideNotifier: Frame error: $e');
    }
  }

  /// Determine status for a single-mode object.
  ObjectStatus _singleObjectStatus(Rect normRect, double confidence) {
    if (_isOutsideBoundary(normRect)) {
      return ObjectStatus.outsideBoundary;
    }
    if (confidence < 0.45) {
      return ObjectStatus.unsure;
    }
    return ObjectStatus.readable;
  }

  /// Check if a normalized rect extends outside the boundary zone.
  bool _isOutsideBoundary(Rect normRect) {
    const margin = 0.04;
    return normRect.left < margin ||
        normRect.top < margin ||
        normRect.right > (1.0 - margin) ||
        normRect.bottom > (1.0 - margin);
  }

  /// Get status for boundary check only.
  ObjectStatus _boundaryStatus(Rect normRect) {
    if (_isOutsideBoundary(normRect)) {
      return ObjectStatus.outsideBoundary;
    }
    return ObjectStatus.readable;
  }

  /// Assign per-object statuses for mixed mode objects.
  List<DetectedObject> _assignMixedObjectStatuses(
      List<DetectedObject> objects) {
    final tooCloseSet = <int>{};
    for (int i = 0; i < objects.length; i++) {
      for (int j = i + 1; j < objects.length; j++) {
        if (_areTooClose(objects[i].displayRect, objects[j].displayRect)) {
          tooCloseSet.add(i);
          tooCloseSet.add(j);
        }
      }
    }

    return objects.asMap().entries.map((entry) {
      final idx = entry.key;
      final obj = entry.value;

      ObjectStatus status;
      if (_isOutsideBoundary(obj.displayRect)) {
        status = ObjectStatus.outsideBoundary;
      } else if (tooCloseSet.contains(idx)) {
        status = ObjectStatus.tooClose;
      } else if (obj.confidence < 0.45) {
        status = ObjectStatus.unsure;
      } else {
        status = ObjectStatus.readable;
      }

      return DetectedObject(
        rect: obj.rect,
        displayRect: obj.displayRect,
        categoryName: obj.categoryName,
        confidence: obj.confidence,
        status: status,
        sourceAspectRatio: obj.sourceAspectRatio,
      );
    }).toList();
  }

  /// Check if two normalized rects are too close to each other.
  bool _areTooClose(Rect a, Rect b) {
    const minGap = 0.04;

    final hGap = a.left < b.left
        ? b.left - a.right
        : a.left - b.right;
    final vGap = a.top < b.top
        ? b.top - a.bottom
        : a.top - b.bottom;

    if (hGap < 0 && vGap < 0) return true;

    return hGap >= 0 && hGap < minGap && vGap >= -minGap ||
        vGap >= 0 && vGap < minGap && hGap >= -minGap;
  }

  /// Classify each cropped region individually for multi-object scenes.
  Future<List<DetectedObject>> _classifyRegions(
    Uint8List bytes,
    List<DetectedRegion> regions,
    double imgW,
    double imgH,
  ) async {
    final sourceAspect = imgW / imgH;
    final detected = <DetectedObject>[];
    try {
      final classifyRects = regions.map((r) => r.classificationRect).toList();
      final results = await _tflite.classifyMultipleImages(
        bytes,
        regions: classifyRects,
      );

      for (int i = 0; i < results.length && i < regions.length; i++) {
        final region = regions[i];
        final result = results[i];
        final normDisplayRect = _normalizeRect(region.displayRect, imgW, imgH);
        final normClassifyRect = _normalizeRect(region.classificationRect, imgW, imgH);
        detected.add(DetectedObject(
          rect: normClassifyRect,
          displayRect: normDisplayRect,
          categoryName: result.category.name,
          confidence: result.confidence,
          sourceAspectRatio: sourceAspect,
        ));
      }
    } catch (e) {
      debugPrint('CameraGuideNotifier: Multi-classify error: $e');
    }
    return detected;
  }

  /// Normalize a pixel-space rect to 0-1 coordinates.
  Rect _normalizeRect(Rect rect, double imgW, double imgH) {
    return Rect.fromLTRB(
      (rect.left / imgW).clamp(0.0, 1.0),
      (rect.top / imgH).clamp(0.0, 1.0),
      (rect.right / imgW).clamp(0.0, 1.0),
      (rect.bottom / imgH).clamp(0.0, 1.0),
    );
  }

  @override
  void dispose() {
    stopValidation();
    _tflite.dispose();
    super.dispose();
  }
}

/// Provider exposing the list of detected objects with bounding boxes + labels.
final detectedObjectsProvider =
    StateProvider<List<DetectedObject>>((ref) => []);

/// Saved normalized rects from camera guide for use during scanning animation.
final scanRegionsProvider =
    StateProvider<List<Rect>>((ref) => []);

/// Source image aspect ratio (width / height) for the last detected objects.
final scanSourceAspectRatioProvider =
    StateProvider<double>((ref) => 1.0);

/// Provider that exposes the current camera guide state (single or mixed).
final cameraGuideProvider =
    StateNotifierProvider<CameraGuideNotifier, CameraGuideState>((ref) {
  final cameraAsync = ref.watch(cameraProvider);
  final cameraService = cameraAsync.valueOrNull;
  return CameraGuideNotifier(cameraService ?? CameraService(), ref);
});
