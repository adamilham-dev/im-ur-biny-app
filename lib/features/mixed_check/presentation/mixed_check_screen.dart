import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';

class MixedCheckScreen extends StatelessWidget {
  const MixedCheckScreen({super.key});

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
                  // Green detection box (confirmed) - scaled for portrait
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Container(
                      width: AppResponsive.rs(size, 90),
                      height: AppResponsive.rs(size, 80),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.green,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 5, v: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '94%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Another green detection box
                  Positioned(
                    left: 130,
                    top: 30,
                    child: Container(
                      width: AppResponsive.rs(size, 85),
                      height: AppResponsive.rs(size, 75),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.green,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 5, v: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '91%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Yellow warning detection box
                  Positioned(
                    left: 70,
                    top: 110,
                    child: Container(
                      width: AppResponsive.rs(size, 95),
                      height: AppResponsive.rs(size, 60),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.warning,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 5, v: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '45%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.help_outline,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 22),
                            ),
                          ),
                        ],
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
                                  Icons.fact_check,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 16),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 6)),
                                Text(
                                  'Perlu pengecekan manual',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perlu Dicek Manual',
                    style: GoogleFonts.baloo2(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 6)),

                  Text(
                    'Sebagian sampah sudah terdeteksi, tapi ada yang perlu konfirmasi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 16)),

                  // Detected items list
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppResponsive.radius(size, 16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _DetectedItemTile(
                          name: 'Botol Plastik',
                          confidence: 94,
                          status: _ItemStatus.confirmed,
                          fontSize: smallFontSize,
                          size: size,
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.surfaceVariant,
                          indent: AppResponsive.rs(size, 16),
                          endIndent: AppResponsive.rs(size, 16),
                        ),
                        _DetectedItemTile(
                          name: 'Kertas Bekas',
                          confidence: 91,
                          status: _ItemStatus.confirmed,
                          fontSize: smallFontSize,
                          size: size,
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.surfaceVariant,
                          indent: AppResponsive.rs(size, 16),
                          endIndent: AppResponsive.rs(size, 16),
                        ),
                        _DetectedItemTile(
                          name: 'Unknown Item',
                          confidence: 45,
                          status: _ItemStatus.needsCheck,
                          fontSize: smallFontSize,
                          size: size,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go('/unknown-detected'),
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
                            'Cek Item',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppResponsive.rs(size, 12)),
                      TextButton(
                        onPressed: () => context.go('/multi-result'),
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
          // Left: Camera preview with mixed detection boxes
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
                  Positioned(
                    left: 50,
                    top: 100,
                    child: Container(
                      width: AppResponsive.rs(size, 130),
                      height: AppResponsive.rs(size, 140),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.green,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 6, v: 3),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '94%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 220,
                    top: 120,
                    child: Container(
                      width: AppResponsive.rs(size, 120),
                      height: AppResponsive.rs(size, 130),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.green,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 6, v: 3),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '91%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 130,
                    top: 300,
                    child: Container(
                      width: AppResponsive.rs(size, 140),
                      height: AppResponsive.rs(size, 150),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.warning,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: AppResponsive.paddingSymmetric(size, h: 6, v: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(AppResponsive.radius(size, 4)),
                              ),
                              child: Text(
                                '45%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: AppResponsive.sp(size, 11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.help_outline,
                              color: AppColors.warning.withValues(alpha: 0.5),
                              size: AppResponsive.sp(size, 36),
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
                                  Icons.fact_check,
                                  color: AppColors.warning,
                                  size: AppResponsive.sp(size, 18),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 8)),
                                Text(
                                  'Perlu pengecekan manual',
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
              padding: AppResponsive.paddingSymmetric(size, h: 40, v: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perlu Dicek Manual',
                    style: GoogleFonts.baloo2(
                      fontSize: AppResponsive.sp(size, 28),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 8)),

                  Text(
                    'Sebagian sampah sudah terdeteksi, tapi ada yang perlu konfirmasi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: AppResponsive.sp(size, 16),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 24)),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppResponsive.radius(size, 16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _DetectedItemTile(
                          name: 'Botol Plastik',
                          confidence: 94,
                          status: _ItemStatus.confirmed,
                          size: size,
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.surfaceVariant,
                          indent: AppResponsive.rs(size, 16),
                          endIndent: AppResponsive.rs(size, 16),
                        ),
                        _DetectedItemTile(
                          name: 'Kertas Bekas',
                          confidence: 91,
                          status: _ItemStatus.confirmed,
                          size: size,
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.surfaceVariant,
                          indent: AppResponsive.rs(size, 16),
                          endIndent: AppResponsive.rs(size, 16),
                        ),
                        _DetectedItemTile(
                          name: 'Unknown Item',
                          confidence: 45,
                          status: _ItemStatus.needsCheck,
                          size: size,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.rs(size, 32)),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go('/unknown-detected'),
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
                            'Cek Item',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: AppResponsive.sp(size, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppResponsive.rs(size, 16)),
                      TextButton(
                        onPressed: () => context.go('/multi-result'),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ItemStatus { confirmed, needsCheck }

class _DetectedItemTile extends StatelessWidget {
  final String name;
  final int confidence;
  final _ItemStatus status;
  final double? fontSize;
  final Size size;

  const _DetectedItemTile({
    required this.name,
    required this.confidence,
    required this.status,
    required this.size,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == _ItemStatus.confirmed;
    final color = isConfirmed ? AppColors.green : AppColors.warning;
    final effectiveFontSize = fontSize ?? AppResponsive.sp(size, 15.0);

    return Padding(
      padding: AppResponsive.paddingSymmetric(size, h: 16, v: 14),
      child: Row(
        children: [
          Container(
            width: AppResponsive.rs(size, 32),
            height: AppResponsive.rs(size, 32),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfirmed ? Icons.check : Icons.help_outline,
              color: color,
              size: AppResponsive.sp(size, 18),
            ),
          ),
          SizedBox(width: AppResponsive.rs(size, 12)),

          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: effectiveFontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          Container(
            padding: AppResponsive.paddingSymmetric(size, h: 10, v: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppResponsive.radius(size, 8)),
            ),
            child: Text(
              '$confidence%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: effectiveFontSize - 2,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
