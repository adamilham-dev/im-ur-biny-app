import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Centralized responsive design utility for TrashScan.
///
/// Design target: iPad landscape (1194×834).
/// All scaling is relative to this reference, with clamping to prevent
/// extreme values on very small or very large screens.
class AppResponsive {
  AppResponsive._();

  // ── Breakpoints (based on shortestSide) ──

  static bool isPhone(Size s) => s.shortestSide < 600;
  static bool isTablet(Size s) => s.shortestSide >= 600;
  static bool isLargeTablet(Size s) => s.shortestSide >= 900;

  // ── Orientation ──

  static bool isPortrait(Size s) => s.width < s.height;
  static bool isLandscape(Size s) => s.width >= s.height;

  // ── Scaling factor ──
  // Average of width/designWidth and height/designHeight, clamped.

  static double scaleFactor(Size s) {
    final wRatio = s.width / AppConstants.designWidth;
    final hRatio = s.height / AppConstants.designHeight;
    return (wRatio + hRatio) / 2;
  }

  // ── Percentage-based sizing (relative to design target) ──

  /// Width percentage: returns [percent]% of screen width, clamped.
  static double wp(Size s, double percent) =>
      (s.width * percent / 100).clamp(0.0, s.width);

  /// Height percentage: returns [percent]% of screen height, clamped.
  static double hp(Size s, double percent) =>
      (s.height * percent / 100).clamp(0.0, s.height);

  // ── Responsive font ──
  // Scales [baseSize] (designed for 1194×834) to current screen.

  static double sp(Size s, double baseSize) {
    final scale = scaleFactor(s);
    final scaled = baseSize * scale;
    // Clamp to prevent fonts becoming unreadable or absurdly large
    return scaled.clamp(
      baseSize * AppConstants.fontScaleMin,
      baseSize * AppConstants.fontScaleMax,
    );
  }

  // ── Responsive spacing ──
  // Scales [baseSpace] (designed for 1194×834) to current screen.

  static double rs(Size s, double baseSpace) {
    final scale = scaleFactor(s);
    final scaled = baseSpace * scale;
    return scaled.clamp(
      baseSpace * AppConstants.spacingScaleMin,
      baseSpace * AppConstants.spacingScaleMax,
    );
  }

  // ── Convenience methods ──

  /// Responsive border radius.
  static double radius(Size s, double baseRadius) {
    return rs(s, baseRadius);
  }

  /// Responsive icon size.
  static double iconSize(Size s, double baseSize) {
    return sp(s, baseSize);
  }

  /// Responsive mascot size, considering orientation.
  static double mascotSize(Size s, {double portraitFactor = 0.28, double landscapeFactor = 0.28, double minSize = 120, double maxSize = 232}) {
    if (isLandscape(s)) {
      return (s.height * landscapeFactor).clamp(minSize, maxSize);
    }
    return (s.width * portraitFactor).clamp(minSize, maxSize);
  }

  // ── Responsive EdgeInsets ──

  static EdgeInsets paddingAll(Size s, double base) =>
      EdgeInsets.all(rs(s, base));

  static EdgeInsets paddingSymmetric(Size s, {double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(
        horizontal: rs(s, h),
        vertical: rs(s, v),
      );

  // ── Responsive SizedBox ──

  static SizedBox hGap(Size s, double base) =>
      SizedBox(height: rs(s, base));

  static SizedBox wGap(Size s, double base) =>
      SizedBox(width: rs(s, base));

  // ── Text scaling safe ──
  // Returns a TextScaler that respects the responsive scaling.

  static TextScaler textScaler(Size s, double baseFontSize) {
    final scaled = sp(s, baseFontSize);
    final scale = scaled / baseFontSize;
    return TextScaler.linear(scale.clamp(0.7, 1.5));
  }
}
