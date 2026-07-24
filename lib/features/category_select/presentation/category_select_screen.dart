import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/category_option.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/category_options_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/biny_hero.dart';

class CategorySelectScreen extends ConsumerWidget {
  const CategorySelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background decorative blobs ──
          if (isPortrait) ...[
            // Mint — top-right
            Positioned(
              right: -size.width * 0.15,
              top: -size.width * 0.18,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
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
                  width: size.width * 0.45,
                  height: size.width * 0.45,
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
            // Mint — top-right (Figma: (884,-170) → 420×420)
            Positioned(
              right: size.width * -0.092,
              top: size.height * -0.204,
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
            // Lavender — bottom-left (Figma: (-110,584) → 380×380)
            Positioned(
              left: size.width * -0.092,
              bottom: size.height * -0.156,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SizedBox(
                    width: isPhone ? size.width : 1100,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isPhone ? 20 : 32,
                                vertical: isPhone ? 8 : 20,
                              ),
                              child: isPhone && isPortrait
                                  ? Column(
                                      children: [
                                        Text('Kira-kira ini sampah apa?',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.headingExtraBold.copyWith(
                                              fontSize: AppResponsive.sp(size, 18).clamp(14.0, 22.0),
                                            )),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pilih kategori — AI yang memastikan.',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyMediumStatic.copyWith(
                                            fontSize: AppResponsive.sp(size, 12).clamp(10.0, 14.0),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            BinyHero(
                                              size: AppResponsive.iconSize(size, 56).clamp(44.0, 64.0),
                                              expression: BinyExpression.category,
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                ref.read(selectedCategoryProvider.notifier).state =
                                                    CategoryOption.fromWasteCategory(WasteCategory.lainnya);
                                                context.go('/camera-guide');
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primarySoft,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Text('Lewati',
                                                    style: AppTypography.pillLabel.copyWith(
                                                        color: AppColors.primaryPress,
                                                        fontSize: AppResponsive.sp(size, 12).clamp(10.0, 13.0))),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        BinyHero(
                                          size: 112,
                                          expression: BinyExpression.category,
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Kira-kira ini sampah apa?',
                                                  style: AppTypography.headingExtraBold),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Pilih perkiraan kategori — tenang, AI yang memastikan.',
                                                style: AppTypography.bodyMediumStatic,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: () {
                                            ref.read(selectedCategoryProvider.notifier).state =
                                                CategoryOption.fromWasteCategory(WasteCategory.lainnya);
                                            context.go('/camera-guide');
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySoft,
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text('Lewati',
                                                style: AppTypography.pillLabel.copyWith(
                                                    color: AppColors.primaryPress)),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: isPhone ? 8 : 24),

                            // Grid
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isPhone ? 20 : 32,
                              ),
                              child: Center(
                                child: _buildGrid(size, isPhone ? 2 : 3, isPhone: isPhone, ref: ref, context: context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(Size size, int cols, {required bool isPhone, required WidgetRef ref, required BuildContext context}) {
    final gap = isPhone ? 10.0 : 22.0;
    final rows = <Widget>[];
    final categoryOptions = ref.watch(categoryOptionsProvider);
    for (var r = 0; r < categoryOptions.length; r += cols) {
      final rowChildren = <Widget>[];
      for (var c = 0; c < cols; c++) {
        final idx = r + c;
        final isMissing = idx >= categoryOptions.length;
        rowChildren.add(
          Expanded(
            child: isMissing
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(
                      right: c < cols - 1 ? gap : 0,
                      bottom: gap,
                    ),
                    child: _buildCard(
                      size,
                      categoryOptions[idx],
                      isPhone: isPhone,
                      onTap: () {
                        ref.read(selectedCategoryProvider.notifier).state = categoryOptions[idx];
                        context.go('/camera-guide');
                      },
                    ),
                  ),
          ),
        );
      }
      rows.add(Row(children: rowChildren));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildCard(Size size, CategoryOption category, {required bool isPhone, required VoidCallback onTap}) {
    final catColor = category.color;

    final iconBox = isPhone ? 48.0 : 84.0;
    final nameSize = isPhone ? 16.0 : 26.0;
    final subSize = isPhone ? 11.0 : 15.0;
    final padH = isPhone ? 12.0 : 24.0;
    final padV = isPhone ? 14.0 : 22.0;
    final gap = isPhone ? 10.0 : 18.0;
    final radius = isPhone ? 20.0 : 32.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              padding: EdgeInsets.all(iconBox * 0.08),
              child: Image.asset(
                category.iconAsset,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    style: GoogleFonts.baloo2(
                      fontSize: nameSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    category.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: subSize,
                      fontWeight: FontWeight.w700,
                      color: catColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
