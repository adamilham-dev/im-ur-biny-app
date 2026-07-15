import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/camera_service.dart';

class CameraNotifier extends StateNotifier<AsyncValue<CameraService>> {
  final CameraService _cameraService = CameraService();
  bool _initialized = false;

  CameraNotifier() : super(const AsyncValue.loading());

  Future<void> initializeCamera() async {
    if (_initialized && _cameraService.isInitialized) return;

    state = const AsyncValue.loading();
    try {
      final success = await _cameraService.initialize();
      if (success) {
        _initialized = true;
        state = AsyncValue.data(_cameraService);
      } else {
        state = AsyncValue.error('Camera not available or permission denied', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Uint8List?> capturePhoto() async {
    final file = await _cameraService.capturePhoto();
    if (file == null) return null;
    return await file.readAsBytes();
  }

  CameraService? get service => _cameraService;

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, AsyncValue<CameraService>>((ref) {
  return CameraNotifier();
});

final isCameraReadyProvider = Provider<bool>((ref) {
  return ref.watch(cameraProvider).valueOrNull?.isInitialized ?? false;
});
