import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/camera_init_failure.dart';
import '../services/camera_service.dart';

class CameraNotifier extends StateNotifier<AsyncValue<CameraService>> {
  final CameraService _cameraService = CameraService();

  CameraNotifier() : super(const AsyncValue.loading());

  /// Idempotent — safe to call multiple times from different screens.
  Future<void> initializeCamera() async {
    if (_cameraService.isInitialized) {
      state = AsyncValue.data(_cameraService);
      return;
    }

    // Already errored — reset so the loading indicator shows on retry.
    state = const AsyncValue.loading();

    try {
      final success = await _cameraService.initialize();
      if (success) {
        state = AsyncValue.data(_cameraService);
      } else {
        state = AsyncValue.error(
          _cameraService.lastFailure ?? CameraInitFailure.hardwareError,
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Switch to a different camera and reinitialise.
  Future<void> setCamera(CameraDescription camera) async {
    state = const AsyncValue.loading();
    try {
      final success = await _cameraService.initializeWith(camera);
      if (success) {
        state = AsyncValue.data(_cameraService);
      } else {
        state = AsyncValue.error(
          _cameraService.lastFailure ?? CameraInitFailure.hardwareError,
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Uint8List?> capturePhoto() async {
    final file = await _cameraService.capturePhoto();
    if (file == null) return null;
    return file.readAsBytes();
  }

  CameraService? get service => _cameraService;

  /// The resolved failure reason, usable from the UI for copy + actions.
  CameraInitFailure? get failure => state.maybeWhen(
        error: (e, _) =>
            e is CameraInitFailure ? e : CameraInitFailure.hardwareError,
        orElse: () => _cameraService.lastFailure,
      );

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

/// Reactive failure reason — rebuilds whenever [cameraProvider] changes.
final cameraFailureProvider = Provider<CameraInitFailure?>((ref) {
  ref.watch(cameraProvider); // track state changes
  return ref.read(cameraProvider.notifier).failure;
});
