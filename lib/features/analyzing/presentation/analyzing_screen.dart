import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Screen 12 - Analyzing (AI Agent).
/// Dark gradient background with Biny thinking pose,
/// animated glow aura, 3 progress steps, then runs
/// TensorFlow classification on the captured image.
class AnalyzingScreen extends ConsumerStatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _spinController;

  int _completedSteps = 0;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Animate steps then run classification
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _completedSteps = 1);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _completedSteps = 2);
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // Step 3 becomes "active" (spinning) — don't mark completed yet
        setState(() => _completedSteps = 2);
        _runClassification();
      }
    });
  }

  Future<void> _runClassification() async {
    // Check if this is a re-analysis of a multi-result item
    final reanalyzeIndex = ref.read(reanalyzeMultiIndexProvider);

    // If the result was already manually corrected, skip re-classification
    final isCorrected = ref.read(scanProvider.notifier).isCorrected;

    if (isCorrected && reanalyzeIndex == null) {
      // Still show the analyzing animation for a minimum time
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _completedSteps = 3);
      }
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && !_hasNavigated) {
        _hasNavigated = true;
        // Determine if this is a new category or existing. `kaca` is the only
        // "learnable new type" — it's never a user pick, so a confident kaca
        // result from the AI is the only path that should reach
        // /conclusion-new. Any of the 5 standard daur categories
        // (plastik/kertas/logam/organik/residu) is "existing" →
        // /conclusion-existing. `lainnya` is filtered to /low-confidence
        // earlier and never reaches this branch.
        final result = ref.read(scanResultProvider);
        final isNewCategory = result?.category == WasteCategory.kaca;
        if (isNewCategory) {
          context.go('/conclusion-new');
        } else {
          context.go('/conclusion-existing');
        }
      }
      return;
    }

    // Bytes to classify:
    // - Re-analyzing a multi-result item → that item's CROPPED image (the
    //   object itself), so the AI focuses on just that object instead of the
    //   whole scene. Falls back to the full captured frame if the item has
    //   no crop (rare: cloud returned no box).
    // - Single-object escalation → the full captured frame (the "Analisis
    //   AI" button from /unknown-detected).
    final notifier = ref.read(scanProvider.notifier);
    final Uint8List? analyzeBytes = reanalyzeIndex != null
        ? notifier.bytesForReanalyze(reanalyzeIndex)
        : ref.read(capturedImageProvider);
    // The existing multi-result item (only set in reanalyze mode) so its
    // croppedImage + boundingBox survive the re-classification — otherwise
    // the card would lose its photo and fall back to a generic icon.
    final existingResult = reanalyzeIndex != null
        ? notifier.multiResults[reanalyzeIndex]
        : null;

    // Cloud classification via OpenRouter (Gemma) — no on-device
    // TFLite/RT-DETR. classifyWithGemini (despite the legacy name) routes to
    // OpenRouterClassifierService.classifyAnalyzing and SKIPS the local
    // dataset cache so the AI always runs fresh. Returns null if the cloud
    // isn't configured, fails, or the AI answered "lainnya"; in that case the
    // previous on-device result stays in state and the post-classification
    // routing falls through to /low-confidence (single) or just keeps the
    // item as-is (reanalyze).
    final classifyFuture = analyzeBytes != null
        ? notifier.classifyWithGemini(analyzeBytes, existingResult: existingResult)
        : Future.value(null);

    final minWaitFuture = Future.delayed(const Duration(seconds: 4));

    // Run both in parallel — wait for BOTH to finish
    await Future.wait([
      classifyFuture,
      minWaitFuture,
    ]);

    // Mark step 3 as completed after AI finishes
    if (mounted) {
      setState(() => _completedSteps = 3);
    }

    // Navigate based on result
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        // Re-analysis mode: update the multi-result item and go back
        if (reanalyzeIndex != null) {
          final result = ref.read(scanResultProvider);
          if (result != null) {
            ref.read(scanProvider.notifier).updateMultiResult(reanalyzeIndex, result);
          }
          ref.read(reanalyzeMultiIndexProvider.notifier).state = null;
          context.go('/multi-result');
          return;
        }

        final result = ref.read(scanResultProvider);
        final isLowConfidence = result != null && result.confidence <= 0.70;

        if (isLowConfidence) {
          context.go('/low-confidence');
        } else {
          // See comment above — kaca is the only "learnable new type", every
          // other resolved category is "existing".
          final isNewCategory = result?.category == WasteCategory.kaca;
          if (isNewCategory) {
            context.go('/conclusion-new');
          } else {
            context.go('/conclusion-existing');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final glowAreaSize = isPortrait ? size.width * 0.55 : size.height * 0.5;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Base linear gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF241F40), Color(0xFF15122A)],
              ),
            ),
          ),

          // — big 560×480 soft purple radial glow
          // centered behind the mascot area. Pulses with _glowAnimation.
          Positioned(
            top: size.height * 0.14,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, _) {
                  final glowW = (size.width * 0.47).clamp(360.0, 560.0);
                  final glowH = glowW * (480.0 / 560.0);
                  return IgnorePointer(
                    child: Container(
                      width: glowW,
                      height: glowH,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(
                                alpha: 0.22 + (_glowAnimation.value * 0.10)),
                            AppColors.primary.withValues(
                                alpha: 0.10 + (_glowAnimation.value * 0.05)),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPortrait ? 24 : size.width * 0.08,
                  vertical: isPortrait ? 16 : 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Glow aura + Biny mascot ---
                    SizedBox(
                      width: glowAreaSize * 0.7,
                      height: glowAreaSize * 0.7,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // — wide outer radial wash (subtle)
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, _) {
                              return Container(
                                width: glowAreaSize * 0.7,
                                height: glowAreaSize * 0.7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withValues(
                                          alpha: 0.08 + (_glowAnimation.value * 0.12)),
                                      AppColors.primary.withValues(
                                          alpha: 0.03 + (_glowAnimation.value * 0.05)),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),
                          // — outer ring outline (Ø230 in Figma)
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, _) {
                              final gs = glowAreaSize * 0.6;
                              return Container(
                                width: gs,
                                height: gs,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryLight.withValues(
                                        alpha: 0.18 + (_glowAnimation.value * 0.10)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          // — inner ring outline (Ø180 in Figma)
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, _) {
                              final gs = glowAreaSize * 0.46;
                              return Container(
                                width: gs,
                                height: gs,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryLight.withValues(
                                        alpha: 0.28 + (_glowAnimation.value * 0.14)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          // — Biny glow disc behind mascot
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, _) {
                              final gs = glowAreaSize * 0.38;
                              return Container(
                                width: gs,
                                height: gs,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                                      blurRadius: 16 + (_glowAnimation.value * 10),
                                      spreadRadius: 2 + (_glowAnimation.value * 3),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          BinyHero(
                            size: isPortrait
                                ? (size.width * 0.18).clamp(70.0, 110.0)
                                : (size.height * 0.16).clamp(80.0, 110.0),
                            expression: BinyExpression.analyzing,
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: AppResponsive.rs(size, isPortrait ? 12 : 16).clamp(8.0, 16.0)),

                  // --- "AI AGENT BEKERJA" label ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, _) {
                          return Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFC9BEFF).withValues(
                                  alpha: 0.5 + (_glowAnimation.value * 0.5)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI AGENT BEKERJA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: AppResponsive.sp(size, 13).clamp(10.0, 13.0),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC9BEFF),
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppResponsive.rs(size, 8).clamp(4.0, 8.0)),

                  // --- Heading ---
                  // Figma: "Menganalisis sampah…" (proper ellipsis), 38px
                  // ExtraBold Baloo 2, white.
                  Text(
                    'Menganalisis sampah…',
                    style: GoogleFonts.baloo2(
                      fontSize: AppResponsive.sp(size, isPortrait ? 32 : 38).clamp(24.0, 38.0),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppResponsive.rs(size, 4).clamp(2.0, 6.0)),

                  // --- Subheading ---
                  // Figma: 18px Medium Plus Jakarta Sans, line 1.5, white.
                  Text(
                    'Biny lagi mempelajari benda barumu pakai AI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: AppResponsive.sp(size, 18).clamp(13.0, 18.0),
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppResponsive.rs(size, isPortrait ? 16 : 20).clamp(10.0, 20.0)),

                  // --- Steps card ---
                  Container(
                    width: isPortrait ? double.infinity : 540,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildStep(
                          size: size,
                          text: 'Mengamati bentuk & material',
                          isCompleted: _completedSteps >= 1,
                          isActive: _completedSteps == 0,
                          isPortrait: isPortrait,
                        ),
                        const SizedBox(height: 4),
                        _buildStep(
                          size: size,
                          text: 'Membandingkan dengan database sampah',
                          isCompleted: _completedSteps >= 2,
                          isActive: _completedSteps == 1,
                          isPortrait: isPortrait,
                        ),
                        const SizedBox(height: 4),
                        _buildStep(
                          size: size,
                          text: 'Menyimpulkan kategori yang tepat',
                          isCompleted: _completedSteps >= 3,
                          isActive: _completedSteps == 2,
                          isPortrait: isPortrait,
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required Size size,
    required String text,
    required bool isCompleted,
    required bool isActive,
    required bool isPortrait,
  }) {
    // - bg: transparent unless active (#7C5CFC @ 0.16)
    // - padding: 16h × 14v
    // - radius: 16
    // - icon-text gap: 15
    // - icon: 34×34 (done = green check, active = spinner, pending = grey ring)
    final bgColor = isActive
        ? const Color(0xFF7C5CFC).withValues(alpha: 0.16)
        : Colors.transparent;
    final stepFontSize =
        AppResponsive.sp(size, isPortrait ? 14 : 18).clamp(12.0, 18.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.rs(size, 16).clamp(12.0, 16.0),
        vertical: AppResponsive.rs(size, 14).clamp(10.0, 14.0),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: _buildStepIcon(isCompleted: isCompleted, isActive: isActive),
          ),
          SizedBox(width: AppResponsive.rs(size, 15).clamp(8.0, 15.0)),
          Expanded(
            child: Text(
              text,
              // Figma: 18px Bold Baloo 2, white for ALL steps.
              style: GoogleFonts.baloo2(
                fontSize: stepFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step indicator icon, matching children exactly.
  /// - completed: green disc (#3AD6A0) with dark-green check (#006633)
  /// - active:    circular spinner — track #A892FF, arc #C9BEFF (rotates)
  /// - pending:   static ring #635994
  Widget _buildStepIcon({required bool isCompleted, required bool isActive}) {
    if (isCompleted) {
      return SvgPicture.asset(
        'assets/icons/analyzing_step_done.svg',
        width: 34,
        height: 34,
      );
    }
    if (isActive) {
      return AnimatedBuilder(
        animation: _spinController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _spinController.value * 6.2831853, // 2π
            child: child,
          );
        },
        child: SvgPicture.asset(
          'assets/icons/analyzing_step_active.svg',
          width: 34,
          height: 34,
        ),
      );
    }
    return SvgPicture.asset(
      'assets/icons/analyzing_step_pending.svg',
      width: 34,
      height: 34,
    );
  }
}
