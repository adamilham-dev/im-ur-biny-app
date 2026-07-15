import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> initialize() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('CameraService: Camera permission denied');
        _isInitialized = false;
        return false;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;

      // Find back camera
      CameraDescription? backCamera;
      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }
      backCamera ??= _cameras.first;

      await _controller?.dispose();

      _controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Set flash off and auto-focus. Both are best-effort: devices without
      // the capability THROW (iPads have no flash — an unguarded
      // setFlashMode bricked camera init there, leaving the UI stuck on
      // "Menyiapkan kamera...").
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {
        // No flash on this device (e.g. iPad) — nothing to turn off.
      }
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Some devices don't support auto focus
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('CameraService: Failed to initialize camera: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Capture a small JPEG frame for fast object validation analysis.
  /// Returns raw JPEG bytes, or null if capture fails.
  Future<Uint8List?> captureSmallFrame() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final file = await _controller!.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('CameraService: Failed to capture small frame: $e');
      return null;
    }
  }

  Future<XFile?> capturePhoto() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      // Capture directly without refocusing — the camera is already in
      // a steady autofocus state. Resetting focus causes a brief blur/
      // exposure shift that degrades classification accuracy.
      final file = await _controller!.takePicture();
      debugPrint('CameraService: Photo captured, size = ${await file.length()} bytes');
      return file;
    } catch (e) {
      debugPrint('CameraService: Failed to capture photo: $e');
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
