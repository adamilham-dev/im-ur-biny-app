import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/scan_result.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Pixel-perfect "21 · Low Confidence"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma)
/// - Background #FBFAFF with two LAYER_BLUR blobs + 5 decorative dots
/// - Container at left:92, vertically centered, gap:60
/// - Left: image card 430×430 (white, r32, shadow 0/18/44 rgba(41,31,89,.13))
///   - inner img 400×400 at (15,15), r22, gradient 111.8° #2B2843→#191731
///   - inner glow ellipse 250×250 (category-tinted)
///   - "PERLU DICEK" badge top:14 (warning tinted)
///   - tag bottom: "Kategori · 0.XX" (dark with cat-color dot)
/// - Right: 520px column, gap:24
///   1. Biny(84×88.2) + speech bubble "Hmm, aku agak ragu yang ini…"
///   2. Category section: name 58px ExtraBold "?" + "Keyakinan rendah" pill
///      + description 17px Medium
///   3. Stats card 520×~155 (white, r20) with "KEMUNGKINAN KATEGORI" +
///      top-2 candidates with progress bars
///   4. Buttons "Koreksi" (#EDE8FF drop-shadow) + "Ya, Benar" (#7C5CFC)
///   5. XP note "XP ditambahkan setelah kamu konfirmasi"
class LowConfidenceScreen extends ConsumerWidget {
  const LowConfidenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final scanResult = ref.watch(scanResultProvider);
    final result = scanResult ?? _sampleResult;
    // Prefer the detected object's crop over the full frame — essential in
    // the mixed-mode "Periksa" flow where the frame contains several objects
    // and only this one is being checked.
    final capturedImage =
        scanResult?.croppedImage ?? ref.watch(capturedImageProvider);

    final bgScale = (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ──
          if (!isPortrait) ...[
            Positioned(
              left: -90 * bgScale,
              top: -150 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(440 * bgScale, 440 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFF4DA3FF),
                    opacity: 0.2,
                    blurSigma: 110 * bgScale,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 920 * bgScale,
              top: 540 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(360 * bgScale, 360 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFFFFB02E),
                    opacity: 0.2,
                    blurSigma: 110 * bgScale,
                  ),
                ),
              ),
            ),
            // ── Decorative dots ──
            _buildDot(left: 340 * bgScale, top: 120 * bgScale,
                color: const Color(0xFF4DA3FF), dotSize: 11 * bgScale, radius: 2),
            _buildDot(left: 760 * bgScale, top: 90 * bgScale,
                color: const Color(0xFFFFB02E), dotSize: 9 * bgScale, radius: 2),
            _buildDot(left: 1070 * bgScale, top: 180 * bgScale,
                color: const Color(0xFF3AD6A0), dotSize: 8 * bgScale, radius: 4),
            _buildDot(left: 120 * bgScale, top: 640 * bgScale,
                color: const Color(0xFFFF6B8A), dotSize: 10 * bgScale, radius: 2),
            _buildDot(left: 880 * bgScale, top: 690 * bgScale,
                color: const Color(0xFF7C5CFC), dotSize: 10 * bgScale, radius: 2),
          ],

          // ── Main content ──
          SafeArea(
            child: Center(
              child: isPortrait
                  ? _buildPortrait(context, size, ref, result, capturedImage)
                  : _buildLandscape(context, size, ref, result, capturedImage),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // DECORATIVE DOT
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDot({
    required double dotSize,
    required Color color,
    required double radius,
    double? left,
    double? top,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // PORTRAIT (phone)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildPortrait(BuildContext context, Size size, WidgetRef ref,
      ScanResult result, Uint8List? capturedImage) {
    final isPhone = AppResponsive.isPhone(size);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 16 : 24,
        vertical: isPhone ? 12 : 20,
      ),
      child: Column(
        children: [
          SizedBox(
            height: isPhone ? size.width * 0.75 : size.width * 0.5,
            width: isPhone ? size.width * 0.75 : size.width * 0.5,
            child: _buildImageCard(result, capturedImage, isPhone: isPhone),
          ),
          SizedBox(height: isPhone ? 20 : 32),
          _buildRightPanel(context, size, ref, result, isPortrait: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LANDSCAPE (iPad) — Figma exact layout
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size, WidgetRef ref,
      ScanResult result, Uint8List? capturedImage) {
    final availW = size.width - 92.0 - 92.0;
    final scale = (availW / 1010.0).clamp(0.5, 1.0);
    final gap = 60.0 * scale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 92),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildImageCard(result, capturedImage, scale: scale),
          SizedBox(width: gap),
          SizedBox(
            width: 520.0 * scale,
            child: _buildRightPanel(context, size, ref, result,
                isPortrait: false, scale: scale),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // IMAGE CARD — Figma: 430×430, white, r32
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildImageCard(ScanResult result, Uint8List? capturedImage,
      {double scale = 1.0, bool isPhone = false}) {
    final cardSize = 430.0 * scale;
    final innerSize = 400.0 * scale;
    final pad = 15.0 * scale;
    final cardRadius = 32.0 * scale;
    final innerRadius = 22.0 * scale;
    final catColor = result.displayColor;

    return Container(
      width: isPhone ? null : cardSize,
      height: isPhone ? null : cardSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPhone ? 24.0 : cardRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.13),
            blurRadius: 44 * scale,
            offset: Offset(0, 18 * scale),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 12.0 : pad),
        child: Container(
          width: isPhone ? null : innerSize,
          height: isPhone ? null : innerSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isPhone ? 18.0 : innerRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B2843), Color(0xFF191731)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (capturedImage != null)
                Image.memory(capturedImage, fit: BoxFit.cover)
              else
                _buildPlaceholder(catColor, scale, isPhone: isPhone),

              // "PERLU DICEK" badge — Figma: top:14.4
              // bg rgba(255,176,46,0.18), border rgba(255,176,46,0.55)
              Positioned(
                top: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 109 * scale,
                    height: 30 * scale,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB02E).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFFB02E).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'PERLU DICEK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFB02E),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom tag — "Kategori · 0.XX"
              Positioned(
                bottom: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 8 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A14).withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8 * scale,
                          height: 8 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: result.displayCategoryColor,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${result.displayCategoryName} ·',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  ${result.confidence.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.4,
                                  letterSpacing: 0.028,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inner placeholder: dark gradient + soft cat-tinted glow ellipse +
  /// camera icon. Matches Figma's "image 17" placeholder pattern.
  Widget _buildPlaceholder(Color catColor, double scale,
      {bool isPhone = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 75 * scale,
          top: 70 * scale,
          child: IgnorePointer(
            child: Container(
              width: 250 * scale,
              height: 250 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    catColor.withValues(alpha: 0.35),
                    catColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.image_outlined,
            size: (isPhone ? 80 : 137) * scale,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Figma: 520px col, gap:24
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext context, Size size, WidgetRef ref,
      ScanResult result, {required bool isPortrait, double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap24 = isPhone ? 14.0 : 24.0 * scale;
    final gap16 = isPhone ? 10.0 : 16.0 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Biny + speech bubble
        _buildBinyBubble(size, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 2. Category section
        _buildCategorySection(size, result, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 3. Stats card
        _buildStatsCard(size, result, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 4. Buttons row
        Padding(
          padding: EdgeInsets.only(top: 16 * scale),
          child: _buildButtonsRow(context, ref, size,
              scale: scale, isPortrait: isPortrait),
        ),
        SizedBox(height: isPhone ? 8.0 : 12.0 * scale),

        // 5. XP note
        Text(
          'XP ditambahkan setelah kamu konfirmasi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isPhone ? 12 : 15.0 * scale,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY + SPEECH BUBBLE — "Hmm, aku agak ragu yang ini…"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final mascotSize = isPhone ? 60.0 : 88.2 * scale;
    final bubblePadH = isPhone ? 14.0 : 20.0 * scale;
    final bubblePadV = isPhone ? 8.0 : 12.0 * scale;
    final bubbleRadius = isPhone ? 16.0 : 22.0 * scale;
    final fontSize = isPhone ? 13.0 : 17.0 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BinyHero(size: mascotSize, expression: BinyExpression.lowConfidence),
        SizedBox(width: 16 * scale),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: bubblePadH,
                  vertical: bubblePadV,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFEDE8FF),
                    width: isPhone ? 1.5 : 2.0,
                  ),
                  borderRadius: BorderRadius.circular(bubbleRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPress.withValues(alpha: 0.08),
                      blurRadius: isPhone ? 10 : 18,
                      offset: Offset(0, isPhone ? 3 : 6),
                    ),
                  ],
                ),
                child: Text(
                  'Hmm, aku agak ragu yang ini…',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Bubble tail
              Positioned(
                left: -7,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398, // 45°
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xFFEDE8FF),
                            width: isPhone ? 1.5 : 2.0,
                          ),
                          bottom: BorderSide(
                            color: const Color(0xFFEDE8FF),
                            width: isPhone ? 1.5 : 2.0,
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // CATEGORY SECTION — "Plastik?" 58px + "Keyakinan rendah" pill + desc
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCategorySection(Size size, ScanResult result,
      {double scale = 1.0, bool isPhone = false}) {
    final catSize = isPhone ? 36.0 : 58.0 * scale;
    final pillPadH = isPhone ? 10.0 : 14.0 * scale;
    final pillPadV = isPhone ? 5.0 : 7.0 * scale;
    final pillFontSize = isPhone ? 12.0 : 16.0 * scale;
    final descSize = isPhone ? 14.0 : 17.0 * scale;
    final gap16 = isPhone ? 8.0 : 16.0 * scale;
    final catColor = result.displayColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row: name + pill
        Row(
          children: [
            Flexible(
              child: Text(
                '${result.displayCategoryName}?',
                style: GoogleFonts.baloo2(
                  fontSize: catSize,
                  fontWeight: FontWeight.w800,
                  color: result.displayCategoryColor,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(width: 16 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: pillPadH, vertical: pillPadV),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2D9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Keyakinan rendah',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: pillFontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9A6A00),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap16),
        // Description
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isPhone ? double.infinity : 480.0 * scale,
          ),
          child: Text(
            'Tebakan terbaikku ${result.displayCategoryName}, tapi aku belum yakin. Bantu pastikan ya.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: descSize,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STATS CARD — "KEMUNGKINAN KATEGORI" + top-2 progress bars
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStatsCard(Size size, ScanResult result,
      {double scale = 1.0, bool isPhone = false}) {
    final rawTop2 = result.topProbabilities.take(2).toList();
    // Fallback: if no probabilities, use the result category alone
    final entries = rawTop2.isNotEmpty
        ? rawTop2
        : [
            MapEntry(result.dynamicCategoryName ?? result.category.name, result.confidence),
          ];

    return Container(
      width: isPhone ? double.infinity : 520.0 * scale,
      padding: EdgeInsets.all(isPhone ? 16.0 : 20.0 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPhone ? 18 : 20.0 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.08),
            blurRadius: isPhone ? 12 : 16,
            offset: Offset(0, isPhone ? 4 : 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'KEMUNGKINAN KATEGORI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: isPhone ? 11 : 13.0 * scale,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 17 * scale),
          // Candidates
          ...entries.asMap().entries.map((entry) {
            final i = entry.key;
            final prob = entry.value;
            final cat = _categoryFromName(prob.key);
            final catColor = cat?.color ?? AppColors.textMuted;
            final isFirst = i == 0;
            final pct = (prob.value * 100).round().clamp(0, 100);

            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < entries.length - 1 ? 17.0 * scale : 0),
              child: _buildCandidateRow(
                cat: cat,
                catColor: catColor,
                name: prob.key,
                pct: pct,
                isFirst: isFirst,
                scale: scale,
                isPhone: isPhone,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCandidateRow({
    required WasteCategory? cat,
    required Color catColor,
    required String name,
    required int pct,
    required bool isFirst,
    required double scale,
    required bool isPhone,
  }) {
    final iconBox = isPhone ? 28.0 : 34.0 * scale;
    final nameSize = isPhone ? 14.0 : 16.0 * scale;
    final pctSize = isPhone ? 16.0 : 19.0 * scale;
    final barH = isPhone ? 8.0 : 9.0 * scale;

    return Row(
      children: [
        // Icon box — uses PNG illustration (matches Figma's KEMUNGKINAN KATEGORI card)
        Container(
          width: iconBox,
          height: iconBox,
          padding: EdgeInsets.all(iconBox * 0.15),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(isPhone ? 9 : 10.0 * scale),
          ),
          child: cat != null
              ? Image.asset(_iconAssetFor(cat), fit: BoxFit.contain)
              : Icon(Icons.category,
                  size: isPhone ? 16 : 18.0 * scale,
                  color: catColor),
        ),
        SizedBox(width: 11 * scale),
        // Right column: row + bar
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.baloo2(
                      fontSize: nameSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: GoogleFonts.baloo2(
                      fontSize: pctSize,
                      fontWeight: FontWeight.w800,
                      color: catColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4 * scale),
              // Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Container(
                      height: barH,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDF9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (pct / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: barH,
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS ROW — "Koreksi" + "Ya, Benar"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtonsRow(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0, required bool isPortrait}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap = isPhone ? 8.0 : 12.0 * scale;

    if (isPhone || isPortrait) {
      return Column(
        children: [
          _buildKoreksiButton(context, size, scale: scale, isPhone: isPhone),
          SizedBox(height: gap),
          _buildYaBenarButton(context, ref, size,
              scale: scale, isPhone: isPhone),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildKoreksiButton(context, size, scale: scale),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _buildYaBenarButton(context, ref, size, scale: scale),
        ),
      ],
    );
  }

  /// "Koreksi" — bg #EDE8FF drop-shadow 0/6/0 #DDD3FF
  Widget _buildKoreksiButton(BuildContext context, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDDD3FF),
            offset: Offset(0, isPhone ? 4 : 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () =>
              context.go('/manual-correction', extra: '/low-confidence'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Koreksi',
                style: GoogleFonts.baloo2(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPress,
                  letterSpacing: 0.095,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Ya, Benar" — bg #7C5CFC shadow rgba(124,92,252,0.35) + #5B3FD6
  Widget _buildYaBenarButton(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: isPhone ? 12 : 22,
            offset: Offset(0, isPhone ? 6 : 12),
          ),
          BoxShadow(
            color: AppColors.primaryPress,
            offset: Offset(0, isPhone ? 4 : 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            // Mixed-mode "Periksa" context: write the user-confirmed item
            // back into the multi list (confidence 1.0 = user-confirmed
            // ground truth, same semantics as a dataset hit) and return to
            // /multi-result. History/dataset/XP for mixed items are handled
            // by that screen's "Selesai" flow — don't double-count here.
            final reanalyzeIndex = ref.read(reanalyzeMultiIndexProvider);
            if (reanalyzeIndex != null) {
              final result = ref.read(scanResultProvider);
              if (result != null) {
                ref.read(scanProvider.notifier).updateMultiResult(
                      reanalyzeIndex,
                      result.copyWith(
                        confidence: 1.0,
                        allProbabilities: {result.category.name: 1.0},
                      ),
                    );
              }
              ref.read(reanalyzeMultiIndexProvider.notifier).state = null;
              context.go('/multi-result');
              return;
            }

            await ref.read(scanProvider.notifier).saveToHistory();
            ref
                .read(sessionProvider.notifier)
                .addXP(SessionService.xpExistingCategory);
            ref.read(sessionProvider.notifier).addScan();
            context.go('/thank-you');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Ya, Benar',
                style: GoogleFonts.baloo2(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.095,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sample fallback result supaya halaman tetap bisa di-preview via
  /// debug menu tanpa harus lewat flow scanning.
  static final ScanResult _sampleResult = ScanResult(
    itemName: 'Botol Plastik',
    category: WasteCategory.plastik,
    confidence: 0.42,
    disposalInfo: 'Masukkan ke tempat daur ulang plastik (biru)',
    description: 'Botol plastik dengan keyakinan rendah',
    allProbabilities: const {
      'Plastik': 0.42,
      'Logam': 0.31,
      'Kertas': 0.12,
      'Organik': 0.08,
      'Residu': 0.04,
      'Kaca': 0.02,
      'Lainnya': 0.01,
    },
  );

  /// Maps category to PNG illustration asset (matches Figma's KEMUNGKINAN
  /// KATEGORI card icons). Same set as detail_item_screen / manual_correction.
  String _iconAssetFor(WasteCategory category) {
    switch (category) {
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
      case WasteCategory.lainnya:
        return 'assets/images/page_5/auto.png';
    }
  }
}

/// Helper to get WasteCategory from name string.
WasteCategory? _categoryFromName(String name) {
  for (final cat in WasteCategory.values) {
    if (cat.name.toLowerCase() == name.toLowerCase()) return cat;
  }
  return null;
}

/// Draws a blurred solid-color ellipse — replicates Figma's SOLID fill +
/// LAYER_BLUR effect exactly.
class _BlobPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double blurSigma;

  const _BlobPainter({
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
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.blurSigma != blurSigma;
}
