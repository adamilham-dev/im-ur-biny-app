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
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;

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

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _dotsAnimation = IntTween(begin: 0, end: 3).animate(_dotsController);

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
    _dotsController.dispose();
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

  Widget _buildTitle(Size size) {
    final style = GoogleFonts.baloo2(
      fontSize: AppResponsive.sp(size, 30).clamp(20.0, 30.0),
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bersiap memindai', style: style),
        SizedBox(
          width: 30, // Fixed width for up to 3 dots to prevent jumping
          child: AnimatedBuilder(
            animation: _dotsAnimation,
            builder: (context, child) {
              return Text('.' * _dotsAnimation.value, style: style);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownCircle(double ringDiameter) {
    final fontSize = ringDiameter * 0.51;
    final strokeWidth = ringDiameter * 0.05;

    return AnimatedBuilder(
      animation: Listenable.merge([_progressController, _scaleAnimation]),
      builder: (context, child) {
        final progress = 1.0 - _progressController.value;

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: ringDiameter * 1.8,
            height: ringDiameter * 1.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ringDiameter * 1.8,
                  height: ringDiameter * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3AD6A0).withValues(alpha: 0.25),
                        const Color(0xFF3AD6A0).withValues(alpha: 0.08),
                        const Color(0xFF3AD6A0).withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size(ringDiameter, ringDiameter),
                  painter: _CountdownRingPainter(
                    progress: progress,
                    trackColor: const Color(0xFF2D2D4D),
                    progressColor: const Color(0xFF00FF99),
                    strokeWidth: strokeWidth,
                  ),
                ),
                Text(
                  '$_count',
                  style: GoogleFonts.baloo2(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CountdownRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      const startAngle = -pi / 2;
      final sweepAngle = 2 * pi * progress;
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      // Outer glow layer
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, glowPaint);

      // Main progress arc
      final arcPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

      // Bright tip at the end
      final endAngle = startAngle + sweepAngle;
      final tipX = center.dx + radius * cos(endAngle);
      final tipY = center.dy + radius * sin(endAngle);

      final tipPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 2, tipPaint);
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress;
}
