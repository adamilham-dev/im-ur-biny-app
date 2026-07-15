import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Screen 16 - Continue / End Session.
/// Lanjut pilah lagi? Tiap sampah yang kamu pilah bikin Biny makin pintar.
class ContinueSessionScreen extends ConsumerStatefulWidget {
  const ContinueSessionScreen({super.key});

  @override
  ConsumerState<ContinueSessionScreen> createState() =>
      _ContinueSessionScreenState();
}

class _ContinueSessionScreenState extends ConsumerState<ContinueSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
    final session = ref.watch(sessionProvider);

    final hPad = isPortrait ? AppResponsive.rs(size, 24) : size.width * 0.10;
    final mascotSize = AppResponsive.mascotSize(
      size,
      portraitFactor: 0.20,
      landscapeFactor: 0.14,
      minSize: 80,
      maxSize: 130,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: AppResponsive.rs(size, 24),
              ),
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Biny mascot ---
                    BinyHero(
                      size: mascotSize,
                      expression: BinyExpression.cont,
                    ),

                    SizedBox(height: AppResponsive.rs(size, 20)),

                    // --- "SESI BERJALAN" label ---
                    Container(
                      padding: AppResponsive.paddingSymmetric(size, h: 14, v: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppResponsive.rs(size, 6)),
                          Text(
                            'SESI BERJALAN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: AppResponsive.sp(size, 11).clamp(9.0, 12.0),
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppResponsive.rs(size, 14)),

                    // --- Title ---
                    Text(
                      'Lanjut pilah lagi?',
                      style: GoogleFonts.baloo2(
                        fontSize: AppResponsive.sp(size, 28).clamp(20.0, 30.0),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: AppResponsive.rs(size, 8)),

                    // --- Subtitle ---
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Text(
                        'Tiap sampah yang kamu pilah bikin Biny makin pintar & bumi makin sehat.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: AppResponsive.sp(size, 14).clamp(11.0, 15.0),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: AppResponsive.rs(size, 28)),

                    // --- Two stat cards ---
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: isPortrait
                          ? Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.delete_outline_rounded,
                                    iconColor: AppColors.primary,
                                    iconBg: AppColors.primarySoft,
                                    value: '${session.scanCount}',
                                    label: 'Sudah dipilah',
                                    size: size,
                                  ),
                                ),
                                SizedBox(width: AppResponsive.rs(size, 12)),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.star_rounded,
                                    iconColor: const Color(0xFFFFA000),
                                    iconBg: const Color(0xFFFFC107).withValues(alpha: 0.2),
                                    value: '+${session.totalXP}',
                                    label: 'XP sesi ini',
                                    size: size,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatCard(
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: AppColors.primary,
                                  iconBg: AppColors.primarySoft,
                                  value: '${session.scanCount}',
                                  label: 'Sudah dipilah',
                                  size: size,
                                  width: 180,
                                ),
                                SizedBox(width: AppResponsive.rs(size, 16)),
                                _StatCard(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFFFA000),
                                  iconBg: const Color(0xFFFFC107).withValues(alpha: 0.2),
                                  value: '+${session.totalXP}',
                                  label: 'XP sesi ini',
                                  size: size,
                                  width: 180,
                                ),
                              ],
                            ),
                    ),

                    SizedBox(height: AppResponsive.rs(size, 36)),

                    // --- Buttons ---
                    _buildButtons(context, size, isPortrait),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, Size size, bool isPortrait) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: isPortrait
          ? Column(
              children: [
                // SELESAI SESI - outlined/soft
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.rs(size, 54).clamp(44.0, 56.0),
                  child: OutlinedButton(
                    onPressed: () => context.go('/feedback'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      'SELESAI SESI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppResponsive.rs(size, 12)),
                // PILAH LAGI - primary filled
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.rs(size, 54).clamp(44.0, 56.0),
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(rescanProvider.notifier).state = true;
                      context.go('/scanning');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      'PILAH LAGI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SELESAI SESI - outlined/soft
                SizedBox(
                  width: 200,
                  height: AppResponsive.rs(size, 54).clamp(44.0, 56.0),
                  child: OutlinedButton(
                    onPressed: () => context.go('/feedback'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      'SELESAI SESI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppResponsive.rs(size, 16)),
                // PILAH LAGI - primary filled
                SizedBox(
                  width: 200,
                  height: AppResponsive.rs(size, 54).clamp(44.0, 56.0),
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(rescanProvider.notifier).state = true;
                      context.go('/scanning');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      'PILAH LAGI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppResponsive.sp(size, 16).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Stat card showing a single metric.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final Size size;
  final double? width;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.size,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: AppResponsive.paddingSymmetric(size, h: 20, v: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.radius(size, 20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: AppResponsive.rs(size, 44),
            height: AppResponsive.rs(size, 44),
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, size: AppResponsive.sp(size, 24), color: iconColor),
          ),
          SizedBox(height: AppResponsive.rs(size, 10)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: AppResponsive.sp(size, 22).clamp(16.0, 24.0),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.rs(size, 2)),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: AppResponsive.sp(size, 13).clamp(10.0, 14.0),
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
