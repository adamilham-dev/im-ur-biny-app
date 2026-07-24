import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/category_options_provider.dart';
import '../../../core/models/category_option.dart';
import '../../../shared/widgets/biny_hero.dart';

class CameraGuideScreen extends ConsumerStatefulWidget {
  const CameraGuideScreen({super.key});

  @override
  ConsumerState<CameraGuideScreen> createState() => _CameraGuideScreenState();
}

class _CameraGuideScreenState extends ConsumerState<CameraGuideScreen> {
  int _currentStep = 0;
  Timer? _stepTimer;

  static const _singleStepImages = [
    'assets/images/page_6/inbox.png',
    'assets/images/page_6/move-vertical.png',
    'assets/images/page_6/ic-hand.png',
  ];

  static const _mixedStepImages = [
    'assets/images/page_6/inbox.png',
    'assets/images/page_6/move-vertical.png',
    'assets/images/page_6/ic-hand.png',
  ];

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % 3;
        });
      }
    });
    Future.microtask(() {
      ref.read(scanProvider.notifier).clearResult();
      ref.read(capturedImageProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryOption = ref.watch(selectedCategoryProvider);
    final scanMode = ref.watch(scanModeProvider);
    final isMixed = scanMode == 'mixed';
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size);

    final stepImages = isMixed ? _mixedStepImages : _singleStepImages;

    final selectedCategoryOpt = selectedCategoryOption ?? CategoryOption.fromWasteCategory(WasteCategory.plastik);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isPhone && isPortrait
            ? _buildPhoneLayout(selectedCategoryOpt, isMixed, size, stepImages)
            : _buildTabletLayout(selectedCategoryOpt, isMixed, size, isPhone, stepImages),
      ),
    );
  }

  Widget _buildCameraPreview(
      bool isPhone, List<String> stepImages,
      {bool isMixed = false, double? explicitWidth, double? explicitHeight}) {
    // Live Camera panel — bg #19162b, rounded-32
    // boundary: 22px inset, dashed 2px rgba(124,92,252,0.35), rounded-22
    // LIVE CAMERA pill at top-center
    //
    // The pill is rendered as a SIBLING Positioned on top of the camera
    // panel, NOT as a child inside the clipped Container. Previously the
    // pill lived inside the clip area as the second Stack child, and the
    // cycling illustration image (which fills the full panel height after
    // the 14/22px padding) painted over/around it — the pill was being
    // visually swallowed at the top edge ("tidak muncul, kehalang sama
    // border"). Lifting it out of the clip guarantees it stays visible
    // regardless of how the illustration image is sized by BoxFit.contain.
    return Container(
      width: explicitWidth,
      height: explicitHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF19162B),
        borderRadius: BorderRadius.circular(isPhone ? 24 : 32),
      ),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 14.0 : 22.0),
        child: _buildStepIllustration(isPhone, isMixed),
      ),
    );
  }

  Widget _buildStepIllustration(bool isPhone, bool isMixed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        Widget colorfulImg(String asset) =>
            Image.asset(asset, fit: BoxFit.contain);

        Widget inner;
        if (_currentStep == 0) {
          inner = colorfulImg(isMixed
              ? 'assets/images/letakan sampah.png'
              : 'assets/images/letakan sampah single waste.png');
        } else if (_currentStep == 1) {
          inner = colorfulImg(isMixed
              ? 'assets/images/beri jarak antar sampah.png'
              : 'assets/images/Atur tinggin papan.png');
        } else {
          inner = colorfulImg(isMixed
              ? 'assets/images/semua masuk dalam kotak.png'
              : 'assets/images/jauhkan tangan.png');
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: SizedBox(
            key: ValueKey(_currentStep),
            width: boxW,
            height: boxH,
            child: inner,
          ),
        );
      },
    );
  }

  Widget _buildScanButton(bool isPhone) {
    // bg #7c5cfc, px=32 py=20, rounded-999
    //   shadow rgba(124,92,252,0.35) offset(0,12) blur-22 + #5b3fd6 offset(0,6),
    //   24×24 scan-line icon, "Mulai Scan" 19px Baloo 2 Bold white ls 0.095
    return GestureDetector(
      onTap: () {
        // Start fresh: capture photo first, then countdown, then AI scan
        ref.read(rescanProvider.notifier).state = false;
        context.go('/scanning');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 20 : 32,
          vertical: isPhone ? 14 : 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              offset: const Offset(0, 12),
              blurRadius: 22,
            ),
            const BoxShadow(
              color: Color(0xFF5B3FD6),
              offset: Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/page_6/scan-line.png',
              width: 24,
              height: 24,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 12),
            Text(
              'Mulai Scan',
              style: GoogleFonts.baloo2(
                fontSize: isPhone ? 15 : 19,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(
      CategoryOption selectedCategoryOption, bool isMixed, Size size, List<String> stepImages) {
    // Structure: outer Column (fills SafeArea) with a scrollable content area
    // in the middle (Expanded) and the Mulai Scan button PINNED at the bottom.
    // This pushes the button to the bottom of the visible area with a gap above
    // it, instead of stacking directly under the last step card (which left a
    // large empty area below the button on tall phones).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // Mode pill + Ganti (pinned top)
          isMixed ? _buildMixedPill() : _buildCategoryPill(selectedCategoryOption),
          const SizedBox(height: 16),

          // Scrollable middle: camera preview, mascot, title, step cards.
          // Top-aligned so content flows from the top and the leftover space
          // gathers just above the pinned button.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera preview — height trimmed from 0.35 → 0.30 so the
                  // scroll content fits with breathing room above the pinned
                  // Mulai Scan button. At 0.35 on common phone heights the
                  // content was ~taller than the Expanded, so when scrolled to
                  // the bottom the trailing gap was clipped and card 3 read
                  // as "nempel" (tertutup) against the button.
                  _buildCameraPreview(true, stepImages,
                      isMixed: isMixed,
                      explicitWidth: size.width - 32,
                      explicitHeight: size.height * 0.30),
                  const SizedBox(height: 16),

                  // Biny mascot — pushed to the right side (away from the
                  // centered camera preview column) and shrunk to keep it out
                  // of the way.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: BinyHero(
                        size: AppResponsive.iconSize(size, 52).clamp(40.0, 56.0),
                        expression: BinyExpression.guide,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    'Siap memindai?',
                    style: AppTypography.headingExtraBold.copyWith(
                      fontSize: AppResponsive.sp(size, 22).clamp(18.0, 26.0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pastikan 3 hal ini dulu',
                    style: AppTypography.bodyMediumStatic.copyWith(
                      fontSize: AppResponsive.sp(size, 14).clamp(12.0, 16.0),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step cards
                  if (isMixed) ...[
                    _StepCard(
                      number: '1',
                      title: 'Letakkan Sampah',
                      subtitle: 'Taruh di atas papan hitam',
                      iconAsset: 'assets/images/page_6/inbox.png',
                      isPhone: true,
                      isActive: _currentStep == 0,
                    ),
                    const SizedBox(height: 8),
                    _StepCard(
                      number: '2',
                      title: 'Beri jarak antar sampah',
                      subtitle: 'Jangan saling menempel / menumpuk',
                      iconAsset: 'assets/images/page_6/move-vertical.png',
                      isPhone: true,
                      isActive: _currentStep == 1,
                    ),
                    const SizedBox(height: 8),
                    _StepCard(
                      number: '3',
                      title: 'Semua masuk dalam kotak',
                      subtitle: 'Jangan ada yang keluar frame',
                      iconAsset: 'assets/images/page_6/frame_corners.svg',
                      isWarning: true,
                      isPhone: true,
                      isActive: _currentStep == 2,
                    ),
                  ] else ...[
                    _StepCard(
                      number: '1',
                      title: 'Letakkan Sampah',
                      subtitle: 'Taruh di atas papan hitam',
                      iconAsset: 'assets/images/page_6/inbox.svg',
                      isPhone: true,
                      isActive: _currentStep == 0,
                    ),
                    const SizedBox(height: 8),
                    _StepCard(
                      number: '2',
                      title: 'Atur Tinggi Papan',
                      subtitle: 'Naik-turunkan agar pas di frame',
                      iconAsset: 'assets/images/page_6/move-vertical.png',
                      isPhone: true,
                      isActive: _currentStep == 1,
                    ),
                    const SizedBox(height: 8),
                    _StepCard(
                      number: '3',
                      title: 'Jauhkan Tangan',
                      subtitle: 'Biar yang terbaca cuma sampah',
                      iconAsset: 'assets/images/page_6/ic-hand.png',
                      isWarning: true,
                      isPhone: true,
                      isActive: _currentStep == 2,
                    ),
                  ],
                  // Trailing breathing room before the pinned button.
                  // Bumped 20 → 32 so even when the scroll settles at the
                  // bottom, there's a clearly visible gap between card 3
                  // and the pinned Mulai Scan button (was reading as
                  // "tertutup" / touching at 20px on shorter phones).
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Mulai Scan button — pinned to the bottom of the visible area.
          _buildScanButton(true),
          const SizedBox(height: 12),

          // scanhint — info icon +
          // "Rapikan sampah dulu untuk mulai"
          if (isMixed)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/page_6/lock_hint.svg',
                    width: 15,
                    height: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Rapikan sampah dulu untuk mulai',
                    style: AppTypography.captionStatic.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(CategoryOption selectedCategoryOption, bool isMixed, Size size,
      bool isPhone, List<String> stepImages) {
    // layout
    //   Outer padding 26px (top/right/bottom/left)
    //   Row gap 26px between camera and side panel
    //   Camera (666×782) + side (450×782) split → flex 666 / 450
    //
    // Right panel internal layout from Figma metadata
    //   24px top padding → cat-bar (44px) → Frame 13 (626px, content centered)
    //   → Button (64px) → 24px bottom padding
    final pad = isPhone ? 14.0 : 26.0;
    final gap = isPhone ? 14.0 : 26.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Camera panel — 666×782
          // Container fills Expanded via tight constraints (no explicit dimensions)
          Expanded(
            flex: 666,
            child: _buildCameraPreview(
              isPhone, stepImages,
              isMixed: isMixed,
            ),
          ),
          SizedBox(width: gap),

          // Right: cam-side — 450×782
          //   Column(pt=24, justify-between, items-center):
          //     cat-bar (44/46) → Frame 36 (Expanded, content centered, gap=22)
          //     → Button (64) → scanhint (pt=24, mixed only) / 24px bottom gap (single)
          Expanded(
            flex: 450,
            child: Padding(
              padding: EdgeInsets.only(
                left: isPhone ? 6 : 0,
                right: isPhone ? 6 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Figma: 24px top gap before cat-bar (at y=24)
                  SizedBox(height: isPhone ? 12 : 24),

                  // Top: cat-bar
                  isMixed ? _buildMixedPill() : _buildCategoryPill(selectedCategoryOption),

                  // Middle: Frame 36 — Expanded
                  //   Column(gap=22, items-center, justify=center).
                  //   Children: mascot (124h) → head (title+subtitle) → cinfo (3 cards, gap=14).
                  //
                  // Pattern: LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight)
                  // so the inner Column top-aligns when content fits the available
                  // height (leftover space pools BETWEEN the cards and the pinned
                  // button — keeping "Mulai Scan" low on the panel), AND scrolls
                  // cleanly when it doesn't (smaller windows / tablets with bigger
                  // safe-area insets were causing a RenderFlex overflow here). The
                  // button stays pinned below the Expanded — scrolling only happens
                  // inside the Expanded area.
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isPhone ? 4 : 8,
                        isPhone ? 4 : 8,
                        isPhone ? 4 : 8,
                        isPhone ? 16 : 20,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                // Top-align so mascot sits just under the mode
                                // pill and ALL spare height gathers between the
                                // last card and the pinned Mulai Scan button.
                                // (center left the content floating mid-panel
                                // and the button reading "too high".)
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Biny mascot — 118×123.9.
                                  Center(
                                    child: BinyHero(
                                      size: isPhone ? 88 : 124,
                                      expression: BinyExpression.guide,
                                    ),
                                  ),
                                  SizedBox(height: isPhone ? 12 : 22),

                                  // head — Column(items-center)
                                  //   Title 30px Baloo 2 ExtraBold leading 34
                                  //   Subtitle 16px Plus Jakarta Sans Medium leading 1.5
                                  Text(
                                    'Siap memindai?',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      fontSize: isPhone ? 22 : 30,
                                      fontWeight: FontWeight.w800,
                                      height: 34 / 30,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: isPhone ? 4 : 6),
                                  Text(
                                    'Pastikan 3 hal ini dulu',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: isPhone ? 14 : 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: isPhone ? 14 : 22),

                                  // cinfo — Column(gap=14)
                                  if (isMixed) ...[
                                    _StepCard(
                                      number: '1',
                                      title: 'Letakkan Sampah',
                                      subtitle: 'Taruh di atas papan hitam',
                                      iconAsset: 'assets/images/page_6/inbox.png',
                                      isPhone: isPhone,
                                      isActive: _currentStep == 0,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 10),
                                    _StepCard(
                                      number: '2',
                                      title: 'Beri jarak antar sampah',
                                      subtitle: 'Jangan saling menempel / menumpuk',
                                      iconAsset: 'assets/images/page_6/move-vertical.png',
                                      isPhone: isPhone,
                                      isActive: _currentStep == 1,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 10),
                                    _StepCard(
                                      number: '3',
                                      title: 'Semua masuk dalam kotak',
                                      subtitle: 'Jangan ada yang keluar frame',
                                      iconAsset: 'assets/images/page_6/frame_corners.svg',
                                      isWarning: true,
                                      isPhone: isPhone,
                                      isActive: _currentStep == 2,
                                    ),
                                  ] else ...[
                                    _StepCard(
                                      number: '1',
                                      title: 'Letakkan Sampah',
                                      subtitle: 'Taruh di atas papan hitam',
                                      iconAsset: 'assets/images/page_6/inbox.svg',
                                      isPhone: isPhone,
                                      isActive: _currentStep == 0,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 10),
                                    _StepCard(
                                      number: '2',
                                      title: 'Atur Tinggi Papan',
                                      subtitle: 'Naik-turunkan agar pas di frame',
                                      iconAsset: 'assets/images/page_6/move-vertical.png',
                                      isPhone: isPhone,
                                      isActive: _currentStep == 1,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 10),
                                    _StepCard(
                                      number: '3',
                                      title: 'Jauhkan Tangan',
                                      subtitle: 'Biar yang terbaca cuma sampah',
                                      iconAsset: 'assets/images/page_6/ic-hand.png',
                                      isWarning: true,
                                      isPhone: isPhone,
                                      isActive: _currentStep == 2,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom: Mulai Scan button — h=64
                  _buildScanButton(isPhone),

                  // scanhint — gap=7
                  // 15×15 LOCK icon (Figma asset 0e8441f3 — padlock SVG
                  //   scan is locked until trash is tidied) +
                  //   13px Plus Jakarta Sans SemiBold text.
                  //   Mixed mode only; single mode just has a small bottom gap.
                  //   Scanhint content is anchored to the bottom of cam-side
                  //   (last child of Column), so changing this top padding
                  //   moves ONLY the button — the hint text stays put.
                  if (isMixed)
                    Padding(
                      padding: EdgeInsets.only(top: isPhone ? 12 : 16),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/page_6/lock_hint.svg',
                              width: 15,
                              height: 15,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Rapikan sampah dulu untuk mulai',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isPhone ? 11 : 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(height: isPhone ? 12 : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(CategoryOption option) {
    // cat-bar uses justify-between (Plastik left, Ganti right)
    // cat-tag with border #d1e7ff 1.5px, padding l=12 r=24 py=8
    //   rounded-999, 28×28 icon, "Plastik" 17px Baloo 2 ExtraBold category color
    // Ganti button bg primary-soft, px=24 py=12, rounded-999
    //   "Ganti" 19px Baloo 2 Bold #5b3fd6 ls 0.095
    //
    // Icon uses the SAME colorful PNG assets as /category-select so the two
    // screens match.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 12, right: 24, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: option.color.withValues(alpha: 0.3), 
              width: 1.5
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCategoryIcon(option, 28),
              const SizedBox(width: 10),
              Text(
                option.name,
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: option.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.go('/mode-select'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Ganti',
              style: GoogleFonts.baloo2(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.095,
                color: AppColors.primaryPress,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the colorful PNG asset path used by /category-select for the
  /// given category, or null when no PNG exists (kaca) — caller should fall
  /// back to the Material icon.
  String? _categoryIconAsset(WasteCategory category) {
    switch (category) {
      case WasteCategory.plastik:
        return 'assets/images/page_5/plastik.png';
      case WasteCategory.kertas:
        return 'assets/images/page_5/kertas.png';
      case WasteCategory.organik:
        return 'assets/images/page_5/organik.png';
      case WasteCategory.logam:
        return 'assets/images/page_5/logam.png';
      case WasteCategory.residu:
        return 'assets/images/page_5/residu.png';
      case WasteCategory.lainnya:
        return 'assets/images/page_5/auto.png';
    }
  }

  Widget _buildCategoryIcon(CategoryOption? option, double size) {
    if (option == null) return const SizedBox.shrink();
    
    // Some assets are PNG, but others might be generic fallback
    final assetPath = option.iconAsset;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if asset is missing
          return Icon(
            Icons.category, // Fallback icon
            size: size * 0.8,
            color: option.color,
          );
        },
      ),
    );
  }

  Widget _buildMixedPill() {
    // cat-bar / mode-tag
    //   w=214, h=46. PRIMARY SOFT bg (#ede8ff) — NOT white; white blended with
    //   the screen bg and looked "bgless". Border #ddd5fe 1.5px.
    //   padding l=8 r=16 t=7 b=7, rounded-999.
    //   32×32 icon container bg SURFACE (white) rounded-10 with 19×19 layers icon.
    //   Then INLINE text row (vertically centered):
    //     "Mode" 13px Plus Jakarta Sans SemiBold muted
    //     11px gap
    //     "Mixed Waste" 17px Baloo 2 ExtraBold primary
    // Ganti button: bg primarySoft, px=24 py=12.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 7, bottom: 7),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDDD5FE), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.layers, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Text(
                'Mode',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                'Mixed Waste',
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.go('/mode-select'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Ganti',
              style: GoogleFonts.baloo2(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.095,
                color: AppColors.primaryPress,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final String iconAsset;
  final bool isWarning;
  final bool isPhone;
  final bool isActive;

  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    this.isWarning = false,
    this.isPhone = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Container: bg white, px=20 py=18, rounded-20,
    //   shadow rgba(91,63,214,0.08) offset(0,6) blur-18
    // Step 3 (active/warning): border 2px primary, shadow rgba(255,176,46,0.18)
    // Row gap 16:
    //   Number circle: 40×40 bg primary rounded-999, "n" 18px Baloo 2 ExtraBold white
    //   Title: 18px Baloo 2 Bold #2b2a45
    //   Subtitle: 14px Plus Jakarta Sans Bold #908dac leading 1.4 ls 0.028
    //   Icon container: 40×40 bg primary-soft rounded-13, icon 20×20 (22×22 step 3)
    final numCircleSize = isPhone ? 32.0 : 40.0;
    final iconBoxSize = isPhone ? 32.0 : 40.0;
    final iconImgSize = isPhone ? 16.0 : (isWarning ? 22.0 : 20.0);

    // — ALL step cards use purple shadow, never yellow
    //   inactive: rgba(91,63,214,0.08)  offset 6 blur 18
    //   active:   rgba(124,92,252,0.18) offset 8 blur 22  (+ 2px primary border)
    // The earlier `isWarning && isActive` branch here gave step 3 a YELLOW
    // shadow; that yellow glow flared ~24px down into the Mulai Scan button's
    // own purple drop shadow, making the two look "nempel" even though the
    // boxes had a real gap. Match Figma — purple only.
    //
    // Shadow blur reduced from Figma's 22/18 → 14/10 so the active card's
    // glow doesn't bleed down into the Mulai Scan button area when the
    // column is centered near the bottom of the Expanded (gap was reading
    // as "nempel" even though logical rects had clearance).
    final shadowColor = isActive
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primaryPress.withValues(alpha: 0.08);
    final shadowBlur = isActive ? 14.0 : 10.0;
    final shadowOffset = isActive ? 6.0 : 4.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Card vertical padding trimmed 18→14 to free up vertical headroom on
      // shorter tablets, where mascot + title + 3 cards otherwise overflow the
      // side panel and step 3 lands flush against the Mulai Scan button
      // ("nempel"). Mascot & button are NOT touched here.
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 14 : 20,
        vertical: isPhone ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: Offset(0, shadowOffset),
            blurRadius: shadowBlur,
          ),
        ],
      ),
      child: Row(
        children: [
          // Number circle — always primary per Figma
          Container(
            width: numCircleSize,
            height: numCircleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.baloo2(
                  fontSize: isPhone ? 14 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.surface,
                ),
              ),
            ),
          ),
          SizedBox(width: isPhone ? 10 : 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.baloo2(
                    fontSize: isPhone ? 14 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isPhone ? 11 : 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: 0.028,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isPhone ? 8 : 16),
          // Icon container — 40×40 bg primary-soft rounded-13 per Figma
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(isPhone ? 11 : 13),
            ),
            child: Center(
              child: _buildIcon(iconAsset, iconImgSize, AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String asset, double size, Color color) {
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}
