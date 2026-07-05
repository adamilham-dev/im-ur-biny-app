import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/models/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';
import '../../../core/providers/bluetooth_provider.dart';

/// 12 · Thank You — pixel-perfect match to Figma 226:1947.
///
/// Design target: 1194×834 (iPad landscape).
/// Layout: Frame 256:1302 (540 wide, 16px gap) centered vertically.
class ThankYouScreen extends ConsumerStatefulWidget {
  const ThankYouScreen({super.key});

  @override
  ConsumerState<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends ConsumerState<ThankYouScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _celebrateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _bounceAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _celebrateController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    final session = ref.watch(sessionProvider);

    // Pixel-perfect at 1194×834 landscape. Scale proportionally elsewhere.
    final scale = isPortrait
        ? (size.width / 430.0).clamp(0.4, 1.0)
        : (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs — Figma 226:1948, 226:1949 ──
          // 226:1948: 460×460 at (380, -160) — top right area
          // 226:1949: 420×420 at (660, 540) — bottom right
          if (!isPortrait) ...[
            Positioned(
              left: 380 * scale,
              top: -160 * scale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(460 * scale, 460 * scale),
                  painter: _BlobPainter(
                    color: AppColors.primaryLight,
                    opacity: 0.30,
                    blurSigma: 115 * scale,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 660 * scale,
              top: 540 * scale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(420 * scale, 420 * scale),
                  painter: _BlobPainter(
                    color: const Color(0xFFC58CFF),
                    opacity: 0.28,
                    blurSigma: 110 * scale,
                  ),
                ),
              ),
            ),

            // ── Confetti rectangles — Figma 226:1950-1954 ──
            _confetti(
              left: 320 * scale,
              top: 140 * scale,
              size: 11 * scale,
              radius: 2,
              color: const Color(0xFF3AD6A0).withValues(alpha: 0.6),
            ),
            _confetti(
              left: 860 * scale,
              top: 170 * scale,
              size: 9 * scale,
              radius: 2,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            _confetti(
              left: 920 * scale,
              top: 120 * scale,
              size: 8 * scale,
              radius: 4,
              color: const Color(0xFFFFB02E).withValues(alpha: 0.6),
            ),
            _confetti(
              left: 320 * scale,
              top: 650 * scale,
              size: 10 * scale,
              radius: 2,
              color: const Color(0xFFFF6B8A).withValues(alpha: 0.6),
            ),
            _confetti(
              left: 880 * scale,
              top: 640 * scale,
              size: 10 * scale,
              radius: 2,
              color: const Color(0xFF4DA3FF).withValues(alpha: 0.6),
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
                      maxWidth: 540 * scale,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Biny mascot with bounce ---
                        // Figma 226:1955: 132×138.6
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _bounceAnimation.value),
                              child: child,
                            );
                          },
                          child: BinyHero(
                            size: 138.6 * scale,
                            expression: BinyExpression.thankyou,
                          ),
                        ),

                        SizedBox(height: 16 * scale),

                        // --- "SESI SELESAI" label --- Figma 226:1986
                        // Plus Jakarta Sans ExtraBold, 13px, color #3AD6A0,
                        // tracking 1.6px. No background, no icon.
                        Text(
                          'SESI SELESAI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 16 * scale),

                        // --- Title --- Figma 226:1987
                        // Baloo 2 ExtraBold, 50px, height 1.04, color #2B2A45
                        // Manual line break: "Terima kasih" / "sudah memilah!"
                        Text(
                          'Terima kasih\nsudah memilah!',
                          style: GoogleFonts.baloo2(
                            fontSize: 50 * scale,
                            fontWeight: FontWeight.w800,
                            height: 1.04,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 16 * scale),

                        // --- Subtitle --- Figma 226:1988
                        // Plus Jakarta Sans Medium, 18px, height 1.5, color #5C5980
                        Text(
                          'Pilahan kecilmu hari ini bikin bumi lebih sehat. '
                          'Sampai jumpa lagi, ya!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 16 * scale),

                        // --- Recap card --- Figma 2006:1889
                        // White bg, rounded 24, shadow 0 18 44 rgba(41,31,89,0.12)
                        // 3 cells, dividers #ECE9F7 1px, padding 40h/22v per cell
                        _buildRecapCard(scale, session),

                        SizedBox(height: 16 * scale),

                        // --- Buttons or Loading --- Figma 336:1566
                        // Row with 12px gap, each button flex:1 (equal width)
                        if (_isLoading)
                          _buildLoading(scale)
                        else
                          _buildButtons(scale),
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
  // CONFETTI — Figma 226:1950-1954
  // Tiny rounded squares with translucent fills.
  // ─────────────────────────────────────────────────────────────────────
  Widget _confetti({
    required double left,
    required double top,
    required double size,
    required double radius,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RECAP CARD — Figma 2006:1889
  // White surface, radius 24, shadow 0 18 44 rgba(41,31,89,0.12).
  // 3 cells with 40h/22v padding, separated by 1px #ECE9F7 dividers.
  // Value: Baloo 2 ExtraBold 34px. Label: Plus Jakarta Sans Bold 14px #908DAC.
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRecapCard(double scale, UserSession session) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.12),
            offset: Offset(0, 18 * scale),
            blurRadius: 44 * scale,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _recapCell(
              value: '${session.scanCount}',
              label: 'Item dipilah',
              valueColor: AppColors.textPrimary,
              scale: scale,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            _recapCell(
              value: '+${session.totalXP}',
              label: 'XP didapat',
              valueColor: const Color(0xFF9A6A00),
              scale: scale,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            _recapCell(
              value: '${session.uniqueCategoryCount}',
              label: 'Jenis sampah',
              valueColor: AppColors.textPrimary,
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recapCell({
    required String value,
    required String label,
    required Color valueColor,
    required double scale,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 40 * scale,
        vertical: 22 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.baloo2(
              fontSize: 34 * scale,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: valueColor,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
              height: 1.4,
              letterSpacing: 0.028,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS — Figma 336:1566
  // Row, 12px gap, each button flex:1 (full width).
  // LEFT (Pilah Lagi): bg #EDE8FF, text #5B3FD6, drop shadow 0 6 0 #DDD3FF
  // RIGHT (Selesai): bg #7C5CFC, text white, shadow 0 12 22 rgba(124,92,252,0.35) + 0 6 0 #5B3FD6
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtons(double scale) {
    return Row(
      children: [
        // --- Pilah Lagi (soft) ---
        Expanded(
          child: _SoftButton(
            label: 'Pilah Lagi',
            scale: scale,
            onPressed: () {
              // Reset scan state, keep the user's chosen mode + category,
              // and jump back to the mode select screen.
              ref.read(scanProvider.notifier).clearResult();
              ref.read(capturedImageProvider.notifier).state = null;
              context.go('/mode-select');
            },
          ),
        ),
        SizedBox(width: 12 * scale),
        // --- Selesai (primary) ---
        Expanded(
          child: _PrimaryButton(
            label: 'Selesai',
            scale: scale,
            onPressed: () => _onSelesaiPressed(),
          ),
        ),
      ],
    );
  }

  void _onSelesaiPressed() {
    setState(() => _isLoading = true);
    ref.read(bluetoothProvider.notifier).sendCloseAll();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ref.read(sessionProvider.notifier).resetSession();
        context.go('/');
      }
    });
  }

  Widget _buildLoading(double scale) {
    // Figma: spinner on LEFT of text — horizontal layout, both centered as a group.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20 * scale,
          height: 20 * scale,
          child: CircularProgressIndicator(
            strokeWidth: 2.5 * scale,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(width: 12 * scale),
        Text(
          'Kembali ke layar awal otomatis...',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PILAH LAGI — soft variant. Figma 336:1567
// bg #EDE8FF, text #5B3FD6, drop shadow 0 6 0 #DDD3FF (3D press effect)
// padding 32h/20v, radius 999, Baloo 2 Bold 19px ls 0.095
// ─────────────────────────────────────────────────────────────────────
class _SoftButton extends StatelessWidget {
  final String label;
  final double scale;
  final VoidCallback onPressed;

  const _SoftButton({
    required this.label,
    required this.scale,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDDD3FF),
            offset: Offset(0, 6 * scale),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 32 * scale,
              vertical: 20 * scale,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 19 * scale,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.primaryPress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SELESAI — primary variant. Figma 336:1568
// bg #7C5CFC, text white, shadow 0 12 22 rgba(124,92,252,0.35) + 0 6 0 #5B3FD6
// padding 32h/20v, radius 999, Baloo 2 Bold 19px ls 0.095
// ─────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final double scale;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.scale,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 32 * scale,
              vertical: 20 * scale,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 19 * scale,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.095,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
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
