import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  static const int _totalPages = 3;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      title: "Arahkan ke Kamera",
      subtitle:
          "Letakkan sampah di tengah papan, lalu pastikan posisinya terlihat jelas dan fokus oleh kamera.",
      badgeIconPath: 'assets/images/page_3/Camera-1 Streamline Flex.svg',
      badgeBg: AppColors.primarySoft,
      badgeIconColor: AppColors.primary,
      expression: BinyExpression.onboard1,
    ),
    _OnboardingStep(
      title: "Tunggu Scan Selesai",
      subtitle:
          "AI akan otomatis mendeteksi dan mengidentifikasi jenis sampahmu. Tunggu sebentar sampai proses scan selesai.",
      badgeIconPath:
          'assets/images/page_3/Search-Category Streamline Flex.svg',
      badgeBg: AppColors.successSoft,
      badgeIconColor: AppColors.success,
      expression: BinyExpression.onboard3,
    ),
    _OnboardingStep(
      title: "Dapatkan Poin!",
      subtitle:
          "Setiap sampah yang terpilah dengan benar akan memberikan reward XP. Kumpulkan poin dan naik ke level berikutnya.",
      badgeIconPath:
          'assets/images/page_3/Star-Circle Streamline Flex 2.svg',
      badgeBg: AppColors.warningSoft,
      badgeIconColor: AppColors.warning,
      expression: BinyExpression.onboard4,
    ),
  ];

  void _handleBack() {
    if (_currentPage == 0) {
      context.go('/welcome');
    } else {
      setState(() => _currentPage--);
    }
  }

  void _handleNext() {
    if (_currentPage == _totalPages - 1) {
      context.go('/mode-select');
    } else {
      setState(() => _currentPage++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background decorative blobs ──
          if (isPortrait) ...[
            // Lavender — top-left
            Positioned(
              left: -size.width * 0.15,
              top: -size.width * 0.25,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.75,
                  height: size.width * 0.75,
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
            // Mint — bottom-right
            Positioned(
              right: -size.width * 0.2,
              bottom: -size.width * 0.15,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.9,
                  height: size.width * 0.9,
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
          ] else ...[
            // ── Landscape — Figma-exact proportions ──
            // Lavender — top-left (Figma: -140,-180 → 560×560)
            Positioned(
              left: size.width * -0.117,
              top: size.height * -0.216,
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
            // Mint — bottom-right (Figma: 804,494 → 520×520)
            Positioned(
              right: size.width * -0.109,
              bottom: size.height * -0.216,
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
          ],
          // ── Content ──
          // Content + buttons form one vertically centered group, so the
          // buttons sit a small fixed gap below the subtitle.
          SafeArea(
            child: Center(
              child: SizedBox(
                width: isPhone ? size.width : 760,
                child: Column(
                  children: [
                    SizedBox(height: isPhone ? 24 : 40),
                    // Dots
                    _buildStepDots(isPhone),
                    const Spacer(),
                    // Content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildContent(isPhone),
                    ),
                    SizedBox(height: isPhone ? 20 : 32),
                    // Buttons — directly below content
                    _buildButtons(isPhone),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDots(bool isPhone) {
    // active dot 26×9 (#7c5cfc), inactive 9×9 (#ede8ff), gap 8
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: isPhone ? 3 : 4),
          width: isActive ? (isPhone ? 20 : 26) : (isPhone ? 7 : 9),
          height: isPhone ? 7 : 9,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildContent(bool isPhone) {
    final step = _steps[_currentPage];
    final size = MediaQuery.of(context).size;
    final mascotSize = isPhone
        ? AppResponsive.iconSize(size, 160).clamp(120.0, 180.0)
        : 240.0;

    return Column(
      key: ValueKey(_currentPage),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mascot + badge. The badge is passed to BinyHero.foreground so the
        // global flight overlay paints it ON TOP of the mascot — otherwise the
        // overlay mascot would cover the badge (overlay sits above the route).
        BinyHero(
          size: mascotSize,
          expression: step.expression,
          foreground: _buildBadgeOverlay(step, mascotSize, isPhone),
        ),
        SizedBox(height: isPhone ? 16 : 24),
        // Title — 40px Baloo 2 ExtraBold #2b2a45 leading 1.1 letter-spacing -0.2
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isPhone ? 20 : 48),
          child: Text(
            step.title,
            style: GoogleFonts.baloo2(
              fontSize: isPhone ? 24 : 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: isPhone ? 8 : 14),
        // Subtitle — Figma: 18px Plus Jakarta Sans Medium #5c5980 leading 1.5
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isPhone ? 20 : 48),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isPhone ? size.width - 40 : 560),
            child: Text(
              step.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isPhone ? 14 : 18,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Foreground layer painted above the mascot by the flight overlay.
  /// Positioned relative to the mascot's rect (≈ mascotSize wide). Badge sits
  /// at the top-right corner, overlapping Biny's head — same look as the old
  /// local Stack but now in front of the mascot.
  Widget _buildBadgeOverlay(_OnboardingStep step, double mascotSize, bool isPhone) {
    final badgeSize = isPhone ? 44.0 : 66.0;
    final iconSize = isPhone ? 24.0 : 38.0;
    // Anchor the badge so roughly half of it overhangs the mascot's top-right
    // corner — matches the previous Positioned(right: 10, top: 30) feel.
    final right = isPhone ? -10.0 : -16.0;
    final top = isPhone ? 2.0 : 14.0;

    return SizedBox(
      width: mascotSize,
      height: mascotSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: right,
            top: top,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: step.badgeBg,
                borderRadius:
                    BorderRadius.circular(isPhone ? 14 : 20),
                border: Border.all(
                    color: AppColors.background, width: isPhone ? 3 : 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPress.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  step.badgeIconPath,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                      step.badgeIconColor, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(bool isPhone) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == _totalPages - 1;

    if (isFirst) {
      return Center(
        child:
            _buildPrimaryButton('Lanjut', _handleNext, isPhone, showChevron: true),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSecondaryButton('Kembali', _handleBack, isPhone),
        SizedBox(width: isPhone ? 12 : 16),
        _buildPrimaryButton(
          isLast ? 'Mulai sekarang' : 'Lanjut',
          _handleNext,
          isPhone,
          showChevron: !isLast,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(
    String label,
    VoidCallback onTap,
    bool isPhone, {
    required bool showChevron,
  }) {
    // bg #7c5cfc, padding 24/12, rounded-999, gap 8
    // text 19px Baloo 2 Bold white, letter-spacing 0.095,
    // shadow rgba(124,92,252,0.32) offset(0,10) blur-18 + #5b3fd6 offset(0,5) blur-0
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 20 : 24,
          vertical: isPhone ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              offset: Offset(0, isPhone ? 6 : 10),
              blurRadius: isPhone ? 12 : 18,
            ),
            BoxShadow(
              color: AppColors.primaryPress,
              offset: Offset(0, isPhone ? 3 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: isPhone ? 14 : 19,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.surface,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.surface),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onTap, bool isPhone) {
    // bg #ede8ff, padding 24/12, rounded-999, gap 8
    // text 19px Baloo 2 Bold #5b3fd6, letter-spacing 0.095, chevron-left 20×20,
    // drop-shadow #ddd3ff offset(0,5) blur-0
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 20 : 24,
          vertical: isPhone ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            const BoxShadow(
              color: Color(0xFFDDD3FF),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_left_rounded,
                size: 20, color: AppColors.primaryPress),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: isPhone ? 14 : 19,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.primaryPress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String subtitle;
  final String badgeIconPath;
  final Color badgeBg;
  final Color badgeIconColor;
  final BinyExpression expression;

  const _OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.badgeIconPath,
    required this.badgeBg,
    required this.badgeIconColor,
    required this.expression,
  });
}
