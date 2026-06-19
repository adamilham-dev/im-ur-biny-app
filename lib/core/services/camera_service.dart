import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/camera_init_failure.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _currentCamera;
  bool _isInitialized = false;
  CameraInitFailure? lastFailure;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  List<CameraDescription> get cameras => _cameras;
  CameraDescription? get currentCamera => _currentCamera;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    lastFailure = null;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('CameraService: no cameras found on device');
        lastFailure = CameraInitFailure.noCamera;
        return false;
      }

      // Prefer the back camera; fall back to whatever is first.
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _currentCamera = camera;
      debugPrint('CameraService: using ${camera.name} (${camera.lensDirection.name})');

      // Try resolution presets from high → medium → low.
      // camera_avfoundation requests the AVCaptureDevice permission during
      // initialize() — no separate permission_handler call needed.
      for (final preset in const [
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ]) {
        final ok = await _tryInit(camera, preset);
        if (ok) return true;

        // Don't retry lower resolutions for permission errors.
        if (lastFailure == CameraInitFailure.permissionDenied ||
            lastFailure == CameraInitFailure.permissionPermanentlyDenied) {
          return false;
        }
      }

      lastFailure ??= CameraInitFailure.hardwareError;
      return false;
    } on CameraException catch (e) {
      debugPrint('CameraService: outer CameraException — ${e.code}: ${e.description}');
      lastFailure = _failureFrom(e.code);
      return false;
    } catch (e, st) {
      debugPrint('CameraService: unexpected error — $e\n$st');
      lastFailure = CameraInitFailure.hardwareError;
      return false;
    }
  }

  /// Re-initialise with a specific camera (e.g. from the camera switcher UI).
  Future<bool> initializeWith(CameraDescription camera) async {
    if (_isInitialized && _currentCamera == camera) return true;
    _isInitialized = false;
    lastFailure = null;
    _currentCamera = camera;

    for (final preset in const [
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.low,
    ]) {
      final ok = await _tryInit(camera, preset);
      if (ok) return true;
      if (lastFailure == CameraInitFailure.permissionDenied ||
          lastFailure == CameraInitFailure.permissionPermanentlyDenied) {
        return false;
      }
    }

    lastFailure ??= CameraInitFailure.hardwareError;
    return false;
  }

  Future<bool> _tryInit(CameraDescription camera, ResolutionPreset preset) async {
    await _disposeController();

    _controller = CameraController(
      camera,
      preset,
      enableAudio: false,
      // Do NOT force jpeg on iOS — camera_avfoundation uses bgra8888/yuv420.
    );

    try {
      await _controller!.initialize();
      debugPrint('CameraService: initialized at $preset');

      // Both flash and focus are best-effort — not all iPads expose them
      // the same way; errors here must not kill the camera session.
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('CameraService: setFlashMode ignored — $e');
      }
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('CameraService: setFocusMode ignored — $e');
      }

      _isInitialized = true;
      return true;
    } on CameraException catch (e) {
      debugPrint('CameraService: $preset failed — ${e.code}: ${e.description}');
      lastFailure = _failureFrom(e.code);
      await _disposeController();
      return false;
    }
  }

  CameraInitFailure _failureFrom(String? code) => switch (code) {
        'CameraAccessDenied' => CameraInitFailure.permissionDenied,
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          CameraInitFailure.permissionPermanentlyDenied,
        _ => CameraInitFailure.hardwareError,
      };

  Future<void> _disposeController() async {
    _isInitialized = false;
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  Future<Uint8List?> captureSmallFrame() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final file = await _controller!.takePicture();
      return file.readAsBytes();
    } catch (e) {
      debugPrint('CameraService: captureSmallFrame error — $e');
      return null;
    }
  }

  Future<XFile?> capturePhoto() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final file = await _controller!.takePicture();
      debugPrint('CameraService: photo captured, ${await file.length()} bytes');
      return file;
    } catch (e) {
      debugPrint('CameraService: capturePhoto error — $e');
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
