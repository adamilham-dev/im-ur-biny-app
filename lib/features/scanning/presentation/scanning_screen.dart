import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/camera_provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/models/waste_category.dart';
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
    }
    if (mounted) setState(() {});
  }

  /// Capture photo → go to preview
  Future<void> _capturePhoto() async {
    try {
      final cameraNotifier = ref.read(cameraProvider.notifier);
      final cameraService = cameraNotifier.service;
      if (cameraService == null || !cameraService.isInitialized) {
        await cameraNotifier.initializeCamera();
      }

      final imageBytes = await cameraNotifier.capturePhoto();
      debugPrint('ScanningScreen: Captured ${imageBytes?.length ?? 0} bytes');

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
    const minAnalyzeTime = Duration(seconds: 6);

    try {
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

        final elapsed = DateTime.now().difference(analyzeStart);
        if (elapsed < minAnalyzeTime) {
          await Future.delayed(minAnalyzeTime - elapsed);
        }

        if (!mounted) return;
        // Treat the scan as "unknown" only if NO item cleared the confidence
        // threshold. If at least one item is recognised, still show multi-result
        // (unknown items appear as "Tidak dikenali" inside the list).
        final anyConfident = results.any((r) =>
            r.confidence >= 0.50 && r.category != WasteCategory.lainnya);
        if (results.isNotEmpty && anyConfident) {
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

        final elapsed = DateTime.now().difference(analyzeStart);
        if (elapsed < minAnalyzeTime) {
          await Future.delayed(minAnalyzeTime - elapsed);
        }

        if (!mounted) return;
        if (result != null && result.confidence >= 0.50) {
          if (result.confidence < 0.70) {
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

        final elapsed = DateTime.now().difference(analyzeStart);
        if (elapsed < minAnalyzeTime) {
          await Future.delayed(minAnalyzeTime - elapsed);
        }

        if (!mounted) return;
        // Route based on confidence:
        //   < 50%  → /unknown-detected  (model has no real guess)
        //   50-69% → /low-confidence    (model has a guess but isn't sure)
        //   ≥ 70%  → /result            (model is confident)
        final isUnknown = result == null ||
            result.confidence < 0.50 ||
            result.category == WasteCategory.lainnya;
        if (isUnknown) {
          context.go('/unknown-detected');
        } else if (result.confidence < 0.70) {
          context.go('/low-confidence');
        } else {
          context.go('/result');
        }
      }
    } catch (e) {
      debugPrint('ScanningScreen: Classification error: $e');

      final elapsed = DateTime.now().difference(analyzeStart);
      if (elapsed < minAnalyzeTime) {
        await Future.delayed(minAnalyzeTime - elapsed);
      }

      if (mounted) {
        context.go('/unknown-detected');
      }
    }
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

            // Biny mascot for Live Camera & Photo Preview
            Positioned(
              bottom: AppResponsive.isPhone(size) ? 14 : 35,
              right: AppResponsive.isPhone(size) ? 16 : 60,
              child: IgnorePointer(
                child: BinyHero(
                  size: AppResponsive.isPhone(size) ? 110.0 : 160.0,
                  expression: BinyExpression.countdown,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Live camera preview — centered 16:9 container with square crop guide
  Widget _buildCameraPreview(Size size) {
    final cameraNotifier = ref.read(cameraProvider.notifier);
    final cameraService = cameraNotifier.service;
    final controller = cameraService?.controller;
    final isReady = cameraService?.isInitialized == true &&
        controller != null &&
        controller.value.isInitialized;

    final isPortrait = size.height > size.width;
    double containerW = isPortrait ? size.width * 0.9 : 960.0;
    if (containerW > 960.0) containerW = 960.0;
    final containerH = containerW * (540.0 / 960.0);
    final radius = AppResponsive.radius(size, 24).clamp(16.0, 24.0);

    if (isReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraService!.cameras.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildCameraDropdown(cameraService),
              ),
            Container(
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SizedBox.expand(
                      child: Transform.scale(
                        scaleX: controller.description.lensDirection ==
                                CameraLensDirection.front
                            ? -1.0
                            : 1.0,
                        alignment: Alignment.center,
                        child: CameraPreview(controller),
                      ),
                    ),
                    CustomPaint(painter: _GuidePainter()),
                  ],
                ),
              ),
            ),
          ],
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

  /// Photo preview after capture — centered 16:9 container with square crop guide
  Widget _buildPhotoPreview(Size size) {
    if (_capturedPhoto == null) return const SizedBox.shrink();

    final isPortrait = size.height > size.width;
    double containerW = isPortrait ? size.width * 0.9 : 960.0;
    if (containerW > 960.0) containerW = 960.0;
    final containerH = containerW * (540.0 / 960.0);
    final radius = AppResponsive.radius(size, 24).clamp(16.0, 24.0);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Invisible spacer to match camera preview height if dropdown was present
          if (ref.read(cameraProvider.notifier).service?.cameras.isNotEmpty ==
              true)
            const SizedBox(height: 52), // approx dropdown height + padding
          Container(
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_capturedPhoto!, fit: BoxFit.cover),
                  CustomPaint(painter: _GuidePainter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown to switch cameras
  Widget _buildCameraDropdown(dynamic cameraService) {
    final cameras = cameraService.cameras as List<CameraDescription>;
    final current = cameraService.currentCamera as CameraDescription?;

    if (cameras.isEmpty || current == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CameraDescription>(
          value: current,
          dropdownColor: const Color(0xFF2B2843),
          icon: const Icon(Icons.flip_camera_ios_rounded,
              color: Colors.white, size: 20),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          items: cameras.map<DropdownMenuItem<CameraDescription>>((cam) {
            String name = cam.name;
            if (cam.lensDirection == CameraLensDirection.front) {
              name = 'Kamera Depan';
            } else if (cam.lensDirection == CameraLensDirection.back) {
              name = 'Kamera Belakang';
            } else {
              name = 'Kamera Eksternal';
            }
            return DropdownMenuItem(
              value: cam,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(name),
              ),
            );
          }).toList(),
          onChanged: (newCam) async {
            if (newCam != null) {
              await ref.read(cameraProvider.notifier).setCamera(newCam);
              if (mounted) setState(() {});
            }
          },
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
                  backgroundColor:
                      const Color(0xFF0E0B1A).withValues(alpha: 0.66),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  /// Full-screen scanning UI — pixel-perfect match to Figma 226:1140
  /// ("07 · Scanning / AI Loading") in 1194×834 frame.
  ///
  /// Key elements (Figma coordinates / 600px stage width):
  /// - glow:    720×600 ellipse, #7C5CFC @ 0.18, blur 80
  /// - stage:   600×450 (4:3), radius 30, border 2px #7C5CFC @ 0.4, shadow blur 70
  /// - scanfill: 600×90 gradient trail above scanline, #7C5CFC
  /// - scanline: 600×4 gradient line with glow, #7C5CFC, animated
  /// - corners: 30×30 L-brackets at 18px inset, 4px stroke, per-corner radii
  /// - info:    dots(13px,gap9) + title(38px) + subtitle(19px), spacing 14
  /// - biny:    150×157 at bottom-right (54px right, 40px bottom margin)
  Widget _buildScanningOverlay(Size size) {
    final isPortrait =
        AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    final isPhone = AppResponsive.isPhone(size);

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
                        // Purple glow ellipse — Figma 226:1141
                        CustomPaint(
                          size: Size(glowW, glowH),
                          painter: _BlurGlowPainter(
                            color: const Color(0xFF7C5CFC),
                            opacity: 0.18,
                            blurSigma: glowBlur,
                          ),
                        ),

                        // Stage frame — Figma 226:1142
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
                                // Captured photo — Figma 226:3292
                                if (_capturedPhoto != null)
                                  Image.memory(_capturedPhoto!,
                                      fit: BoxFit.cover),

                                // Scan fill + scan line (animated)
                                _buildScanAnimation(stageH, s),

                                // Corner brackets — Figma 226:1152-1155
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

            // ── Biny mascot — Figma 226:1163: bottom-right positioned ──
            // Figma: 150×157 at (990,636) in 1194×834 → 54px right, 40px bottom
            Positioned(
              bottom: isPhone ? 14 : (isPortrait ? 24 : 40),
              right: isPhone ? 16 : (isPortrait ? 16 : 54),
              child: IgnorePointer(
                child: BinyHero(
                  size: isPhone ? 110.0 : (isPortrait ? 110.0 : 160.0),
                  expression: BinyExpression.scanning,
                ),
              ),
            ),
          ],
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
  /// Figma 226:1156: VERTICAL layout, itemSpacing 14, center-aligned.
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

/// Paints a darkened overlay with a square cutout and corner guide brackets,
/// showing the user exactly which area will be captured.
class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    // Square cutout in the center
    final minDim = size.shortestSide;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: minDim,
      height: minDim,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Corner guides to show the scan area clearly
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerLength = minDim * 0.12;

    // Top Left
    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(0, cornerLength), borderPaint);

    // Top Right
    canvas.drawLine(
        rect.topRight, rect.topRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(
        rect.topRight, rect.topRight + Offset(0, cornerLength), borderPaint);

    // Bottom Left
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft + Offset(0, -cornerLength), borderPaint);

    // Bottom Right
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight + Offset(0, -cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
