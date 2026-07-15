import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Centralised TFLite interpreter creation with optional hardware acceleration.
///
/// Replaces the scattered `InterpreterOptions()..threads = 4` + `fromAsset`
/// calls so delegate configuration lives in ONE place (see
/// `docs/dev/03-PERFORMANCE.md`).
///
/// Safety contract: a GPU delegate is *attempted* (platform-guarded), and on
/// ANY failure we fall back to a plain CPU interpreter. The app therefore never
/// breaks because of an unsupported op or a missing GPU — worst case it runs on
/// CPU exactly like before.
///
/// ⚠️ Not yet verified on a physical device (Flutter wasn't available in the
/// authoring environment). Validate inference correctness + latency on the
/// target iPad before flipping [tryGpu] on for RT-DETR.
class InterpreterFactory {
  InterpreterFactory._();

  static bool get _gpuPlatform => Platform.isAndroid || Platform.isIOS;

  /// Create an interpreter for [assetPath].
  ///
  /// [tryGpu] attempts a GPU delegate first (Metal on iOS, GPUv2 on Android),
  /// falling back to CPU on any error. [allowPrecisionLoss] lets the GPU use
  /// FP16 for speed — fine for a classifier, negligible accuracy impact.
  static Future<Interpreter> create(
    String assetPath, {
    bool tryGpu = false,
    int threads = 4,
    bool allowPrecisionLoss = true,
  }) async {
    if (tryGpu && _gpuPlatform) {
      Delegate? delegate;
      try {
        delegate = _buildGpuDelegate(allowPrecisionLoss);
        final opts = InterpreterOptions()
          ..threads = threads
          ..addDelegate(delegate);
        final interpreter =
            await Interpreter.fromAsset(assetPath, options: opts);
        debugPrint('[InterpreterFactory] $assetPath → GPU delegate');
        return interpreter;
      } catch (e) {
        debugPrint('[InterpreterFactory] GPU delegate failed for '
            '$assetPath ($e) → CPU fallback');
        try {
          delegate?.delete();
        } catch (_) {}
      }
    }

    final cpu = InterpreterOptions()..threads = threads;
    final interpreter = await Interpreter.fromAsset(assetPath, options: cpu);
    debugPrint('[InterpreterFactory] $assetPath → CPU ($threads threads)');
    return interpreter;
  }

  static Delegate _buildGpuDelegate(bool allowPrecisionLoss) {
    if (Platform.isAndroid) {
      return GpuDelegateV2(
        options: GpuDelegateOptionsV2(
          isPrecisionLossAllowed: allowPrecisionLoss,
        ),
      );
    }
    // iOS / iPadOS — Metal delegate.
    return GpuDelegate(
      options: GpuDelegateOptions(
        allowPrecisionLoss: allowPrecisionLoss,
        enableQuantization: true,
      ),
    );
  }
}
