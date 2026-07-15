import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// 11 · Feedback screen — pixel-perfect match to .
///
/// Design target: 1194×834 (iPad landscape).
/// Layout: Frame 31 (760×564.2) centered, column with 20px gap between items.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Initial state: everything empty. Fills in on tap.
  int _rating = 0;
  final _selectedChips = <String>{};

  // — chip icons. Akurat & Cepat use exact SVG paths
  // exported from Figma (the Material Icon equivalents didn't match: Akurat
  // is 3 concentric rings not a 2-ring Icons.adjust, and Cepat's bolt has a
  // specific path). Puas & Mudah still use Material Icons — close enough.
  // Color flips to primary when selected.
  //
  // Tuple: (label, svgAsset | null, materialIcon | null).
  static const _feedbackOptions = [
    ('Akurat', 'assets/icons/feedback_akurat.svg', null),
    ('Puas', null, Icons.sentiment_satisfied_outlined),
    ('Cepat', 'assets/icons/feedback_cepat.svg', null),
    ('Mudah', null, Icons.thumb_up_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);

    // Pixel-perfect at 1194×834 landscape. Scale proportionally elsewhere.
    final scale = isPortrait
        ? (size.width / 760.0).clamp(0.6, 1.0)
        : (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ──
          // Ellipse 440×440 at (360, -150) — top-right, partially off-screen
          // Ellipse 380×380 at (700, 540) — bottom-right, partially off-screen
          // Replicate Figma's blurred ellipse using MaskFilter.blur (matches result_screen).
          if (!isPortrait) ...[
            Positioned(
              left: 360 * scale,
              top: -150 * scale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(440 * scale, 440 * scale),
                  painter: _BlobPainter(
                    color: AppColors.primaryLight,
                    opacity: 0.30,
                    blurSigma: 110 * scale,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 700 * scale,
              top: 540 * scale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(380 * scale, 380 * scale),
                  painter: _BlobPainter(
                    color: const Color(0xFFC58CFF),
                    opacity: 0.28,
                    blurSigma: 100 * scale,
                  ),
                ),
              ),
            ),
          ],

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isPortrait ? AppResponsive.rs(size, 24) : 24 * scale,
                  vertical: AppResponsive.rs(size, 16),
                ),
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    );
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 760 * scale,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Biny mascot --- 124×130.2
                        BinyHero(
                          size: 130.2 * scale,
                          expression: BinyExpression.feedback,
                        ),

                        SizedBox(height: 20 * scale),

                        // --- Title ---
                        // Baloo 2 ExtraBold, 50px, height 1.04, color #2B2A45
                        // Manual line break: "Bagaimana" on line 1, "pengalaman kamu?" on line 2.
                        Text(
                          'Bagaimana\npengalaman kamu?',
                          style: GoogleFonts.baloo2(
                            fontSize: 50 * scale,
                            fontWeight: FontWeight.w800,
                            height: 1.04,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 20 * scale),

                        // --- Subtitle ---
                        // Plus Jakarta Sans Medium, 18px, height 1.5, color #5C5980
                        Text(
                          'Bantu kami jadi lebih baik',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 20 * scale),

                        // --- Stars --- 5× (52×52), 16px gap
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < 5; i++) ...[
                              if (i > 0) SizedBox(width: 16 * scale),
                              _buildStar(i + 1, 52 * scale),
                            ],
                          ],
                        ),

                        SizedBox(height: 20 * scale),

                        // --- Chips --- originally Row with 14px
                        // gap, but on narrow phones (360-414px) 4 chips side-by-side
                        // overflow the available width. Wrap lets them flow onto a
                        // second line on phones while still rendering inline on tablets.
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14 * scale,
                          runSpacing: 10 * scale,
                          children: _feedbackOptions.asMap().entries.map((e) {
                            final option = e.value;
                            final isSelected =
                                _selectedChips.contains(option.$1);
                            return _buildChip(
                              label: option.$1,
                              svgAsset: option.$2,
                              icon: option.$3,
                              isSelected: isSelected,
                              scale: scale,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedChips.remove(option.$1);
                                  } else {
                                    _selectedChips.add(option.$1);
                                  }
                                });
                              },
                              extraLeftPadding:
                                  option.$1 == 'Mudah' ? 2 * scale : 0.0,
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 20 * scale),

                        // --- Submit button frame --- Frame 19 (760×96)
                        // Button at y=16 within frame → 16 top pad + 64 button + 16 bottom pad.
                        SizedBox(
                          height: 96 * scale,
                          child: Center(
                            child: _buildSubmitButton(scale: scale),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STAR
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStar(int starIndex, double size) {
    final isActive = starIndex <= _rating;
    return GestureDetector(
      onTap: () => setState(() => _rating = starIndex),
      behavior: HitTestBehavior.opaque,
      child: Icon(
        isActive ? Icons.star_rounded : Icons.star_outline_rounded,
        // Outline matches star fill color (Figma: orange #FFB02E on both states).
        color: AppColors.warning,
        size: size,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // CHIP
  // padding 22h/13v, icon 22px (24px for thumbs-up), gap 10px, text Baloo 2 Bold 18px
  // Selected: bg #EDE8FF, border 2px #7C5CFC, icon+text #7C5CFC (primary)
  // Unselected: bg white, border 2px #ECE9F7, text #2B2A45 (textPrimary),
  // icon #5C5980 (textSecondary — Figma renders unselected chip
  //             icons as a neutral gray image asset, distinct from the dark
  //             navy text. Using textPrimary for both made icons look darker
  // than the Figma reference.)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildChip({
    required String label,
    required String? svgAsset,
    required IconData? icon,
    required bool isSelected,
    required double scale,
    required VoidCallback onTap,
    double extraLeftPadding = 0.0,
  }) {
    final iconColor =
        isSelected ? AppColors.primary : AppColors.textSecondary;
    final textColor =
        isSelected ? AppColors.primary : AppColors.textPrimary;

    // Render either the exact Figma SVG asset or a Material Icon fallback.
    Widget iconWidget;
    if (svgAsset != null) {
      iconWidget = SvgPicture.asset(
        svgAsset,
        width: 22 * scale,
        height: 22 * scale,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      iconWidget = Icon(icon, size: 22 * scale, color: iconColor);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 22 * scale,
          vertical: 13 * scale,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: extraLeftPadding),
              child: iconWidget,
            ),
            SizedBox(width: 10 * scale),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 18 * scale,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUBMIT BUTTON
  // 316×64, bg #7C5CFC, padding 32h/20v, gap 12px
  // Send icon 24px white + "Kirim Feedback" Baloo 2 Bold 19px
  // Shadow: 0 12 22 rgba(124,92,252,0.35), 0 6 0 #5B3FD6 (3D press effect)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSubmitButton({required double scale}) {
    return Container(
      width: 316 * scale,
      height: 64 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            offset: Offset(0, 12 * scale),
            blurRadius: 22 * scale,
          ),
          BoxShadow(
            color: AppColors.primaryPress,
            offset: Offset(0, 6 * scale),
            blurRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => context.go('/thank-you'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: 32 * scale,
            vertical: 20 * scale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // — exact paper-plane SVG exported from Figma.
            // The icon is already tilted up-right in the source path, so no
            // Transform.rotate needed. Fill is white (textOnPrimary).
            SvgPicture.asset(
              'assets/icons/feedback_send.svg',
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: ColorFilter.mode(
                AppColors.textOnPrimary,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 12 * scale),
            Text(
              'Kirim Feedback',
              style: GoogleFonts.baloo2(
                fontSize: 19 * scale,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a blurred solid-color ellipse — replicates Figma's SOLID fill +
/// LAYER_BLUR effect. Same pattern as result_screen.dart's _BlobPainter.
class _BlobPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double blurSigma;

  const _BlobPainter({
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
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.blurSigma != blurSigma;
}
