import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/app_provider.dart';
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
        // Determine if this is a new category or existing
        final selectedCategory = ref.read(selectedCategoryProvider);
        final result = ref.read(scanResultProvider);
        final isExistingCategory =
            selectedCategory != null &&
            result != null &&
            result.category == selectedCategory;

        if (isExistingCategory) {
          context.go('/conclusion-existing');
        } else {
          context.go('/conclusion-new');
        }
      }
      return;
    }

    final capturedImage = ref.read(capturedImageProvider);

    // Pure Gemini cloud classification — no on-device TFLite/RT-DETR.
    // Triggered from Unknown Detected → "Analisis AI" → /analyzing.
    // classifyWithGemini returns null if Gemini is unavailable or below its
    // own 0.50 confidence threshold; in that case the previous on-device
    // result (which routed here with <0.50 confidence) stays in state and
    // the post-classification routing falls through to /low-confidence.
    final classifyFuture = capturedImage != null
        ? ref.read(scanProvider.notifier).classifyWithGemini(capturedImage)
        : Future.value(null);

    final minWaitFuture = Future.delayed(const Duration(seconds: 4));

    // Run both in parallel — wait for BOTH to finish
    await Future.wait([classifyFuture, minWaitFuture]);

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
            ref
                .read(scanProvider.notifier)
                .updateMultiResult(reanalyzeIndex, result);
          }
          ref.read(reanalyzeMultiIndexProvider.notifier).state = null;
          context.go('/multi-result');
          return;
        }

        final result = ref.read(scanResultProvider);
        final isLowConfidence = result != null && result.confidence < 0.70;

        if (isLowConfidence) {
          context.go('/low-confidence');
        } else {
          // Determine if this is a new category or existing
          final selectedCategory = ref.read(selectedCategoryProvider);
          final isExistingCategory =
              selectedCategory != null &&
              result != null &&
              result.category == selectedCategory;

          if (isExistingCategory) {
            context.go('/conclusion-existing');
          } else {
            context.go('/conclusion-new');
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
    final isPortrait =
        AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    final glowAreaSize = isPortrait
        ? size.shortestSide * 0.55
        : size.height * 0.5;

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

          // Figma 226:1596 — big 560×480 soft purple radial glow
          // centered behind the mascot area. Pulses with _glowAnimation.
          Positioned(
            top: size.height * 0.14,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, _) {
                  final glowW = (size.shortestSide * 0.47).clamp(360.0, 560.0);
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
                              alpha: 0.22 + (_glowAnimation.value * 0.10),
                            ),
                            AppColors.primary.withValues(
                              alpha: 0.10 + (_glowAnimation.value * 0.05),
                            ),
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
                          // Figma 226:1596 — wide outer radial wash (subtle)
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
                                        alpha:
                                            0.08 +
                                            (_glowAnimation.value * 0.12),
                                      ),
                                      AppColors.primary.withValues(
                                        alpha:
                                            0.03 +
                                            (_glowAnimation.value * 0.05),
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Figma 226:1597 — outer ring outline (Ø230 in Figma)
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
                                      alpha:
                                          0.18 + (_glowAnimation.value * 0.10),
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Figma 226:1598 — inner ring outline (Ø180 in Figma)
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
                                      alpha:
                                          0.28 + (_glowAnimation.value * 0.14),
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Figma 226:1599 — Biny glow disc behind mascot
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
                                      color: AppColors.primaryLight.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius:
                                          16 + (_glowAnimation.value * 10),
                                      spreadRadius:
                                          2 + (_glowAnimation.value * 3),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          BinyHero(
                            size: isPortrait
                                ? (size.width * 0.18).clamp(110.0, 150.0)
                                : (size.height * 0.16).clamp(120.0, 150.0),
                            expression: BinyExpression.analyzing,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: AppResponsive.rs(
                        size,
                        isPortrait ? 12 : 16,
                      ).clamp(8.0, 16.0),
                    ),

                    // --- "AI AGENT BEKERJA" label ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, _) {
                            return Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFC9BEFF).withValues(
                                  alpha: 0.5 + (_glowAnimation.value * 0.5),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI AGENT BEKERJA',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: AppResponsive.sp(
                              size,
                              13,
                            ).clamp(10.0, 13.0),
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
                        fontSize: AppResponsive.sp(
                          size,
                          isPortrait ? 32 : 38,
                        ).clamp(24.0, 38.0),
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

                    SizedBox(
                      height: AppResponsive.rs(
                        size,
                        isPortrait ? 16 : 20,
                      ).clamp(10.0, 20.0),
                    ),

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
    final bgColor = isActive
        ? AppColors.primary.withValues(alpha: 0.16)
        : Colors.transparent;
    final stepFontSize = AppResponsive.sp(
      size,
      isPortrait ? 14 : 18,
    ).clamp(12.0, 18.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.rs(
          size,
          isPortrait ? 16 : 20,
        ).clamp(12.0, 20.0),
        vertical: AppResponsive.rs(
          size,
          isPortrait ? 12 : 14,
        ).clamp(10.0, 14.0),
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
            child: isCompleted
                ? SvgPicture.asset(
                    'assets/images/page_12/check.svg',
                    width: 34,
                    height: 34,
                  )
                : AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, _) {
                      return Transform.rotate(
                        angle: _spinController.value * 6.28,
                        child: CircularProgressIndicator(
                          value: 0.25,
                          color: const Color(0xFFA892FF),
                          backgroundColor: const Color(0xFFC9BEFF),
                          strokeWidth: 4.5,
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: AppResponsive.rs(
              size,
              isPortrait ? 12 : 15,
            ).clamp(8.0, 15.0),
          ),
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
}
