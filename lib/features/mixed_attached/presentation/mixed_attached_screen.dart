import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';

class MixedAttachedScreen extends StatelessWidget {
  const MixedAttachedScreen({super.key});

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
                  // Yellow detection box covering multiple objects
                  Center(
                    child: Container(
                      width: AppResponsive.rs(size, 200),
                      height: AppResponsive.rs(size, 130),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.warning,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 66,
                            child: Container(
                              width: 1,
                              height: 130,
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 133,
                            child: Container(
                              width: 1,
                              height: 130,
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          Positioned(
                            left: 22,
                            top: 45,
                            child: Icon(
                              Icons.local_drink,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 26),
                            ),
                          ),
                          Positioned(
                            left: 88,
                            top: 45,
                            child: Icon(
                              Icons.description,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 26),
                            ),
                          ),
                          Positioned(
                            left: 155,
                            top: 45,
                            child: Icon(
                              Icons.eco,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 26),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: AppResponsive.paddingAll(size, 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Icon(
                                Icons.link,
                                color: Colors.white,
                                size: AppResponsive.sp(size, 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                  Icons.link,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 16),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 6)),
                                Text(
                                  'Objek menempel',
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
                      Icons.link_off,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 28),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 16)),

                  Text(
                    'Sampah Menempel',
                    style: GoogleFonts.baloo2(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.rs(size, 8)),

                  Text(
                    'Beberapa sampah menempel satu sama lain. Pisahkan dulu, lalu scan satu per satu.',
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
                              'Oke, Sudah Dipisah',
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
          // Left: Camera preview with multiple attached objects
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
                    child: Container(
                      width: AppResponsive.rs(size, 280),
                      height: AppResponsive.rs(size, 240),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.warning,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 90,
                            child: Container(
                              width: 1,
                              height: 240,
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 180,
                            child: Container(
                              width: 1,
                              height: 240,
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          Positioned(
                            left: 30,
                            top: 90,
                            child: Icon(
                              Icons.local_drink,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 32),
                            ),
                          ),
                          Positioned(
                            left: 120,
                            top: 90,
                            child: Icon(
                              Icons.description,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 32),
                            ),
                          ),
                          Positioned(
                            left: 210,
                            top: 90,
                            child: Icon(
                              Icons.eco,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 32),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: AppResponsive.paddingAll(size, 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Icon(
                                Icons.link,
                                color: Colors.white,
                                size: AppResponsive.sp(size, 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                  Icons.link,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 18),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 8)),
                                Text(
                                  'Objek menempel',
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
                      Icons.link_off,
                      color: AppColors.warning,
                      size: AppResponsive.sp(size, 36),
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  Text(
                    'Sampah Menempel',
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
                      'Beberapa sampah menempel satu sama lain. Pisahkan dulu, lalu scan satu per satu.',
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
                              'Oke, Sudah Dipisah',
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
}
