import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/biny_hero.dart';
import '../../../shared/widgets/floating_asset.dart';
import '../../../shared/widgets/pill_indicator.dart';

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/welcome'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final isPhone = AppResponsive.isPhone(size);

            final double leafSize = isPhone ? 35.0 : 77.0;
            final double recycleSize = isPhone ? 30.0 : 63.0;
            final double plantSize = isPhone ? 30.0 : 61.0;
            final double waterSize = isPhone ? 24.0 : 48.63;

            return Stack(
              children: [
                // Background decorative blobs (Figma 226:568, 226:569, 226:570)
                // Painted as RadialGradient (not PNG) for guaranteed colour visibility
                if (maxHeight > maxWidth) ...[
                  // ── Portrait ──
                  Positioned(
                    left: -maxWidth * 0.15,
                    top: -maxWidth * 0.25,
                    child: IgnorePointer(
                      child: Container(
                        width: maxWidth * 0.75,
                        height: maxWidth * 0.75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobPurple.withValues(alpha: 0.6),
                              AppColors.blobPurple.withValues(alpha: 0.25),
                              AppColors.blobPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -maxWidth * 0.2,
                    bottom: -maxWidth * 0.15,
                    child: IgnorePointer(
                      child: Container(
                        width: maxWidth * 0.9,
                        height: maxWidth * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobGreen.withValues(alpha: 0.6),
                              AppColors.blobGreen.withValues(alpha: 0.25),
                              AppColors.blobGreen.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: maxWidth * 0.02,
                    top: maxHeight * 0.4,
                    child: IgnorePointer(
                      child: Container(
                        width: maxWidth * 0.5,
                        height: maxWidth * 0.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobPurple.withValues(alpha: 0.6),
                              AppColors.blobPurple.withValues(alpha: 0.25),
                              AppColors.blobPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Landscape — Figma-exact proportions ──
                  Positioned(
                    left: maxWidth * -0.117,
                    top: maxHeight * -0.216,
                    child: IgnorePointer(
                      child: Container(
                        width: size.shortestSide * 0.67,
                        height: size.shortestSide * 0.67,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobPurple.withValues(alpha: 0.6),
                              AppColors.blobPurple.withValues(alpha: 0.25),
                              AppColors.blobPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: maxWidth * -0.109,
                    bottom: maxHeight * -0.216,
                    child: IgnorePointer(
                      child: Container(
                        width: size.shortestSide * 0.624,
                        height: size.shortestSide * 0.624,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobGreen.withValues(alpha: 0.6),
                              AppColors.blobGreen.withValues(alpha: 0.25),
                              AppColors.blobGreen.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: maxWidth * 0.162,
                    top: maxHeight * 0.46,
                    child: IgnorePointer(
                      child: Container(
                        width: size.shortestSide * 0.456,
                        height: size.shortestSide * 0.456,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.blobPurple.withValues(alpha: 0.6),
                              AppColors.blobPurple.withValues(alpha: 0.25),
                              AppColors.blobPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Floating assets
                Positioned(
                  top: maxHeight * 0.13,
                  left: maxWidth * 0.12,
                  child: FloatingAsset(
                    width: leafSize,
                    height: leafSize,
                    rotationDegree: 0.0,
                    animationDuration: const Duration(seconds: 4),
                    movementRange: const Offset(8, 12),
                    initialPhase: 0.0,
                    child: Image.asset(
                        'assets/images/page_1/leaf.png',
                        fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: maxHeight * 0.20,
                  right: maxWidth * 0.16,
                  child: FloatingAsset(
                    width: recycleSize,
                    height: recycleSize,
                    rotationDegree: -17.22,
                    animationDuration: const Duration(milliseconds: 3500),
                    movementRange: const Offset(-10, 10),
                    initialPhase: 0.3,
                    child: Image.asset(
                        'assets/images/page_1/recycle.png',
                        fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  bottom: maxHeight * 0.18,
                  left: maxWidth * 0.18,
                  child: FloatingAsset(
                    width: plantSize,
                    height: plantSize,
                    rotationDegree: 9.15,
                    animationDuration: const Duration(seconds: 5),
                    movementRange: const Offset(12, -8),
                    initialPhase: 0.7,
                    child: Image.asset(
                        'assets/images/page_1/plant.png',
                        fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  bottom: maxHeight * 0.23,
                  right: maxWidth * 0.16,
                  child: FloatingAsset(
                    width: waterSize,
                    height: waterSize,
                    rotationDegree: -5.69,
                    animationDuration: const Duration(milliseconds: 4200),
                    movementRange: const Offset(-6, -14),
                    initialPhase: 0.5,
                    child: Image.asset(
                        'assets/images/page_1/water.png',
                        fit: BoxFit.contain),
                  ),
                ),

                // Center content
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isPhone ? 20 : 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isPhone ? maxWidth : 508,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          BinyHero(
                            size: isPhone
                                ? AppResponsive.iconSize(size, 110).clamp(80.0, 140.0)
                                : 200.0,
                            expression: BinyExpression.idle,
                          ),
                          SizedBox(height: isPhone ? 12 : 24),
                          Text(
                            'Yuk, pilah sampahmu!',
                            style: AppTypography.headingExtraBold.copyWith(
                              fontSize: AppResponsive.sp(size, isPhone ? 24 : 40).clamp(20.0, 40.0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Biny bantu kamu memilah sampah dengan benar',
                            style: AppTypography.bodyMediumStatic.copyWith(
                              fontSize: AppResponsive.sp(size, isPhone ? 13 : 18).clamp(11.0, 18.0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isPhone ? 20 : 32),
                          const PillIndicator(
                            text: 'Sentuh layar untuk mulai',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer
                Positioned(
                  bottom: isPhone ? 12.0 : 24.0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Biny Interactive Display · Future of AI Waste Sorting',
                      style: AppTypography.captionStatic.copyWith(
                        fontSize: isPhone ? 9 : 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
