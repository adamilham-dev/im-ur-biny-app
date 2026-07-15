import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';

class MixedTooManyScreen extends StatelessWidget {
  const MixedTooManyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);

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
                  // Many yellow detection boxes scattered (scaled for portrait)
                  ..._buildDetectionBoxes(scaled: true),
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
                                  Icons.grid_view,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 16),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 6)),
                                Text(
                                  '7 objek terdeteksi',
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
              padding: AppResponsive.paddingSymmetric(size, h: 24, v: 24),
              child: Column(
                children: [
                  Container(
                    width: AppResponsive.rs(size, 56),
                    height: AppResponsive.rs(size, 56),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.grid_view,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 28),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 16)),

                  Text(
                    'Terlalu Banyak Sampah',
                    style: GoogleFonts.baloo2(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 8)),

                  Text(
                    'AI mendeteksi terlalu banyak objek sekaligus. Kurangi jumlah sampah di papan untuk hasil lebih akurat.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 28)),

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
                              'Kurangi & Scan Ulang',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.rs(size, 8)),
                        TextButton(
                          onPressed: () => context.go('/multi-result'),
                          child: Text(
                            'Tetap Lanjut',
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
          // Left: Camera preview with many detection boxes
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
                  ..._buildDetectionBoxes(scaled: false),
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
                                  Icons.grid_view,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 18),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 8)),
                                Text(
                                  '7 objek terdeteksi',
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
                      Icons.grid_view,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 36),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  Text(
                    'Terlalu Banyak Sampah',
                    style: GoogleFonts.baloo2(
                      fontSize: AppResponsive.sp(size, 28),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 12)),

                  SizedBox(
                    width: 400,
                    child: Text(
                      'AI mendeteksi terlalu banyak objek sekaligus. Kurangi jumlah sampah di papan untuk hasil lebih akurat.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 48)),

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
                              'Kurangi & Scan Ulang',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: AppResponsive.sp(size, 16),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.rs(size, 8)),
                        TextButton(
                          onPressed: () => context.go('/multi-result'),
                          child: Text(
                            'Tetap Lanjut',
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

  List<Widget> _buildDetectionBoxes({required bool scaled}) {
    final boxes = <Map<String, dynamic>>[
      {'left': 40.0, 'top': 80.0, 'w': 100.0, 'h': 110.0},
      {'left': 180.0, 'top': 60.0, 'w': 90.0, 'h': 100.0},
      {'left': 300.0, 'top': 100.0, 'w': 110.0, 'h': 120.0},
      {'left': 60.0, 'top': 260.0, 'w': 95.0, 'h': 105.0},
      {'left': 200.0, 'top': 240.0, 'w': 100.0, 'h': 115.0},
      {'left': 340.0, 'top': 280.0, 'w': 85.0, 'h': 95.0},
      {'left': 140.0, 'top': 400.0, 'w': 105.0, 'h': 110.0},
    ];

    if (scaled) {
      // Scale boxes to fit within a ~360x180 area
      return boxes
          .map(
            (b) => Positioned(
              left: (b['left'] as double) * 0.45,
              top: (b['top'] as double) * 0.35,
              child: Container(
                width: (b['w'] as double) * 0.55,
                height: (b['h'] as double) * 0.45,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.warning,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          )
          .toList();
    }

    return boxes
        .map(
          (b) => Positioned(
            left: b['left'] as double,
            top: b['top'] as double,
            child: Container(
              width: b['w'] as double,
              height: b['h'] as double,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.warning,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        )
        .toList();
  }
}
