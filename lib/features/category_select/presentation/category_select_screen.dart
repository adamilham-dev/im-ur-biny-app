import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
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
    final isPortrait =
        AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    ;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background decorative blobs (Figma 226:944, 226:945) ──
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
                      child: SizedBox(
                        height: constraints.maxHeight,
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
                                        Text(
                                          'Kira-kira ini sampah apa?',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.headingExtraBold
                                              .copyWith(
                                                fontSize: AppResponsive.sp(
                                                  size,
                                                  18,
                                                ).clamp(14.0, 22.0),
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pilih kategori — AI yang memastikan.',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyMediumStatic
                                              .copyWith(
                                                fontSize: AppResponsive.sp(
                                                  size,
                                                  12,
                                                ).clamp(10.0, 14.0),
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            BinyHero(
                                              size: AppResponsive.iconSize(
                                                size,
                                                56,
                                              ).clamp(44.0, 64.0),
                                              expression:
                                                  BinyExpression.category,
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                ref
                                                    .read(
                                                      selectedCategoryProvider
                                                          .notifier,
                                                    )
                                                    .state = WasteCategory
                                                    .lainnya;
                                                context.go('/camera-guide');
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primarySoft,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        100,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Lewati',
                                                  style: AppTypography.pillLabel
                                                      .copyWith(
                                                        color: AppColors
                                                            .primaryPress,
                                                        fontSize:
                                                            AppResponsive.sp(
                                                              size,
                                                              12,
                                                            ).clamp(10.0, 13.0),
                                                      ),
                                                ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Kira-kira ini sampah apa?',
                                                style: AppTypography
                                                    .headingExtraBold,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Pilih perkiraan kategori — tenang, AI yang memastikan.',
                                                style: AppTypography
                                                    .bodyMediumStatic,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: () {
                                            ref
                                                    .read(
                                                      selectedCategoryProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                WasteCategory.lainnya;
                                            context.go('/camera-guide');
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySoft,
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              'Lewati',
                                              style: AppTypography.pillLabel
                                                  .copyWith(
                                                    color:
                                                        AppColors.primaryPress,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: isPhone ? 8 : 24),

                            // Grid
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isPhone ? 20 : 0,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: isPhone ? null : 1077.0,
                                  child: GridView.count(
                                    crossAxisCount: isPhone ? 2 : 3,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: isPhone ? 12 : 24,
                                    crossAxisSpacing: isPhone ? 12 : 24,
                                    childAspectRatio: isPhone
                                        ? 2.2
                                        : (343 / 128),
                                    children: _categories
                                        .map(
                                          (cat) => _CategoryCard(
                                            iconAsset: cat.iconAsset,
                                            name: cat.name,
                                            description: cat.description,
                                            color: cat.color,
                                            isPhone: isPhone,
                                            onTap: () {
                                              ref
                                                      .read(
                                                        selectedCategoryProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  cat.wasteCategory;
                                              context.go('/camera-guide');
                                            },
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
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
}

class _CategoryData {
  final String iconAsset;
  final String name;
  final String description;
  final Color color;
  final WasteCategory wasteCategory;

  const _CategoryData({
    required this.iconAsset,
    required this.name,
    required this.description,
    required this.color,
    required this.wasteCategory,
  });
}

const _categories = <_CategoryData>[
  _CategoryData(
    iconAsset: 'assets/images/page_5/plastik.png',
    name: 'Plastik',
    description: 'Botol, kemasan',
    color: AppColors.catPlastik,
    wasteCategory: WasteCategory.plastik,
  ),
  _CategoryData(
    iconAsset: 'assets/images/page_5/kertas.png',
    name: 'Kertas',
    description: 'Kardus, koran',
    color: AppColors.catKertas,
    wasteCategory: WasteCategory.kertas,
  ),
  _CategoryData(
    iconAsset: 'assets/images/page_5/organik.png',
    name: 'Organik',
    description: 'Sisa makanan',
    color: AppColors.catOrganik,
    wasteCategory: WasteCategory.organik,
  ),
  _CategoryData(
    iconAsset: 'assets/images/page_5/logam.png',
    name: 'Logam',
    description: 'Kaleng, tutup',
    color: AppColors.catLogam,
    wasteCategory: WasteCategory.logam,
  ),
  _CategoryData(
    iconAsset: 'assets/images/page_5/residu.png',
    name: 'Residu',
    description: 'Tidak terdaur',
    color: AppColors.catResidu,
    wasteCategory: WasteCategory.residu,
  ),
  _CategoryData(
    iconAsset: 'assets/images/page_5/auto.png',
    name: 'Auto',
    description: 'Biar AI tentukan',
    color: AppColors.catLainnya,
    wasteCategory: WasteCategory.lainnya,
  ),
];

class _CategoryCard extends StatelessWidget {
  final String iconAsset;
  final String name;
  final String description;
  final Color color;
  final bool isPhone;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.iconAsset,
    required this.name,
    required this.description,
    required this.color,
    required this.isPhone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isPhone ? 38.0 : 84.0;
    final fontSize = isPhone ? 15.0 : 26.0;
    final descSize = isPhone ? 11.0 : 15.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 10 : 24,
          vertical: isPhone ? 10 : 22,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isPhone ? 18 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
            SizedBox(width: isPhone ? 10 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: AppTypography.headingBold.copyWith(
                      fontSize: fontSize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.bodyBoldStatic.copyWith(
                      fontSize: descSize,
                      color: color,
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
