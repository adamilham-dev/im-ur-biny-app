import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen>
    with TickerProviderStateMixin {
  static const int _totalSeconds = 3;
  int _count = _totalSeconds;
  Timer? _timer;

  late AnimationController _progressController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    )..forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _scaleController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _count--);

      if (_count <= 0) {
        timer.cancel();
        context.go('/scanning');
        return;
      }

      _scaleController.reset();
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPhone = AppResponsive.isPhone(size);
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);

    // Figma 226:1196/1197: ring Ø332 in 834px-tall frame
    final ringDiameter = (isPortrait
            ? size.shortestSide * 0.55
            : size.shortestSide * 0.40)
        .clamp(180.0, 360.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background — Figma 226:1193: GRADIENT_LINEAR #211E36 → #13111F ──
          // gradientTransform [[0,1,0],[-1,0,1]] = top→bottom vertical
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF211E36),
                  Color(0xFF13111F),
                ],
              ),
            ),
          ),

          // ── Radial purple bloom ──
          // In Figma, the two glow ellipses + linear gradient composite into a
          // visibly purple center fading to dark edges (perceived radial
          // gradient: center ~#2d1b69, corners ~#1a1a2e). On-device, the 0.18-
          // opacity blurred ellipses alone render too subtly, so this overlay
          // reproduces that perceived gradient directly.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.75,
                colors: [
                  const Color(0xFF4A2F8A).withValues(alpha: 0.55),
                  const Color(0xFF2D1B69).withValues(alpha: 0.30),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Content column ──
          // Figma vertical layout (in 834px frame):
          //   subtitle @ y=148 (center 168, ~20%)
          //   ring     @ y=251 center 417 (50%)
          //   pill     @ y=609 center 634 (76%)
          //   Spacer flex ratios from pixel gaps: top 5 / gap1 2 / gap2 1 / bottom 7
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              const Spacer(flex: 5),
              _buildTitle(size),
              const Spacer(flex: 2),
              _buildCountdownCircle(ringDiameter),
              const Spacer(flex: 1),
              _buildHintPill(size),
              const Spacer(flex: 7),
            ],
          ),

          // ── Biny mascot — Figma 226:1207: (982,640) 152×160 in 1194×834 ──
          // Right margin 60px, bottom margin 34px
          Positioned(
            bottom: isPhone ? 14 : 35,
            right: isPhone ? 16 : 60,
            child: IgnorePointer(
              child: BinyHero(
                size: isPhone ? 110.0 : 160.0,
                expression: BinyExpression.countdown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Bersiap memindai…" — Figma 226:1199: 30px Baloo 2 SemiBold white
  Widget _buildTitle(Size size) {
    return Text(
      'Bersiap memindai…',
      style: GoogleFonts.baloo2(
        fontSize: AppResponsive.sp(size, 30).clamp(20.0, 30.0),
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Countdown ring + glows + number.
  ///
  /// Glows are inside this Stack (clipBehavior: none) so they align perfectly
  /// with the ring and can overflow into title/pill areas — matching Figma's
  /// layout where glow-purple (700×560) is wider than the ring (332).
  Widget _buildCountdownCircle(double ringDiameter) {
    // Figma 226:1198: 170px in Ø332 ring → ratio 0.512
    final fontSize = ringDiameter * 0.51;
    // Figma arc innerRadius 0.916 → stroke = Ø × (1−0.916)/2 ≈ Ø × 0.042
    final strokeWidth = ringDiameter * 0.042;

    // Glow dimensions relative to ring Ø (Figma values / Ø332)
    // glow-purple: 700×560, blur 90, centered 77px above ring center
    final purpleGlowW = ringDiameter * (700.0 / 332); // 2.108
    final purpleGlowH = ringDiameter * (560.0 / 332); // 1.687
    final purpleGlowBlur = ringDiameter * (90.0 / 332); // 0.271
    final purpleGlowOffsetY = ringDiameter * (-77.0 / 332); // -0.232
    // glow-ring (mint): 300×300, blur 30, centered on ring
    final mintGlowSize = ringDiameter * (300.0 / 332); // 0.904
    final mintGlowBlur = ringDiameter * (30.0 / 332); // 0.0904

    return SizedBox(
      width: ringDiameter,
      height: ringDiameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Purple glow — Figma 226:1194 ──
          // 700×560 ellipse, #7C5CFC @ opacity 0.18, LAYER_BLUR radius 90
          Transform.translate(
            offset: Offset(0, purpleGlowOffsetY),
            child: CustomPaint(
              size: Size(purpleGlowW, purpleGlowH),
              painter: _BlurGlowPainter(
                color: const Color(0xFF7C5CFC),
                opacity: 0.18,
                blurSigma: purpleGlowBlur,
              ),
            ),
          ),

          // ── Mint glow — Figma 226:1195 ──
          // 300×300 ellipse, #3AD6A0 @ opacity 0.18, LAYER_BLUR radius 30
          CustomPaint(
            size: Size(mintGlowSize, mintGlowSize),
            painter: _BlurGlowPainter(
              color: const Color(0xFF3AD6A0),
              opacity: 0.18,
              blurSigma: mintGlowBlur,
            ),
          ),

          // ── Ring + number (animated) ──
          AnimatedBuilder(
            animation: Listenable.merge([_progressController, _scaleAnimation]),
            builder: (context, child) {
              final progress = 1.0 - _progressController.value;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ring (track + progress arc)
                  CustomPaint(
                    size: Size(ringDiameter, ringDiameter),
                    painter: _CountdownRingPainter(
                      progress: progress,
                      strokeWidth: strokeWidth,
                    ),
                  ),
                  // Number — bounces on each tick
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Text(
                      '$_count',
                      style: GoogleFonts.baloo2(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Hint pill — Figma 226:1200: bg #0E0B1A @ 0.66, border white @ 0.08 1px,
  /// rounded-999, px=26 py=14 gap=11, ic-hand 22×22 (orange #FFB02E),
  /// text 19px Baloo 2 Bold ls 0.5%
  Widget _buildHintPill(Size size) {
    final iconSize = AppResponsive.iconSize(size, 22).clamp(16.0, 22.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.rs(size, 26).clamp(16.0, 26.0),
        vertical: AppResponsive.rs(size, 14).clamp(10.0, 14.0),
      ),
      decoration: BoxDecoration(
        color: const Color(0xA80E0B1A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Figma 226:1201: ic-hand — orange hand icon (vector stroke #FFB02E)
          Image.asset(
            'assets/images/page_6/ic-hand.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
          SizedBox(width: AppResponsive.rs(size, 11).clamp(6.0, 11.0)),
          Text(
            'Tarik tanganmu keluar dari papan',
            style: GoogleFonts.baloo2(
              fontSize: AppResponsive.sp(size, 19).clamp(13.0, 19.0),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.095,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a blurred ellipse glow — matches Figma's SOLID fill + LAYER_BLUR.
///
/// Figma uses solid-color ellipses with a gaussian layer blur. This painter
/// draws a filled ellipse with [MaskFilter.blur] to replicate that exactly,
/// producing a brighter, more saturated glow than a RadialGradient would.
class _BlurGlowPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double blurSigma;

  const _BlurGlowPainter({
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
  bool shouldRepaint(_BlurGlowPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.blurSigma != blurSigma;
}

/// Draws the countdown ring: a faint white track circle + a mint progress arc
/// with a glow effect.
///
/// Figma 226:1196 (track): white @ 0.08 opacity.
/// Figma 226:1197 (progress): #3AD6A0 arc, innerRadius 0.916,
///   drop-shadow #3AD6A0 @ 0.5 alpha, blur 12, offset 0.
class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  const _CountdownRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // Track — Figma 226:1196: white @ 0.08
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      const startAngle = -pi / 2;
      final sweepAngle = 2 * pi * progress;
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      // Glow — Figma effect: #3AD6A0 @ 0.5 alpha, blur 12, offset 0
      final glowPaint = Paint()
        ..color = const Color(0xFF3AD6A0).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, glowPaint);

      // Main progress arc — Figma 226:1197: #3AD6A0
      final arcPaint = Paint()
        ..color = const Color(0xFF3AD6A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

      // Bright tip at the leading edge
      final endAngle = startAngle + sweepAngle;
      final tipX = center.dx + radius * cos(endAngle);
      final tipY = center.dy + radius * sin(endAngle);

      final tipPaint = Paint()
        ..color = const Color(0xFF3AD6A0).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 2, tipPaint);
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}
