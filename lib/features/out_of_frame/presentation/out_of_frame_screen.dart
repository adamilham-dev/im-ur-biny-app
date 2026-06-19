import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';

class OutOfFrameScreen extends StatelessWidget {
  const OutOfFrameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);

    if (isPortrait) {
      return _buildPortrait(context, size);
    }
    return _buildLandscape(context, size);
  }

  Widget _buildPortrait(BuildContext context, Size size) {
    final titleFontSize = AppResponsive.sp(size, 28);
    final bodyFontSize = AppResponsive.sp(size, 16);
    final smallFontSize = AppResponsive.sp(size, 13);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Camera preview (fixed height)
          SizedBox(
            height: AppResponsive.rs(size, 180),
            child: Container(
              width: double.infinity,
              color: AppColors.cameraBg,
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.videocam,
                      size: AppResponsive.sp(size, 48),
                      color: Colors.white24,
                    ),
                  ),
                  Center(
                    child: CustomPaint(
                      size: const Size(200, 160),
                      painter: _DashedBorderPainter(
                        color: AppColors.warning,
                        strokeWidth: 3,
                        dashWidth: 10,
                        dashGap: 6,
                        radius: 10,
                      ),
                    ),
                  ),
                  // Top label
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: AppResponsive.paddingAll(size, 12),
                        child: Center(
                          child: Container(
                            padding: AppResponsive.paddingSymmetric(size, h: 12, v: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 16),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 6)),
                                Text(
                                  'Sampah di luar area deteksi',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.warning,
                                    fontSize: smallFontSize,
                                    fontWeight: FontWeight.w600,
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
            ),
          ),

          // Info panel (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: AppResponsive.paddingSymmetric(size, h: 24, v: 20),
              child: Column(
                children: [
                  // Warning icon
                  Container(
                    width: AppResponsive.rs(size, 56),
                    height: AppResponsive.rs(size, 56),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 32),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 16)),

                  Text(
                    'Sampah di Luar Frame',
                    style: GoogleFonts.baloo2(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 8)),

                  Text(
                    'Geser atau pindahkan sampah ke dalam area papan yang ditandai.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 20)),

                  // Visual guide: correct vs incorrect
                  Container(
                    padding: AppResponsive.paddingSymmetric(size, h: 16, v: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppResponsive.radius(size, 20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Incorrect
                        Column(
                          children: [
                            Container(
                              width: AppResponsive.rs(size, 100),
                              height: AppResponsive.rs(size, 75),
                              decoration: BoxDecoration(
                                color: AppColors.cameraBg,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 12)),
                                border: Border.all(
                                  color: AppColors.red.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: CustomPaint(
                                      size: Size(AppResponsive.rs(size, 70), AppResponsive.rs(size, 45)),
                                      painter: _DashedBorderPainter(
                                        color: AppColors.warning,
                                        strokeWidth: 2,
                                        dashWidth: 6,
                                        dashGap: 4,
                                        radius: 8,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Icon(
                                      Icons.close,
                                      color: AppColors.red,
                                      size: AppResponsive.sp(size, 22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppResponsive.rs(size, 6)),
                            Text(
                              'Salah',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: smallFontSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: AppResponsive.rs(size, 12)),
                        Icon(
                          Icons.arrow_forward,
                          color: AppColors.textMuted,
                          size: AppResponsive.sp(size, 22),
                        ),
                        SizedBox(width: AppResponsive.rs(size, 12)),
                        // Correct
                        Column(
                          children: [
                            Container(
                              width: AppResponsive.rs(size, 100),
                              height: AppResponsive.rs(size, 75),
                              decoration: BoxDecoration(
                                color: AppColors.cameraBg,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 12)),
                                border: Border.all(
                                  color: AppColors.green.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Container(
                                      width: AppResponsive.rs(size, 50),
                                      height: AppResponsive.rs(size, 41),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.green,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 6)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppColors.green,
                                      size: AppResponsive.sp(size, 22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppResponsive.rs(size, 6)),
                            Text(
                              'Benar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: smallFontSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/camera-guide'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              padding: EdgeInsets.symmetric(vertical: AppResponsive.rs(size, 14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 16)),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Coba Lagi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.rs(size, 8)),
                        TextButton(
                          onPressed: () => context.go('/continue-session'),
                          child: Text(
                            'Lewati',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscape(BuildContext context, Size size) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: Camera preview with warning
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.cameraBg,
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.videocam,
                      size: AppResponsive.sp(size, 64),
                      color: Colors.white24,
                    ),
                  ),
                  Center(
                    child: CustomPaint(
                      size: const Size(300, 350),
                      painter: _DashedBorderPainter(
                        color: AppColors.warning,
                        strokeWidth: 3,
                        dashWidth: 12,
                        dashGap: 8,
                        radius: 12,
                      ),
                    ),
                  ),
                  ..._buildArrows(size),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: AppResponsive.paddingAll(size, 16),
                        child: Center(
                          child: Container(
                            padding: AppResponsive.paddingSymmetric(size, h: 16, v: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 18),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 8)),
                                Text(
                                  'Sampah di luar area deteksi',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.warning,
                                    fontSize: AppResponsive.sp(size, 13),
                                    fontWeight: FontWeight.w600,
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
            ),
          ),

          // Right: Info panel
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.background,
              padding: AppResponsive.paddingSymmetric(size, h: 48, v: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: AppResponsive.rs(size, 72),
                    height: AppResponsive.rs(size, 72),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 40),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  Text(
                    'Sampah di Luar Frame',
                    style: GoogleFonts.baloo2(
                      fontSize: AppResponsive.sp(size, 28),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 12)),

                  SizedBox(
                    width: 380,
                    child: Text(
                      'Geser atau pindahkan sampah ke dalam area papan yang ditandai.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 28)),

                  Container(
                    padding: AppResponsive.paddingAll(size, 20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppResponsive.radius(size, 20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: AppResponsive.rs(size, 120),
                              height: AppResponsive.rs(size, 90),
                              decoration: BoxDecoration(
                                color: AppColors.cameraBg,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 12)),
                                border: Border.all(
                                  color: AppColors.red.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(100, 70),
                                    painter: _DashedBorderPainter(
                                      color: AppColors.warning,
                                      strokeWidth: 2,
                                      dashWidth: 6,
                                      dashGap: 4,
                                      radius: 8,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Icon(
                                      Icons.close,
                                      color: AppColors.red,
                                      size: AppResponsive.sp(size, 28),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppResponsive.rs(size, 8)),
                            Text(
                              'Salah',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: AppResponsive.sp(size, 13),
                                fontWeight: FontWeight.w600,
                                color: AppColors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: AppResponsive.rs(size, 24)),
                        Icon(
                          Icons.arrow_forward,
                          color: AppColors.textMuted,
                          size: AppResponsive.sp(size, 28),
                        ),
                        SizedBox(width: AppResponsive.rs(size, 24)),
                        Column(
                          children: [
                            Container(
                              width: AppResponsive.rs(size, 120),
                              height: AppResponsive.rs(size, 90),
                              decoration: BoxDecoration(
                                color: AppColors.cameraBg,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 12)),
                                border: Border.all(
                                  color: AppColors.green.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Container(
                                      width: AppResponsive.rs(size, 60),
                                      height: AppResponsive.rs(size, 50),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.green,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 6)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppColors.green,
                                      size: AppResponsive.sp(size, 28),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppResponsive.rs(size, 8)),
                            Text(
                              'Benar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: AppResponsive.sp(size, 13),
                                fontWeight: FontWeight.w600,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 36)),

                  SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/camera-guide'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              padding: EdgeInsets.symmetric(vertical: AppResponsive.rs(size, 16)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 16)),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Coba Lagi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: AppResponsive.sp(size, 16),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.rs(size, 8)),
                        TextButton(
                          onPressed: () => context.go('/continue-session'),
                          child: Text(
                            'Lewati',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: AppResponsive.sp(size, 16),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
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

  List<Widget> _buildArrows(Size size) {
    return [
      Positioned(
        left: 24,
        top: 0,
        bottom: 0,
        child: Center(
          child: Icon(
            Icons.arrow_forward_ios,
            color: AppColors.warning.withValues(alpha: 0.6),
            size: AppResponsive.sp(size, 32),
          ),
        ),
      ),
      Positioned(
        right: 24,
        top: 0,
        bottom: 0,
        child: Center(
          child: Icon(
            Icons.arrow_back_ios,
            color: AppColors.warning.withValues(alpha: 0.6),
            size: AppResponsive.sp(size, 32),
          ),
        ),
      ),
      Positioned(
        top: 40,
        left: 0,
        right: 0,
        child: Center(
          child: Icon(
            Icons.arrow_downward,
            color: AppColors.warning.withValues(alpha: 0.6),
            size: AppResponsive.sp(size, 32),
          ),
        ),
      ),
      Positioned(
        bottom: 40,
        left: 0,
        right: 0,
        child: Center(
          child: Icon(
            Icons.arrow_upward,
            color: AppColors.warning.withValues(alpha: 0.6),
            size: AppResponsive.sp(size, 32),
          ),
        ),
      ),
    ];
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth) < metric.length
            ? distance + dashWidth
            : metric.length;
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}
