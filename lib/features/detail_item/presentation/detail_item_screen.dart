import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/scan_result.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/biny_flight_controller.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_mascot.dart';

/// Screen 10 - Detail Item (Popup).
///
/// Pixel-perfect modal overlay showing full item details:
/// - Header: category image + name (in category color) + item description + close
/// - Stats row: CONFIDENCE (mint) + XP DIDAPAT (amber)
/// - CARA MEMBUANG: numbered/icon steps with dividers
/// - Tahukah kamu?: amber card with Biny-think mascot + edu fact
///
/// Shown via [show] as a transparent dialog overlaying the current screen
/// (result or multi-result). The veil (rgba(26,20,52,0.5)) sits on top of
/// the live result screen — NOT a separate page, NOT a black void.
class DetailItemScreen extends ConsumerWidget {
  const DetailItemScreen({super.key});

  /// Show the detail popup as an overlay on the current screen.
  /// The underlying screen (result / multi-result) stays visible behind
  /// the veil barrier — this is a real popup, not a new route.
  static void show(BuildContext context) {
    // Hide the flying Biny overlay so it doesn't render on top of the
    // dialog (the overlay lives above the Navigator, so without this it
    // would float over the dialog content while the result screen's
    // BinyHero is still mounted underneath).
    BinyFlightController.instance.hide();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Detail Item',
      // Transparent barrier — we paint our own veil inside so the
      // underlying screen shows through it (not black).
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const DetailItemScreen(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ).whenComplete(() => BinyFlightController.instance.show());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final isPhone = AppResponsive.isPhone(size);

    final result =
        ref.watch(selectedDetailProvider) ?? ref.watch(scanResultProvider);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Veil — rgba(26,20,52,0.5) ──
            // Painted over the live result screen (which stays mounted behind
            // the dialog overlay), so the user sees the result with a veil.
            const ColoredBox(color: Color(0x801A1434)),

            // ── Popup card ──
            SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // prevent dismiss when tapping card
                  child: result == null
                      ? _buildEmpty(context)
                      : _buildPopupCard(
                          context, size, result, isPortrait, isPhone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Text(
        'Tidak ada data',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: Colors.white70,
        ),
      );

  // ─────────────────────────────────────────────────────────────────────
  // POPUP CARD
  //   660×auto, white, r30, p24, gap24
  //   drop-shadow 0/40/45 rgba(26,20,52,0.4)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildPopupCard(BuildContext context, Size size, ScanResult result,
      bool isPortrait, bool isPhone) {
    final scale = _cardScale(size, isPortrait, isPhone);
    final cardW = (isPhone ? size.width - 32 : 660.0 * scale)
        .clamp(280.0, 660.0);
    final pad = (isPhone ? 18.0 : 24.0 * scale);
    final gap = (isPhone ? 16.0 : 24.0 * scale);
    final radius = (isPhone ? 22.0 : 30.0 * scale);

    final cat = result.category;
    final confPct = (result.confidence * 100).round();
    final xp = _calcXP(result);

    return Container(
      width: cardW,
      constraints: BoxConstraints(
        maxHeight: (size.height * (isPhone ? 0.88 : 0.92)).clamp(400.0, 760.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1434).withValues(alpha: 0.4),
            blurRadius: 45 * scale,
            offset: Offset(0, 40 * scale),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(context, size, result, cat, scale, isPhone),
            SizedBox(height: gap),

            // 2. Stats
            _buildStatsRow(size, cat.color, confPct, xp, scale, isPhone),
            SizedBox(height: gap),

            // 3. Cara membuang
            _buildDisposalSteps(size, cat, scale, isPhone),
            SizedBox(height: gap),

            // 4. Tahukah kamu?
            _buildEduFact(size, cat, scale, isPhone),
          ],
        ),
      ),
    );
  }

  double _cardScale(Size size, bool isPortrait, bool isPhone) {
    if (isPhone) return 1.0;
    final ref = isPortrait ? size.height : size.width;
    return (ref / 1194.0).clamp(0.55, 1.0);
  }

  // ─────────────────────────────────────────────────────────────────────
  // HEADER — (phead) + (close)
  //   Row[ image 54×54 (object-cover), col[ name 32px catColor line34,
  //         desc 16px PJS SemiBold #5c5980 line1.5 ], close 42×42 #f2effb r13 ]
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, Size size, ScanResult result,
      WasteCategory cat, double scale, bool isPhone) {
    final imgSz = isPhone ? 44.0 : 54.0 * scale;
    final nameFS = isPhone ? 24.0 : 32.0 * scale;
    final nameLH = isPhone ? 28.0 : 34.0 * scale;
    final descFS = isPhone ? 13.0 : 16.0 * scale;
    final closeSz = isPhone ? 36.0 : 42.0 * scale;
    final closeR = isPhone ? 11.0 : 13.0 * scale;
    final gap8 = isPhone ? 8.0 : 8.0 * scale;
    final imgR = isPhone ? 12.0 : 14.0 * scale;

    final catAsset = _categoryImageAsset(cat);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Category icon — matches category-select page exactly
        // (uses the same PNG illustrations from assets/images/page_5/)
        catAsset != null
            ? Image.asset(
                catAsset,
                width: imgSz,
                height: imgSz,
                fit: BoxFit.contain,
              )
            : Container(
                width: imgSz,
                height: imgSz,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(imgR),
                ),
                child: Center(
                  child: Icon(cat.icon,
                      size: imgSz * 0.5, color: cat.color),
                ),
              ),
        SizedBox(width: gap8),
        // Name + description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cat.name,
                style: GoogleFonts.baloo2(
                  fontSize: nameFS,
                  fontWeight: FontWeight.w800,
                  color: cat.color,
                  height: nameLH / nameFS,
                ),
              ),
              Text(
                result.itemName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: descFS,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: gap8),
        // Close button — 42×42 #f2effb r13
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: closeSz,
            height: closeSz,
            decoration: BoxDecoration(
              color: const Color(0xFFF2EFFB),
              borderRadius: BorderRadius.circular(closeR),
            ),
            child: Icon(
              Icons.close_rounded,
              size: closeSz * 0.52,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STATS ROW — gap12, flex1 each
  //   stat1: bg #e1faf1 r16 p16/13 — CONFIDENCE (mint, #15936b)
  //   stat2: bg #fff2d9 r16 p16/13 — XP DIDAPAT (amber, #9a6a00)
  //   Each: icon container 42×42 white r13 + col[ label 11px ExtraBold ls1,
  //         value 23px ExtraBold ]
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(Size size, Color catColor, int confPct, int xp,
      double scale, bool isPhone) {
    final gap = isPhone ? 10.0 : 12.0 * scale;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'CONFIDENCE',
            '$confPct%',
            Icons.check_circle_rounded,
            const Color(0xFFE1FAF1),
            const Color(0xFF15936B),
            scale,
            isPhone,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _buildStatCard(
            'XP DIDAPAT',
            '+$xp',
            Icons.star_rounded,
            const Color(0xFFFFF2D9),
            const Color(0xFF9A6A00),
            scale,
            isPhone,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color bg,
      Color fg, double scale, bool isPhone) {
    final padH = isPhone ? 12.0 : 16.0 * scale;
    final padV = isPhone ? 11.0 : 13.0 * scale;
    final radius = isPhone ? 14.0 : 16.0 * scale;
    final iconBox = isPhone ? 34.0 : 42.0 * scale;
    final iconR = isPhone ? 10.0 : 13.0 * scale;
    final iconSz = isPhone ? 18.0 : 22.0 * scale;
    final labelFS = isPhone ? 10.0 : 11.0 * scale;
    final valueFS = isPhone ? 19.0 : 23.0 * scale;
    final innerGap = isPhone ? 10.0 : 16.0 * scale;
    final labelValueGap = isPhone ? 2.0 : 3.0 * scale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(iconR),
            ),
            child: Icon(icon, size: iconSz, color: fg),
          ),
          SizedBox(width: innerGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: labelFS,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: labelValueGap),
                Text(
                  value,
                  style: GoogleFonts.baloo2(
                    fontSize: valueFS,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // CARA MEMBUANG
  //   Title: 12px ExtraBold #908dac ls1.2
  //   Steps: each row 42×42 #f4f2fb r12 icon + col[ title 17px Bold,
  //          detail 14px SemiBold #908dac ], px2 py14
  //   Steps separated by border-top #ece9f7
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDisposalSteps(
      Size size, WasteCategory cat, double scale, bool isPhone) {
    final steps = cat.disposalSteps;
    final titleFS = isPhone ? 11.0 : 12.0 * scale;
    final gap12 = isPhone ? 10.0 : 12.0 * scale;
    final iconBox = isPhone ? 34.0 : 42.0 * scale;
    final iconR = isPhone ? 10.0 : 12.0 * scale;
    final iconSz = isPhone ? 18.0 : 22.0 * scale;
    final stepTitleFS = isPhone ? 14.0 : 17.0 * scale;
    final stepDetailFS = isPhone ? 12.0 : 14.0 * scale;
    final rowGap = isPhone ? 11.0 : 14.0 * scale;
    final innerGap = isPhone ? 11.0 : 14.0 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CARA MEMBUANG',
          style: GoogleFonts.plusJakartaSans(
            fontSize: titleFS,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: gap12),
        // Steps with top dividers (except first)
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isNotFirst = i > 0;
          return Container(
            decoration: isNotFirst
                ? const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFECE9F7), width: 1),
                    ),
                  )
                : null,
            padding: EdgeInsets.symmetric(
                horizontal: 2 * scale, vertical: rowGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F2FB),
                    borderRadius: BorderRadius.circular(iconR),
                  ),
                  child: Center(
                    child: Icon(
                      _stepIcon(i),
                      size: iconSz,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: innerGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.baloo2(
                          fontSize: stepTitleFS,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        step.detail,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: stepDetailFS,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Icon for each disposal step — clean line icons matching Figma's
  /// icon set (Frame 6/7 vectors at 22×22). Using a small icon rotation
  /// that visually maps to the step's intent.
  IconData _stepIcon(int i) {
    const icons = [
      Icons.water_drop_outlined,
      Icons.delete_outline_rounded,
      Icons.recycling_rounded,
      Icons.cleaning_services_rounded,
      Icons.local_shipping_rounded,
    ];
    return icons[i % icons.length];
  }

  // ─────────────────────────────────────────────────────────────────────
  // TAHUKAH KAMU? — bg #fff2d9 r18 p12
  //   Biny-think 72×75.6 + col[ "Tahukah kamu?" 16px ExtraBold #9a6a00,
  //   body 14.5px Medium #7a5a14 line1.4 ]
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildEduFact(
      Size size, WasteCategory cat, double scale, bool isPhone) {
    final padH = isPhone ? 12.0 : 12.0 * scale;
    final padV = isPhone ? 10.0 : 12.0 * scale;
    final radius = isPhone ? 16.0 : 18.0 * scale;
    final innerGap = isPhone ? 12.0 : 16.0 * scale;
    final mascotW = isPhone ? 56.0 : 72.0 * scale;
    final titleFS = isPhone ? 14.0 : 16.0 * scale;
    final bodyFS = isPhone ? 12.5 : 14.5 * scale;
    final titleBodyGap = isPhone ? 2.0 : 2.0 * scale;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Biny-think mascot — 72×75.6
          BinyMascot(
            size: mascotW,
            expression: BinyExpression.detail,
          ),
          SizedBox(width: innerGap),
          // Text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tahukah kamu?',
                  style: GoogleFonts.baloo2(
                    fontSize: titleFS,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9A6A00),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: titleBodyGap),
                Text(
                  cat.eduFact,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: bodyFS,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7A5A14),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _categoryImageAsset(WasteCategory cat) {
    switch (cat) {
      case WasteCategory.plastik:
        return 'assets/images/page_5/plastik.png';
      case WasteCategory.kertas:
        return 'assets/images/page_5/kertas.png';
      case WasteCategory.organik:
        return 'assets/images/page_5/organik.png';
      case WasteCategory.logam:
        return 'assets/images/page_5/logam.png';
      case WasteCategory.residu:
        return 'assets/images/page_5/residu.png';
      case WasteCategory.kaca:
        return null;
      case WasteCategory.lainnya:
        return 'assets/images/page_5/auto.png';
    }
  }

  int _calcXP(ScanResult result) {
    if (result.isCorrected) return 2;
    if (result.confidence >= 0.8) return 12;
    if (result.confidence >= 0.5) return 10;
    return 8;
  }
}
