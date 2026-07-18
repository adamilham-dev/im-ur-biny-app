import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/scan_result.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/camera_provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Screen 07 - Photo Capture → Confirm → Scanning → Result
/// Phase 0: Live camera with capture button
/// Phase 1: Photo preview with "Ulangi" / "Gunakan Foto Ini"
/// Phase 2: Scanning animation on captured photo (AI analysis)
class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({super.key});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen>
    with TickerProviderStateMixin {
  // Phases: 0=camera, 1=photo preview, 2=scanning (AI)
  int _phase = 0;
  Uint8List? _capturedPhoto;
  bool _showFlash = false;

  // Detected-object boxes revealed mid-scan, in the PIXEL space of
  // [_capturedPhoto]. Empty until classification returns results that carry
  // a bounding box (RT-DETR or cloud) — no box, no overlay.
  List<Rect> _detectedBoxes = [];
  Size? _photoPixelSize;

  // Scanning animations
  late AnimationController _scanLineController;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    ); // started when phase 2

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    ); // started when phase 2

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();

      // If rescan mode, skip directly to scanning phase with stored photo
      final isRescan = ref.read(rescanProvider);
      if (isRescan) {
        final storedPhoto = ref.read(capturedImageProvider);
        if (storedPhoto != null) {
          ref.read(rescanProvider.notifier).state = false;
          setState(() {
            _capturedPhoto = storedPhoto;
            _phase = 2;
          });
          _scanLineController.repeat(reverse: true);
          _dotController.repeat();
          _runClassification(storedPhoto);
        }
      }
    });
  }

  Future<void> _initCamera() async {
    final cameraNotifier = ref.read(cameraProvider.notifier);
    final cameraService = cameraNotifier.service;
    if (cameraService == null || !cameraService.isInitialized) {
      await cameraNotifier.initializeCamera();
      if (mounted) setState(() {});
    }
  }

  /// Capture photo → go to preview
  Future<void> _capturePhoto() async {
    try {
      final cameraNotifier = ref.read(cameraProvider.notifier);
      final cameraService = cameraNotifier.service;
      if (cameraService == null || !cameraService.isInitialized) {
        await cameraNotifier.initializeCamera();
      }

      final raw = await cameraNotifier.capturePhoto();
      // The preview is a SQUARE (BoxFit.cover), so the user frames a square.
      // takePicture() returns the full sensor (e.g. 9:16) — crop it to the same
      // centre square so what we classify + display == what the user framed,
      // and detection boxes line up with the objects.
      final imageBytes = raw == null ? null : _cropCenterSquare(raw);
      debugPrint('ScanningScreen: Captured ${imageBytes?.length ?? 0} bytes (square)');

      if (imageBytes != null && mounted) {
        ref.read(capturedImageProvider.notifier).state = imageBytes;

        // Flash
        setState(() => _showFlash = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {
          _capturedPhoto = imageBytes;
          _showFlash = false;
          _phase = 1; // Photo preview
        });
      }
    } catch (e) {
      debugPrint('ScanningScreen: Capture error: $e');
    }
  }

  /// Crop [bytes] to its centre square (matches the square BoxFit.cover
  /// preview the user frames). Returns the original on decode failure.
  Uint8List _cropCenterSquare(Uint8List bytes) {
    final im = img.decodeImage(bytes);
    if (im == null) return bytes;
    final side = im.width < im.height ? im.width : im.height;
    final x = ((im.width - side) / 2).round();
    final y = ((im.height - side) / 2).round();
    final sq = img.copyCrop(im, x: x, y: y, width: side, height: side);
    return Uint8List.fromList(img.encodeJpg(sq, quality: 92));
  }

  /// "Ulangi" — back to camera
  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _phase = 0;
    });
  }

  /// "Gunakan Foto Ini" — go to countdown, then AI scanning
  /// The photo is already stored in [capturedImageProvider] from [_capturePhoto].
  /// Setting [rescanProvider] makes the scanning screen skip to Phase 2 (AI)
  /// when re-entered after the countdown.
  void _usePhoto() {
    if (_capturedPhoto == null) return;
    ref.read(rescanProvider.notifier).state = true;
    context.go('/countdown');
  }

  /// Run AI classification with minimum 6s scanning animation
  Future<void> _runClassification(Uint8List imageBytes) async {
    final analyzeStart = DateTime.now();
    _detectedBoxes = [];
    _photoPixelSize = null;

    try {
      // A fresh scan invalidates any pending multi-item reanalyze context
      // (set when the user tapped "Periksa"/"Analisis AI" on a multi-result
      // item) — otherwise a stale index would reroute the single-mode
      // low-confidence flow back to /multi-result.
      ref.read(reanalyzeMultiIndexProvider.notifier).state = null;

      final scanMode = ref.read(scanModeProvider);
      final useGemini = ref.read(useGeminiProvider);
      // Consume the flag — only this one classification uses Gemini.
      ref.read(useGeminiProvider.notifier).state = false;

      if (scanMode == 'mixed') {
        // Mixed mode: route through Gemini if the user came from the
        // multi-result "Pindai Lagi" button (useGemini flag set). Otherwise
        // use the on-device RT-DETR/TFLite multi-detection pipeline.
        final notifier = ref.read(scanProvider.notifier);
        final results = useGemini
            ? await notifier.classifyMultipleWithGemini(imageBytes)
            : await notifier.classifyMultipleImages(imageBytes);

        _revealDetectionBoxes(results, imageBytes);
        await _holdScanAnimation(analyzeStart);

        if (!mounted) return;
        // In mixed scan mode, if any object/waste is detected (results is not empty),
        // we always navigate to the multi-result screen to let the user see the items
        // and optionally check (Periksa) or run Cloud AI (Analisis AI) on them.
        if (results.isNotEmpty) {
          context.go('/multi-result');
        } else {
          context.go('/unknown-detected');
        }
      } else if (useGemini) {
        // ── Gemini path (single mode) ──
        // No TFLite fallback. If Gemini rejects/uncertain → /unknown-detected.
        final result = await ref
            .read(scanProvider.notifier)
            .classifyWithGemini(imageBytes);

        _revealDetectionBoxes([result], imageBytes);
        await _holdScanAnimation(analyzeStart);

        if (!mounted) return;
        if (result != null && result.confidence > 0.50) {
          if (result.confidence <= 0.70) {
            context.go('/low-confidence');
          } else {
            context.go('/result');
          }
        } else {
          context.go('/unknown-detected');
        }
      } else {
        // ── Local TFLite/RT-DETR path (single mode) ──
        final result =
            await ref.read(scanProvider.notifier).classifyImage(imageBytes);

        _revealDetectionBoxes([result], imageBytes);
        await _holdScanAnimation(analyzeStart);

        if (!mounted) return;
        // Routing:
        //   kategori "lainnya" (di luar 5 kategori utama, termasuk kaca
        //   yang di-suppress) → /unknown-detected, berapapun confidence-nya
        //   ≤ 50%  → /unknown-detected  (model has no real guess)
        //   51-70% → /low-confidence    (model has a guess but isn't sure)
        //   > 70%  → /result            (model is confident)
        final isUnknown = result == null ||
            result.confidence <= 0.50 ||
            result.category == WasteCategory.lainnya;
        if (isUnknown) {
          context.go('/unknown-detected');
        } else if (result.confidence <= 0.70) {
          // RT-DETR ships results without an allProbabilities breakdown
          // (it's a detector — one score per box, no class distribution).
          // Run TFLite as a second opinion so the /low-confidence card
          // "KEMUNGKINAN KATEGORI" can render a real top-2 instead of the
          // single-entry fallback. No-op when probabilities are already
          // populated (cloud path, TFLite fallback, dataset hit).
          if (result.allProbabilities.isEmpty) {
            await ref
                .read(scanProvider.notifier)
                .enrichWithClassifierBreakdown(imageBytes);
          }
          if (!mounted) return;
          context.go('/low-confidence');
        } else {
          context.go('/result');
        }
      }
    } catch (e) {
      debugPrint('ScanningScreen: Classification error: $e');

      await _holdScanAnimation(analyzeStart);

      if (mounted) {
        context.go('/unknown-detected');
      }
    }
  }

  /// Wait out the remainder of the minimum scan animation. When detection
  /// boxes were just revealed, hold at least 1.5s so they don't flash for a
  /// single frame before the screen navigates away.
  Future<void> _holdScanAnimation(DateTime analyzeStart) async {
    const minAnalyzeTime = Duration(seconds: 6);
    const minBoxVisible = Duration(milliseconds: 1500);
    final elapsed = DateTime.now().difference(analyzeStart);
    var wait =
        elapsed < minAnalyzeTime ? minAnalyzeTime - elapsed : Duration.zero;
    if (_detectedBoxes.isNotEmpty && wait < minBoxVisible) {
      wait = minBoxVisible;
    }
    if (wait > Duration.zero) {
      await Future.delayed(wait);
    }
  }

  /// Show dashed detection boxes over the captured photo while the scan
  /// animation finishes. No-op when no result carries a bounding box — the
  /// overlay simply never appears and the screen looks exactly as before.
  void _revealDetectionBoxes(
      Iterable<ScanResult?> results, Uint8List photoBytes) {
    final boxes = [
      for (final r in results)
        if (r?.boundingBox != null) r!.boundingBox!,
    ];
    if (boxes.isEmpty || !mounted) return;
    final photoSize = _decodePhotoSize(photoBytes);
    if (photoSize == null) return;
    setState(() {
      _detectedBoxes = boxes;
      _photoPixelSize = photoSize;
    });
  }

  /// Pixel dimensions of [bytes]. Header-only JPEG parse first (cheap);
  /// full decode as fallback for other formats. Null when undecodable —
  /// callers then skip the box overlay rather than guess a mapping.
  Size? _decodePhotoSize(Uint8List bytes) {
    try {
      final info = img.JpegDecoder().startDecode(bytes);
      if (info != null) {
        return Size(info.width.toDouble(), info.height.toDouble());
      }
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        return Size(decoded.width.toDouble(), decoded.height.toDouble());
      }
    } catch (e) {
      debugPrint('ScanningScreen: photo size decode failed: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);

    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Phase 2: Full scanning overlay
          if (_phase == 2)
            _buildScanningOverlay(size)

          // Phase 0 & 1
          else ...[
            // Camera or photo preview
            if (_phase == 0)
              _buildCameraPreview(size)
            else
              _buildPhotoPreview(size),

            if (_showFlash)
              Container(color: Colors.white.withValues(alpha: 0.85)),

            // Back button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: AppResponsive.paddingAll(size, 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => context.go('/camera-guide'),
                      child: Container(
                        padding: AppResponsive.paddingAll(size, 10),
                        decoration: BoxDecoration(
                          color: AppColors.labelDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: AppResponsive.iconSize(size, 22)
                              .clamp(14.0, 22.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls
            if (_phase == 0)
              _buildCaptureButton(size)
            else if (_phase == 1)
              _buildConfirmButtons(size),

            // Biny mascot — bottom-right, parked above the bottom controls.
            // BinyHero is an invisible slot; the global BinyFlightOverlay
            // renders the actual mascot at this rect.
            Positioned(
              bottom: AppResponsive.rs(size, 120).clamp(96.0, 150.0),
              right: AppResponsive.rs(size, 28).clamp(20.0, 36.0),
              child: BinyHero(
                size: isPortrait
                    ? (size.width * 0.15).clamp(60.0, 100.0)
                    : (size.height * 0.16).clamp(80.0, 120.0),
                expression: BinyExpression.scanning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Live camera preview — centered square-ish container
  Widget _buildCameraPreview(Size size) {
    final cameraNotifier = ref.read(cameraProvider.notifier);
    final cameraService = cameraNotifier.service;
    final controller = cameraService?.controller;
    final isReady = cameraService?.isInitialized == true &&
        controller != null &&
        controller.value.isInitialized;

    final isPortrait = size.height > size.width;
    final containerW = isPortrait ? size.width * 0.85 : size.width * 0.55;
    final containerH = containerW; // square
    final radius = AppResponsive.radius(size, 24).clamp(16.0, 24.0);

    if (isReady) {
      // previewSize is reported in LANDSCAPE sensor coordinates (w > h).
      // CameraPreview rotates itself based on the device orientation, so the
      // box we give it must match: portrait swaps the dimensions, landscape
      // (iPad kiosk) keeps them. The old hardcoded portrait swap squashed
      // the live preview on landscape iPads.
      final previewSize = controller.value.previewSize!;
      final orientation = controller.value.lockedCaptureOrientation ??
          controller.value.deviceOrientation;
      final previewLandscape = orientation == DeviceOrientation.landscapeLeft ||
          orientation == DeviceOrientation.landscapeRight;
      final previewW =
          previewLandscape ? previewSize.width : previewSize.height;
      final previewH =
          previewLandscape ? previewSize.height : previewSize.width;

      return Center(
        child: Container(
          width: containerW,
          height: containerH,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1A28),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: containerW,
        height: containerH,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A28),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_rounded,
                size: AppResponsive.iconSize(size, 64).clamp(40.0, 64.0),
                color: Colors.white.withValues(alpha: 0.25),
              ),
              SizedBox(height: AppResponsive.rs(size, 8).clamp(5.0, 8.0)),
              Text(
                'Menyiapkan kamera...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: AppResponsive.sp(size, 14).clamp(10.0, 14.0),
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Photo preview after capture — centered square-ish container
  Widget _buildPhotoPreview(Size size) {
    if (_capturedPhoto == null) return const SizedBox.shrink();

    final isPortrait = size.height > size.width;
    final containerW = isPortrait ? size.width * 0.85 : size.width * 0.55;
    final containerH = containerW; // square
    final radius = AppResponsive.radius(size, 24).clamp(16.0, 24.0);

    return Center(
      child: Container(
        width: containerW,
        height: containerH,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A28),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(_capturedPhoto!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  /// Shutter button
  Widget _buildCaptureButton(Size size) {
    final btnSize = AppResponsive.rs(size, 72).clamp(56.0, 72.0);
    final innerSize = btnSize * 0.78;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            bottom: AppResponsive.rs(size, 24).clamp(16.0, 24.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ambil foto sampah',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: AppResponsive.sp(size, 15).clamp(11.0, 15.0),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: AppResponsive.rs(size, 16).clamp(10.0, 16.0)),
              GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: btnSize,
                  height: btnSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Ulangi" and "Gunakan Foto Ini" buttons
  Widget _buildConfirmButtons(Size size) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.rs(size, 24).clamp(16.0, 24.0),
            vertical: AppResponsive.rs(size, 16).clamp(10.0, 16.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // "Ulangi" — outlined
              OutlinedButton(
                onPressed: _retakePhoto,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E0B1A).withValues(alpha: 0.66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ulangi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(12.0, 16.0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppResponsive.rs(size, 24).clamp(12.0, 24.0)),

              // "Gunakan foto ini" — primary
              ElevatedButton(
                onPressed: _usePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Gunakan foto ini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(12.0, 16.0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_outline_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-screen scanning UI — pixel-perfect match to
  /// ("07 · Scanning / AI Loading") in 1194×834 frame.
  ///
  /// Key elements (Figma coordinates / 600px stage width)
  /// - glow:    720×600 ellipse, #7C5CFC @ 0.18, blur 80
  /// - stage:   600×450 (4:3), radius 30, border 2px #7C5CFC @ 0.4, shadow blur 70
  /// - scanfill: 600×90 gradient trail above scanline, #7C5CFC
  /// - scanline: 600×4 gradient line with glow, #7C5CFC, animated
  /// - corners: 30×30 L-brackets at 18px inset, 4px stroke, per-corner radii
  /// - info:    dots(13px,gap9) + title(38px) + subtitle(19px), spacing 14
  Widget _buildScanningOverlay(Size size) {
    final isPortrait = AppResponsive.isPortrait(size);

    // Stage dimensions — Figma stage is 600×450 (4:3 aspect ratio, NOT square)
    double stageW;
    if (isPortrait) {
      stageW = (size.width * 0.80).clamp(220.0, 520.0);
    } else {
      // Figma: stageH = 450/834 = 54% of frame height
      stageW = (size.height * 0.54 * (600.0 / 450.0)).clamp(300.0, 700.0);
    }
    final stageH = stageW * (450.0 / 600.0); // maintain 4:3

    // Scale factor: device stage width / Figma reference (600px)
    final s = stageW / 600.0;

    // Corner brackets — Figma: 30×30 at 18px inset, 4px stroke
    final cornerSize = 30.0 * s;
    final cornerInset = 18.0 * s;
    final cornerStroke = (4.0 * s).clamp(2.0, 4.0);

    // Glow — Figma 720×600 ellipse, blur 80, #7C5CFC @ 0.18
    final glowW = 720.0 * s;
    final glowH = 600.0 * s;
    final glowBlur = 80.0 * s;

    // Stage border radius — Figma: 30px outer, 28px inner clip
    final stageRadius = 30.0 * s;
    final stageClipRadius = 28.0 * s;

    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF221E3A),
              Color(0xFF121020),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 15), // ~15% top gap (Figma 124/834)

                  // ── Stage with glow ──
                  SizedBox(
                    width: stageW,
                    height: stageH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Purple glow ellipse
                        CustomPaint(
                          size: Size(glowW, glowH),
                          painter: _BlurGlowPainter(
                            color: const Color(0xFF7C5CFC),
                            opacity: 0.18,
                            blurSigma: glowBlur,
                          ),
                        ),

                        // Stage frame
                        Container(
                          width: stageW,
                          height: stageH,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(stageRadius),
                            border: Border.all(
                              color: const Color(0xFF7C5CFC)
                                  .withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C5CFC)
                                    .withValues(alpha: 0.35),
                                blurRadius: 70.0 * s,
                              ),
                            ],
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2B2843),
                                Color(0xFF191731),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(stageClipRadius),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Captured photo
                                if (_capturedPhoto != null)
                                  Image.memory(_capturedPhoto!,
                                      fit: BoxFit.cover),

                                // Dashed boxes around detected objects —
                                // fade in once detection returns. Drawn
                                // UNDER the scan line so the line sweeps
                                // over them (matches the design mock).
                                if (_detectedBoxes.isNotEmpty &&
                                    _photoPixelSize != null)
                                  _buildDetectionBoxes(s),

                                // Scan fill + scan line (animated)
                                _buildScanAnimation(stageH, s),

                                // Corner brackets
                                _buildCornerBrackets(
                                    cornerSize, cornerInset, cornerStroke),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 5), // ~4.6% gap (Figma 38/834)

                  // ── Info section: dots + title + subtitle ──
                  _buildInfoSection(size, s),

                  const Spacer(flex: 13), // ~13% bottom gap (Figma 110/834)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dashed bounding boxes over the detected objects, faded in once the
  /// detector returns. Boxes are in the photo's pixel space; the painter
  /// replays the exact BoxFit.cover transform the photo widget uses, so the
  /// boxes land on the objects regardless of stage size.
  Widget _buildDetectionBoxes(double s) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: CustomPaint(
        painter: _DetectionBoxesPainter(
          boxes: _detectedBoxes,
          photoSize: _photoPixelSize!,
          scale: s,
        ),
      ),
    );
  }

  /// Scan fill (90px gradient trail) + scan line (4px with glow) — animated.
  /// Figma scanfill: 600×90 directly above scanline; scanline: 600×4.
  Widget _buildScanAnimation(double stageH, double s) {
    final fillHeight = 90.0 * s;

    return AnimatedBuilder(
      animation: _scanLineController,
      builder: (context, child) {
        final lineY = _scanLineController.value * stageH;
        final fillTop = (lineY - fillHeight).clamp(0.0, stageH);

        return Stack(
          children: [
            // Scan fill — gradient trail above the line
            if (lineY - fillTop > 0)
              Positioned(
                top: fillTop,
                left: 0,
                right: 0,
                height: lineY - fillTop,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF7C5CFC).withValues(alpha: 0.0),
                        const Color(0xFF7C5CFC).withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),
            // Scan line — 4px gradient with glow
            Positioned(
              top: lineY,
              left: 0,
              right: 0,
              child: Container(
                height: 4.0 * s,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF7C5CFC).withValues(alpha: 0.0),
                    const Color(0xFF7C5CFC),
                    const Color(0xFF7C5CFC).withValues(alpha: 0.0),
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.9),
                      blurRadius: 20.0 * s,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 4 L-shaped corner brackets at stage corners.
  /// Figma: 30×30 at 18px inset, 4px stroke #7C5CFC.
  /// Per-corner radii (TL,TR,BR,BL):
  ///   crn-tl [12,4,4,0] · crn-tr [4,12,0,4] · crn-bl [4,0,12,4] · crn-br [0,4,4,12]
  Widget _buildCornerBrackets(
      double cornerSize, double cornerInset, double cornerStroke) {
    const color = Color(0xFF7C5CFC);
    final r12 = cornerSize * (12.0 / 30.0);
    final r4 = cornerSize * (4.0 / 30.0);

    return Stack(
      children: [
        // crn-tl: shows top+left, radii TL=12 TR=4 BR=4
        Positioned(
          top: cornerInset,
          left: cornerInset,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: cornerStroke),
                left: BorderSide(color: color, width: cornerStroke),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r12),
                topRight: Radius.circular(r4),
                bottomRight: Radius.circular(r4),
              ),
            ),
          ),
        ),
        // crn-tr: shows top+right, radii TL=4 TR=12 BL=4
        Positioned(
          top: cornerInset,
          right: cornerInset,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: cornerStroke),
                right: BorderSide(color: color, width: cornerStroke),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r4),
                topRight: Radius.circular(r12),
                bottomLeft: Radius.circular(r4),
              ),
            ),
          ),
        ),
        // crn-bl: shows bottom+left, radii TL=4 BR=12 BL=4
        Positioned(
          bottom: cornerInset,
          left: cornerInset,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: cornerStroke),
                left: BorderSide(color: color, width: cornerStroke),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r4),
                bottomRight: Radius.circular(r12),
                bottomLeft: Radius.circular(r4),
              ),
            ),
          ),
        ),
        // crn-br: shows bottom+right, radii TR=4 BR=12 BL=4
        Positioned(
          bottom: cornerInset,
          right: cornerInset,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: cornerStroke),
                right: BorderSide(color: color, width: cornerStroke),
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(r4),
                bottomRight: Radius.circular(r12),
                bottomLeft: Radius.circular(r4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Info section: animated dots + title + subtitle.
  /// VERTICAL layout, itemSpacing 14, center-aligned.
  Widget _buildInfoSection(Size size, double s) {
    final dotSize = (13.0 * s).clamp(6.0, 13.0);
    final dotGap = (9.0 * s).clamp(4.0, 9.0);
    final gap14 = (14.0 * s).clamp(8.0, 14.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading dots — Figma: 3 circles Ø13, gap 9
        AnimatedBuilder(
          animation: _dotController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final active = (_dotController.value * 3).floor() % 3 == i;
                return Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: dotGap / 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? const Color(0xFF7C5CFC)
                        : const Color(0xFF7C5CFC).withValues(alpha: 0.3),
                  ),
                );
              }),
            );
          },
        ),
        SizedBox(height: gap14),

        // Title — Figma: "Memindai sampah…" 38px Baloo 2 ExtraBold white
        Text(
          'Memindai sampah…',
          style: GoogleFonts.baloo2(
            fontSize: AppResponsive.sp(size, 38).clamp(22.0, 38.0),
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: gap14),

        // Subtitle — Figma: 19px Plus Jakarta Sans Medium white
        Text(
          'AI sedang mengenali jenis & jumlah sampah',
          style: GoogleFonts.plusJakartaSans(
            fontSize: AppResponsive.sp(size, 19).clamp(12.0, 19.0),
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Draws dashed rounded boxes around detected objects during the scanning
/// animation. [boxes] are Rects in the captured photo's pixel space;
/// [photoSize] is that photo's pixel dimensions. The canvas transform mirrors
/// the BoxFit.cover math of the photo widget (scale to fill, center the
/// overflow) so each box lands exactly on the object it belongs to. Boxes
/// that fall partly outside the stage are clipped by the parent ClipRRect.
class _DetectionBoxesPainter extends CustomPainter {
  final List<Rect> boxes;
  final Size photoSize;

  /// Stage scale factor (stage width / 600 Figma reference) — used to keep
  /// stroke width and dash lengths proportional to the rest of the overlay.
  final double scale;

  const _DetectionBoxesPainter({
    required this.boxes,
    required this.photoSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (photoSize.width <= 0 || photoSize.height <= 0) return;

    // BoxFit.cover: scale so the photo fills the stage, center the overflow.
    final coverScale = math.max(
      size.width / photoSize.width,
      size.height / photoSize.height,
    );
    final dx = (size.width - photoSize.width * coverScale) / 2;
    final dy = (size.height - photoSize.height * coverScale) / 2;

    final paint = Paint()
      ..color = const Color(0xFF6EE7B7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.5 * scale).clamp(1.5, 3.0)
      ..strokeCap = StrokeCap.round;

    final pad = 8.0 * scale; // breathing room around the object
    final cornerRadius = Radius.circular(10.0 * scale);
    final dash = 8.0 * scale;
    final gap = 6.0 * scale;

    for (final b in boxes) {
      final mapped = Rect.fromLTRB(
        b.left * coverScale + dx,
        b.top * coverScale + dy,
        b.right * coverScale + dx,
        b.bottom * coverScale + dy,
      ).inflate(pad);
      if (mapped.width < 4 || mapped.height < 4) continue;
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(mapped, cornerRadius));
      canvas.drawPath(_dashPath(path, dash: dash, gap: gap), paint);
    }
  }

  Path _dashPath(Path source, {required double dash, required double gap}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dest.addPath(
          metric.extractPath(
              distance, math.min(distance + dash, metric.length)),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DetectionBoxesPainter old) =>
      old.boxes != boxes || old.photoSize != photoSize || old.scale != scale;
}

/// Draws a blurred ellipse glow — matches Figma's SOLID fill + LAYER_BLUR.
class _BlurGlowPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double blurSigma;

  const _BlurGlowPainter({
    required this.color,
    required this.opacity,
    required this.blurSigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    final rect = Offset.zero & size;
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_BlurGlowPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.blurSigma != blurSigma;
}
