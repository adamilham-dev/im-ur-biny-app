import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/biny_flight_controller.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  /// True while THIS screen holds a hide() on the global mascot overlay.
  /// While the keyboard is open the layout squeezes and the mascot slot
  /// collapses — hiding the overlay explicitly guarantees Biny never
  /// floats over the name field / button while the user types.
  bool _binyHiddenForKeyboard = false;

  void _syncBinyHiddenForKeyboard() {
    if (!mounted) return;
    final wantHidden = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (wantHidden == _binyHiddenForKeyboard) return;
    _binyHiddenForKeyboard = wantHidden;
    wantHidden
        ? BinyFlightController.instance.hide()
        : BinyFlightController.instance.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Post-frame: hide()/show() notify the overlay synchronously, which is
    // not allowed while the tree is mid-build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncBinyHiddenForKeyboard());
  }

  @override
  void dispose() {
    // Balance the hide() if the user leaves while the keyboard is open —
    // otherwise the mascot would stay hidden on every later screen.
    if (_binyHiddenForKeyboard) BinyFlightController.instance.show();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background decorative blobs ──
          if (isPortrait) ...[
            // Mint — top-right
            Positioned(
              right: -size.width * 0.15,
              top: -size.width * 0.2,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
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
              bottom: -size.width * 0.12,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
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
            // Blue — center
            Positioned(
              left: size.width * 0.25,
              top: size.height * 0.35,
              child: IgnorePointer(
                child: Container(
                  width: size.width * 0.4,
                  height: size.width * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.blobBlue.withValues(alpha: 0.6),
                        AppColors.blobBlue.withValues(alpha: 0.25),
                        AppColors.blobBlue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // ── Landscape — Figma-exact proportions ──
            // Mint — top-right
            Positioned(
              right: size.width * -0.092,
              top: size.height * -0.18,
              child: IgnorePointer(
                child: Container(
                  width: size.shortestSide * 0.528,
                  height: size.shortestSide * 0.528,
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
              left: size.width * -0.092,
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
            // Blue — center
            Positioned(
              left: size.width * 0.46,
              top: size.height * 0.40,
              child: IgnorePointer(
                child: Container(
                  width: size.shortestSide * 0.36,
                  height: size.shortestSide * 0.36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.blobBlue.withValues(alpha: 0.6),
                        AppColors.blobBlue.withValues(alpha: 0.25),
                        AppColors.blobBlue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          // ── Content ──
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 20 : 32,
                vertical: isPhone ? 16 : 40,
              ),
              child: isPhone && isPortrait
                  ? _buildPhoneLayout(size, keyboardOpen)
                  : _buildTabletLayout(size, isPhone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(Size size, bool isPhone) {
    final mascotSize = isPhone ? 200.0 : 320.0;
    final formWidth = isPhone ? size.width * 0.4 : 384.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMascotSection(mascotSize),
        SizedBox(width: isPhone ? 24 : 80),
        SizedBox(width: formWidth, child: _buildFormSection(size, isMobile: false)),
      ],
    );
  }

  Widget _buildPhoneLayout(Size size, bool keyboardOpen) {
    final formWidth = (size.width - 40).clamp(200.0, 384.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // BinyHero (spot for the global flight overlay) is rendered inline so
        // the global mascot can fly into it from the previous screen. While the
        // keyboard is open we collapse the slot so the flying mascot doesn't
        // overlap the name field once the layout is pushed up. AnimatedSize
        // collapses the space smoothly instead of an abrupt jump. Biny returns
        // when the keyboard closes.
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: keyboardOpen
              ? const SizedBox(width: double.infinity)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMascotSection(120),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
        SizedBox(width: formWidth, child: _buildFormSection(size, isMobile: true)),
      ],
    );
  }

  Widget _buildMascotSection(double mascotSize) {
    final double scale = mascotSize / 332.0;
    final double bubbleLeftMargin = 90.0 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: bubbleLeftMargin),
          child: Container(
            padding: EdgeInsets.only(
              left: 12 * scale + 4,
              top: 8,
              right: 12 * scale + 4,
              bottom: 14,
            ),
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shape: SpeechBubbleShape(
                cornerRadius: 14.0 * scale + 4,
                tailWidth: 12.0 * scale,
                tailHeight: 8.0 * scale,
                tailOffsetFromLeft: 16.0 * scale,
              ),
              shadows: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.baloo2(
                  fontSize: 14.0 * scale + 4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                children: [
                  const TextSpan(text: 'Hai, aku '),
                  TextSpan(
                    text: 'Biny',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: '!'),
                ],
              ),
            ),
          ),
        ),
        // BinyHero is an invisible slot that reserves the mascot's space and
        // reports its on-screen rect to the global flight overlay, which
        // renders the single shared Biny that flies between screens.
        BinyHero(
          size: mascotSize,
          expression: BinyExpression.welcome,
        ),
      ],
    );
  }

  Widget _buildFormSection(Size size, {required bool isMobile}) {
    final isPhone = AppResponsive.isPhone(size) && isMobile;

    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isMobile ? Alignment.center : Alignment.centerLeft,
          child: Text(
            'Selamat Datang!',
            style: GoogleFonts.baloo2(
              fontSize: isPhone ? 24 : 52,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          'Kenalan dulu, yuk — siapa namamu?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isPhone ? 13 : 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        SizedBox(height: isPhone ? 16 : 26),
        TextFormField(
          controller: _nameController,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isPhone ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Ketik nama kamu di sini...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: isPhone ? 13 : 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 24,
              vertical: isPhone ? 14 : 22,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isPhone ? 14 : 18),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isPhone ? 14 : 18),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        SizedBox(height: isPhone ? 16 : 26),
        // Mulai Sesi button
        SizedBox(
          width: double.infinity,
          height: isPhone ? 52 : 64,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isPhone ? 30 : 40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  offset: Offset(0, isPhone ? 6 : 12),
                  blurRadius: isPhone ? 12 : 22,
                ),
                BoxShadow(
                  color: const Color(0xFF5B3FD6),
                  offset: Offset(0, isPhone ? 3 : 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Eh, kenalan dulu yuk! Namamu belum diisi.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.surface,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: AppColors.textPrimary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  return;
                }
                final name = _nameController.text.trim();
                ref.read(sessionProvider.notifier).setName(name);
                context.go('/onboarding');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isPhone ? 30 : 40),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/page_2/Play-List-4 Streamline Flex.svg',
                    width: isPhone ? 20 : 24,
                    height: isPhone ? 20 : 24,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  SizedBox(width: isPhone ? 10 : 12),
                  Text(
                    'Mulai Sesi',
                    style: GoogleFonts.baloo2(
                      fontSize: isPhone ? 16 : 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isPhone ? 16 : 26),
        _buildFeatureItem(
          size: size,
          iconPath: 'assets/images/page_2/Recycle-1 Streamline Flex.svg',
          title: 'Ramah lingkungan',
          desc: ' — tiap pilah bantu jaga bumi.',
          isPhone: isPhone,
        ),
        SizedBox(height: isPhone ? 10 : 16),
        _buildFeatureItem(
          size: size,
          iconPath: 'assets/images/page_2/Star-Circle Streamline Flex.svg',
          title: 'Dapatkan XP',
          desc: ' — kumpulkan poin tiap sesi pilah.',
          isPhone: isPhone,
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required Size size,
    required String iconPath,
    required String title,
    required String desc,
    required bool isPhone,
  }) {
    final iconBoxSize = isPhone ? 32.0 : 42.0;
    final iconSize = isPhone ? 18.0 : 24.0;
    final fontSize = isPhone ? 12.0 : 15.0;
    final titleFontSize = isPhone ? 13.0 : 15.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(isPhone ? 10 : 12),
          ),
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              colorFilter: const ColorFilter.mode(
                  AppColors.primary, BlendMode.srcIn),
            ),
          ),
        ),
        SizedBox(width: isPhone ? 10 : 16),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SpeechBubbleShape extends ShapeBorder {
  final double cornerRadius;
  final double tailWidth;
  final double tailHeight;
  final double tailOffsetFromLeft;

  const SpeechBubbleShape({
    this.cornerRadius = 20.0,
    this.tailWidth = 22.0,
    this.tailHeight = 13.0,
    this.tailOffsetFromLeft = 25.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = cornerRadius;
    final tw = tailWidth;
    final th = tailHeight;

    final bodyRect =
        Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - th);

    final path = Path();

    path.moveTo(bodyRect.left + r, bodyRect.top);
    path.lineTo(bodyRect.right - r, bodyRect.top);
    path.arcToPoint(Offset(bodyRect.right, bodyRect.top + r),
        radius: Radius.circular(r));

    path.lineTo(bodyRect.right, bodyRect.bottom - r);
    path.arcToPoint(Offset(bodyRect.right - r, bodyRect.bottom),
        radius: Radius.circular(r));

    final tailLeftX = bodyRect.left + tailOffsetFromLeft;
    final tailRightX = tailLeftX + tw;
    final tailCenterX = tailLeftX + (tw / 2);

    path.lineTo(tailRightX, bodyRect.bottom);
    path.lineTo(tailCenterX, bodyRect.bottom + th);
    path.lineTo(tailLeftX, bodyRect.bottom);

    path.lineTo(bodyRect.left + r, bodyRect.bottom);
    path.arcToPoint(Offset(bodyRect.left, bodyRect.bottom - r),
        radius: Radius.circular(r));
    path.lineTo(bodyRect.left, bodyRect.top + r);
    path.arcToPoint(Offset(bodyRect.left + r, bodyRect.top),
        radius: Radius.circular(r));
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = AppColors.primarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
