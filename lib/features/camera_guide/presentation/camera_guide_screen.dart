import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/camera_guide_provider.dart';
import '../../../core/providers/camera_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/biny_hero.dart';

class CameraGuideScreen extends ConsumerStatefulWidget {
  const CameraGuideScreen({super.key});

  @override
  ConsumerState<CameraGuideScreen> createState() => _CameraGuideScreenState();
}

class _CameraGuideScreenState extends ConsumerState<CameraGuideScreen> {
  int _currentStep = 0;
  Timer? _stepTimer;
  // Cache the notifier so it can be called safely in dispose() after ref tears down.
  late final CameraGuideNotifier _cameraGuideNotifier;

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
    _cameraGuideNotifier = ref.read(cameraGuideProvider.notifier);
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(cameraProvider.notifier).initializeCamera();
      if (mounted &&
          ref.read(cameraProvider).valueOrNull?.isInitialized == true) {
        ref.read(cameraGuideProvider.notifier).startValidation();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _cameraGuideNotifier.stopValidation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final category = selectedCategory ?? WasteCategory.plastik;
    final scanMode = ref.watch(scanModeProvider);
    final isMixed = scanMode == 'mixed';
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait =
        AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);

    final stepImages = isMixed ? _mixedStepImages : _singleStepImages;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isPhone && isPortrait
            ? _buildPhoneLayout(category, isMixed, size, stepImages)
            : _buildTabletLayout(category, isMixed, size, isPhone, stepImages),
      ),
    );
  }

  Widget _buildCameraPreview(
    bool isPhone,
    List<String> stepImages, {
    bool isMixed = false,
    double? explicitWidth,
    double? explicitHeight,
  }) {
    // Figma 226:1042: Live Camera panel — bg #19162b, rounded-32
    //   boundary (226:1043): 22px inset, dashed 2px rgba(124,92,252,0.35), rounded-22
    //   LIVE CAMERA pill (269:2446) at top-center
    // When explicitWidth/Height are null (tablet Expanded), Container fills
    // its parent's tight constraints. When set (phone scroll view), uses those.
    return Container(
      width: explicitWidth,
      height: explicitHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF19162B),
        borderRadius: BorderRadius.circular(isPhone ? 24 : 32),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // LIVE CAMERA pill — Figma 269:2446
          Positioned(
            top: isPhone ? 14 : 38,
            left: 0,
            right: 0,
            child: Center(child: _buildLiveCameraPill(isPhone)),
          ),

          // Step illustration centered, filling the camera preview area.
          Padding(
            padding: EdgeInsets.all(isPhone ? 14.0 : 22.0),
            child: _buildStepIllustration(isPhone, isMixed),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIllustration(bool isPhone, bool isMixed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Colorful illustration fills the FULL dashed-border area
        // (BoxFit.cover) — image is portrait, border is landscape, so cover
        // crops top/bottom to reach both edges. The label is overlaid at
        // bottom-center with a soft scrim so it stays readable.
        // Single-mode step 1/2 still uses the small monochrome icons.
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        // contain: full image visible, no cropping. Image is portrait and
        // the camera border is landscape, so there will be side margins —
        // acceptable trade-off vs. cropping content with cover.
        // contain: full image visible, no cropping. Image is portrait and
        // the camera preview is landscape, so there will be side margins —
        // acceptable trade-off vs. cropping content with cover.
        Widget colorfulImg(String asset) =>
            Image.asset(asset, fit: BoxFit.contain);

        Widget inner;
        if (_currentStep == 0) {
          inner = colorfulImg(
            isMixed
                ? 'assets/images/letakan sampah.png'
                : 'assets/images/letakan sampah single waste.png',
          );
        } else if (_currentStep == 1) {
          inner = colorfulImg(
            isMixed
                ? 'assets/images/beri jarak antar sampah.png'
                : 'assets/images/Atur tinggin papan.png',
          );
        } else {
          inner = colorfulImg(
            isMixed
                ? 'assets/images/semua masuk dalam kotak.png'
                : 'assets/images/jauhkan tangan.png',
          );
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

  Widget _buildLiveCameraPill(bool isPhone) {
    // Figma 269:2446: bg rgba(10,8,18,0.7), rounded-999,
    //   pl=16 pr=18 py=9 gap=9, 9×9 red dot,
    //   "LIVE CAMERA" 14px Baloo 2 Bold white ls 0.56
    return Container(
      padding: EdgeInsets.only(
        left: isPhone ? 10 : 16,
        right: isPhone ? 12 : 18,
        top: isPhone ? 6 : 9,
        bottom: isPhone ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0812).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isPhone ? 6 : 9,
            height: isPhone ? 6 : 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF3B3B),
            ),
          ),
          SizedBox(width: isPhone ? 6 : 9),
          Text(
            'LIVE CAMERA',
            style: GoogleFonts.baloo2(
              fontSize: isPhone ? 10 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.56,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(bool isPhone) {
    // Figma 226:3018: bg #7c5cfc, px=32 py=20, rounded-999,
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
    WasteCategory category,
    bool isMixed,
    Size size,
    List<String> stepImages,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode pill + Ganti
          isMixed ? _buildMixedPill() : _buildCategoryPill(category),
          const SizedBox(height: 16),

          // Camera preview
          _buildCameraPreview(
            true,
            stepImages,
            isMixed: isMixed,
            explicitWidth: size.width - 32,
            explicitHeight: size.height * 0.35,
          ),
          const SizedBox(height: 20),

          // Biny mascot — centered
          Center(child: BinyHero(size: 130, expression: BinyExpression.guide)),
          const SizedBox(height: 22),

          // Title
          Center(
            child: Text(
              isMixed ? 'Ada yang keluar frame' : 'Siap memindai?',
              textAlign: TextAlign.center,
              style: AppTypography.headingExtraBold.copyWith(
                fontSize: AppResponsive.sp(size, 22).clamp(18.0, 26.0),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              isMixed
                  ? 'Geser ke tengah biar semua terbaca'
                  : 'Pastikan 3 hal ini dulu',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMediumStatic.copyWith(
                fontSize: AppResponsive.sp(size, 14).clamp(12.0, 16.0),
              ),
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
              iconAsset: 'assets/images/page_6/ic-hand.png',
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
          const SizedBox(height: 20),

          // Mulai Scan button
          _buildScanButton(true),
          if (isMixed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Rapikan sampah dulu untuk mulai',
                  style: AppTypography.captionStatic.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(
    WasteCategory category,
    bool isMixed,
    Size size,
    bool isPhone,
    List<String> stepImages,
  ) {
    // Figma 226:1041 layout:
    //   Outer padding 26px (top/right/bottom/left)
    //   Row gap 26px between camera and side panel
    //   Camera (666×782) + side (450×782) split → flex 666 / 450
    //
    // Right panel (226:1059) internal layout from Figma metadata:
    //   24px top padding → cat-bar (44px) → Frame 13 (626px, content centered)
    //   → Button (64px) → 24px bottom padding
    final pad = isPhone ? 14.0 : 26.0;
    final gap = isPhone ? 14.0 : 26.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Camera panel — Figma 226:1042: 666×782
          // Container fills Expanded via tight constraints (no explicit dimensions)
          Expanded(
            flex: 666,
            child: _buildCameraPreview(isPhone, stepImages, isMixed: isMixed),
          ),
          SizedBox(width: gap),

          // Right: cam-side — Figma 226:1059: 450×782
          //   Cat-bar flush at top (aligns with camera panel top edge).
          //   Button raised 24px from bottom so its drop shadow
          //   (offset 12 blur 22 + offset 6) visually aligns with the
          //   camera panel's bottom edge — matches Figma 226:3018 (y=694).
          //   Middle content uses Expanded to prevent overflow.
          Expanded(
            flex: 450,
            child: Padding(
              padding: EdgeInsets.only(
                left: isPhone ? 6 : 0,
                right: isPhone ? 6 : 0,
                bottom: isPhone ? 14 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top: cat-bar — flush with camera panel top edge
                  isMixed ? _buildMixedPill() : _buildCategoryPill(category),

                  // Middle: Expanded content area — Figma 226:3014: y=68, h=626
                  // Content centered within this area (Figma: ~54px padding top & bottom).
                  // Biny mascot sits above the title inside the centered column.
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Centered content (Biny mascot / title / subtitle / step cards)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BinyHero(
                                size: 120,
                                expression: BinyExpression.guide,
                              ),
                              const SizedBox(height: 22),
                              // Title — Figma 226:1099: 30px Baloo 2 ExtraBold leading 34
                              Text(
                                isMixed
                                    ? 'Ada yang keluar frame'
                                    : 'Siap memindai?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  fontSize: isPhone ? 22 : 30,
                                  fontWeight: FontWeight.w800,
                                  height: 34 / 30,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: isPhone ? 4 : 6),
                              // Subtitle — Figma 226:1100: 16px Plus Jakarta Sans Medium
                              Text(
                                isMixed
                                    ? 'Geser ke tengah biar semua terbaca'
                                    : 'Pastikan 3 hal ini dulu',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: isPhone ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: isPhone ? 14 : 22),

                              // Step cards — Figma 226:1101: col gap-14
                              if (isMixed) ...[
                                _StepCard(
                                  number: '1',
                                  title: 'Letakkan Sampah',
                                  subtitle: 'Taruh di atas papan hitam',
                                  iconAsset: 'assets/images/page_6/inbox.png',
                                  isPhone: isPhone,
                                  isActive: _currentStep == 0,
                                ),
                                SizedBox(height: isPhone ? 10 : 14),
                                _StepCard(
                                  number: '2',
                                  title: 'Beri jarak antar sampah',
                                  subtitle: 'Jangan saling menempel / menumpuk',
                                  iconAsset:
                                      'assets/images/page_6/move-vertical.png',
                                  isPhone: isPhone,
                                  isActive: _currentStep == 1,
                                ),
                                SizedBox(height: isPhone ? 10 : 14),
                                _StepCard(
                                  number: '3',
                                  title: 'Semua masuk dalam kotak',
                                  subtitle: 'Jangan ada yang keluar frame',
                                  iconAsset: 'assets/images/page_6/ic-hand.png',
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
                                SizedBox(height: isPhone ? 10 : 14),
                                _StepCard(
                                  number: '2',
                                  title: 'Atur Tinggi Papan',
                                  subtitle: 'Naik-turunkan agar pas di frame',
                                  iconAsset:
                                      'assets/images/page_6/move-vertical.png',
                                  isPhone: isPhone,
                                  isActive: _currentStep == 1,
                                ),
                                SizedBox(height: isPhone ? 10 : 14),
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
                      ],
                    ),
                  ),

                  // Bottom: Mulai Scan button — Figma 226:3018: y=694, h=64
                  // (24px above panel bottom so shadow aligns with camera edge)
                  _buildScanButton(isPhone),
                  if (isMixed)
                    Padding(
                      padding: EdgeInsets.only(top: isPhone ? 6 : 8),
                      child: Center(
                        child: Text(
                          'Rapikan sampah dulu untuk mulai',
                          style: AppTypography.captionStatic.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(WasteCategory category) {
    // Figma 226:1061: cat-bar uses justify-between (Plastik left, Ganti right)
    // Figma 226:1062: cat-tag with border #d1e7ff 1.5px, padding l=12 r=24 py=8,
    //   rounded-999, 28×28 icon, "Plastik" 17px Baloo 2 ExtraBold category color
    // Figma 226:2997: Ganti button bg primary-soft, px=24 py=12, rounded-999,
    //   "Ganti" 19px Baloo 2 Bold #5b3fd6 ls 0.095
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.only(
            left: 12,
            right: 24,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD1E7FF), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 28, color: category.color),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: category.color,
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

  Widget _buildMixedPill() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Mode: Mixed Waste',
                style: AppTypography.bodyBoldStatic.copyWith(
                  fontSize: 14,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Ganti',
              style: AppTypography.pillLabel.copyWith(
                color: AppColors.primaryPress,
                fontSize: 13,
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
    // Figma 226:1102/1112/1123:
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

    final shadowColor = isActive && isWarning
        ? const Color(0xFFFFB02E).withValues(alpha: 0.18)
        : AppColors.primaryPress.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 14 : 20,
        vertical: isPhone ? 12 : 18,
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
            offset: const Offset(0, 6),
            blurRadius: 18,
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
