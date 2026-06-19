import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

class ModeSelectScreen extends ConsumerWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background decorative blobs (Figma 226:887, 226:888) ──
          if (isPortrait) ...[
            // Mint — top-right
            Positioned(
              right: -size.width * 0.15,
              top: -size.width * 0.18,
              child: IgnorePointer(
                child: Container(
                  width: size.shortestSide * 0.5,
                  height: size.shortestSide * 0.5,
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
            // Lavender — bottom-left
            Positioned(
              left: -size.width * 0.12,
              bottom: -size.width * 0.15,
              child: IgnorePointer(
                child: Container(
                  width: size.shortestSide * 0.45,
                  height: size.shortestSide * 0.45,
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
            // Mint — top-right (Figma: (884,-150) → 420×420)
            Positioned(
              right: size.width * -0.092,
              top: size.height * -0.18,
              child: IgnorePointer(
                child: Container(
                  width: size.shortestSide * 0.504,
                  height: size.shortestSide * 0.504,
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
            // Lavender — bottom-left (Figma: (-90,564) → 380×380)
            Positioned(
              left: size.width * -0.075,
              bottom: size.height * -0.132,
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

          // ── Content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 16 : 32,
                  vertical: isPhone ? 16 : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isPhone ? size.width : 1000,
                  ),
                  child: Column(
                    children: [
                      // Title — Figma 226:893: 40px Baloo 2 ExtraBold #2b2a45 leading 1.1 letter-spacing -0.2
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isPhone ? 8 : 80),
                        child: Text(
                          'Mau pilah sampah seperti apa?',
                          style: GoogleFonts.baloo2(
                            fontSize: isPhone ? 22 : 40,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.2,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Title → subtitle gap 8
                      const SizedBox(height: 8),
                      // Subtitle — Figma 226:894: 18px Plus Jakarta Sans Medium #5c5980 leading 1.5
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isPhone ? 12 : 120),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isPhone ? size.width - 24 : 660,
                          ),
                          child: Text(
                            'Pilih satu jenis, atau biarkan AI kenali banyak sampah sekaligus.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isPhone ? 13 : 18,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Subtitle → cards gap
                      SizedBox(height: isPhone ? 28 : 56),

                      // Mode cards — Column for phone portrait, Row for tablet/landscape
                      if (isPhone && isPortrait)
                        Column(
                          children: [
                            _ModeCard(
                              iconAsset:
                                  'assets/images/page_4/single_waste.png',
                              title: 'Single Waste',
                              description:
                                  'Satu sampah dalam satu kali pindai. Cepat & sederhana.',
                              isFeatured: false,
                              isPhone: true,
                              onTap: () {
                                ref.read(scanModeProvider.notifier).state =
                                    'single';
                                context.go('/category-select');
                              },
                            ),
                            const SizedBox(height: 20),
                            _ModeCard(
                              iconAsset:
                                  'assets/images/page_4/mixed_waste.png',
                              title: 'Mixed Waste',
                              description:
                                  'Banyak sampah sekaligus — AI kenali tiap jenis dalam satu scan.',
                              isFeatured: true,
                              isPhone: true,
                              onTap: () {
                                ref.read(scanModeProvider.notifier).state =
                                    'mixed';
                                // Mixed mode skips category-select — go straight
                                // to the mixed-waste camera guide.
                                context.go('/camera-guide');
                              },
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ModeCard(
                              iconAsset:
                                  'assets/images/page_4/single_waste.png',
                              title: 'Single Waste',
                              description:
                                  'Satu sampah dalam satu kali pindai. Cepat & sederhana.',
                              isFeatured: false,
                              isPhone: isPhone,
                              onTap: () {
                                ref.read(scanModeProvider.notifier).state =
                                    'single';
                                context.go('/category-select');
                              },
                            ),
                            SizedBox(width: isPhone ? 20 : 28),
                            _ModeCard(
                              iconAsset:
                                  'assets/images/page_4/mixed_waste.png',
                              title: 'Mixed Waste',
                              description:
                                  'Banyak sampah sekaligus — AI kenali tiap jenis dalam satu scan.',
                              isFeatured: true,
                              isPhone: isPhone,
                              onTap: () {
                                ref.read(scanModeProvider.notifier).state =
                                    'mixed';
                                // Mixed mode skips category-select — go straight
                                // to the mixed-waste camera guide.
                                context.go('/camera-guide');
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Biny mascot bottom-left (Figma 226:910: (48,657) → 140×147)
          Positioned(
            bottom: isPhone ? 10 : 30,
            left: isPhone ? 16 : 48,
            child: IgnorePointer(
              child: BinyHero(
                size: isPhone ? 90 : 150,
                expression: BinyExpression.mode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String description;
  final bool isFeatured;
  final bool isPhone;
  final VoidCallback onTap;

  const _ModeCard({
    required this.iconAsset,
    required this.title,
    required this.description,
    required this.isFeatured,
    required this.isPhone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = isPhone ? size.width - 32 : 420.0;

    // Figma 226:896/226:902:
    // Single Waste shadow: rgba(91,63,214,0.08) offset(0,6) blur-18
    // Mixed Waste shadow:  rgba(91,63,214,0.08) offset(0,18) blur-44
    final shadowOffset = isFeatured
        ? const Offset(0, 18)
        : const Offset(0, 6);
    final shadowBlur = isFeatured ? 44.0 : 18.0;

    final cardContent = Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 24 : 34,
        vertical: isPhone ? 28 : 40,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isPhone ? 28 : 40),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPress.withValues(alpha: 0.08),
            offset: shadowOffset,
            blurRadius: shadowBlur,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image — Figma 226:921/927: 120×120
          Image.asset(
            iconAsset,
            width: isPhone ? 88 : 120,
            height: isPhone ? 88 : 120,
            fit: BoxFit.contain,
          ),
          SizedBox(height: isPhone ? 12 : 14),
          // Title — Figma 226:918/924: 28px Baloo 2 Bold #2b2a45 leading 1.15
          Text(
            title,
            style: GoogleFonts.baloo2(
              fontSize: isPhone ? 20 : 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Description — Figma 226:919/925: 16px Plus Jakarta Sans Medium #5c5980 leading 1.5
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isPhone ? size.width - 80 : 340,
            ),
            child: Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isPhone ? 13 : 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // Wrap featured card with positioned badge overlapping the top
    if (isFeatured) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            cardContent,
            Positioned(
              top: -14,
              left: 0,
              right: 0,
              child: Center(
                child: _buildFeaturedBadge(),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(onTap: onTap, child: cardContent);
  }

  // Figma 226:908: bg #7c5cfc, px=16 py=7, rounded-999,
  // 12px Plus Jakarta Sans Bold white letter-spacing 0.48, "FITUR UNGGULAN"
  Widget _buildFeaturedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'FITUR UNGGULAN',
        style: GoogleFonts.plusJakartaSans(
          fontSize: isPhone ? 10 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.48,
          color: AppColors.surface,
        ),
      ),
    );
  }
}
