import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_responsive.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ── Headlines — Baloo 2 ExtraBold ──

  /// heading1: base 52 (designed for 1194×834)
  static TextStyle heading1(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.baloo2(
      fontSize: AppResponsive.sp(s, 52),
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: const Color(0xFF2B2A45),
    );
  }

  /// heading2: base 40
  static TextStyle heading2(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.baloo2(
      fontSize: AppResponsive.sp(s, 40),
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: const Color(0xFF2B2A45),
    );
  }

  /// heading3: base 32
  static TextStyle heading3(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.baloo2(
      fontSize: AppResponsive.sp(s, 32),
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: const Color(0xFF2B2A45),
    );
  }

  // ── Body — Plus Jakarta Sans ──

  /// bodyLarge: base 22
  static TextStyle bodyLarge(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: AppResponsive.sp(s, 22),
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: const Color(0xFF5C5980),
    );
  }

  /// bodyMedium: base 18
  static TextStyle bodyMedium(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: AppResponsive.sp(s, 18),
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: const Color(0xFF5C5980),
    );
  }

  /// bodySmall: base 14
  static TextStyle bodySmall(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: AppResponsive.sp(s, 14),
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: const Color(0xFF908DAC),
    );
  }

  // ── CTA / Button ──

  /// ctaText: base 18
  static TextStyle ctaText(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: AppResponsive.sp(s, 18),
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: const Color(0xFFFFFFFF),
    );
  }

  // ── Caption / Muted ──

  /// caption: base 12
  static TextStyle caption(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: AppResponsive.sp(s, 12),
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: const Color(0xFF908DAC),
    );
  }

  // ── Raw getters (for cases where BuildContext is not available, e.g. theme) ──
  // These return the design-target sizes without scaling.

  static TextStyle get heading1Raw => GoogleFonts.baloo2(
        fontSize: 52,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: const Color(0xFF2B2A45),
      );

  static TextStyle get heading2Raw => GoogleFonts.baloo2(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: const Color(0xFF2B2A45),
      );

  // ── Bini-style static getters (fixed sizes, no BuildContext) ──

  static TextStyle get headingExtraBold => GoogleFonts.baloo2(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingBold => GoogleFonts.baloo2(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyBoldStatic => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMediumStatic => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get pillLabel => GoogleFonts.baloo2(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: 0.095,
        color: AppColors.primaryPress,
      );

  static TextStyle get captionStatic => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.026,
        color: AppColors.textMuted,
      );

  static TextStyle get buttonText => GoogleFonts.baloo2(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.surface,
      );
}
