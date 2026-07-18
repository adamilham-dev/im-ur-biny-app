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
import '../../../core/providers/bluetooth_provider.dart';

/// Pixel-perfect "13 · Conclusion — Kategori Baru"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma)
/// - Background #FBFAFF with two LAYER_BLUR blobs + 5 decorative dots
/// - Container at left:92, vertically centered, gap:60
/// - Left: image card 430×430 (white, r32, shadow 0/18/44 rgba(41,31,89,.13))
///   - inner img 400×400 at (15,15), r22, gradient 111.8° #2B2843→#191731
///   - inner glow ellipse 250×250 (category-tinted)
///   - "BARU" badge top:14 (category-tinted)
///   - tag bottom: "Kategori · 0.XX"
/// - Right: 520px column, gap:24
///   1. Biny(84×88.2) + speech bubble "Asik, aku nemu yang baru!"
///   2. Category section: label + name + "KATEGORI BARU" gradient badge
///      + description
///   3. Dataset chip 520×74 (white, r18) with "+25 XP" pill
///   4. Buttons "Koreksi" (#EDE8FF drop-shadow) + "Lanjutkan" (#7C5CFC)
class ConclusionNewScreen extends ConsumerWidget {
  const ConclusionNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final scanResult = ref.watch(scanResultProvider);
    final capturedImage = ref.watch(capturedImageProvider);

    final result = scanResult ??
        ScanResult(
          itemName: 'Tidak dikenali',
          category: WasteCategory.lainnya,
          confidence: 0.0,
          description: '',
          disposalInfo: '',
        );

    // Background scale: Figma frame is 1194×834.
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
            _buildDot(left: 340 * bgScale, top: 120 * bgScale, color: const Color(0xFF4DA3FF), dotSize: 11 * bgScale, radius: 2),
            _buildDot(left: 760 * bgScale, top: 90 * bgScale, color: const Color(0xFFFFB02E), dotSize: 9 * bgScale, radius: 2),
            _buildDot(left: 1070 * bgScale, top: 180 * bgScale, color: const Color(0xFF3AD6A0), dotSize: 8 * bgScale, radius: 4),
            _buildDot(left: 120 * bgScale, top: 640 * bgScale, color: const Color(0xFFFF6B8A), dotSize: 10 * bgScale, radius: 2),
            _buildDot(left: 880 * bgScale, top: 690 * bgScale, color: const Color(0xFF7C5CFC), dotSize: 10 * bgScale, radius: 2),
          ],

          // ── Main content ──
          SafeArea(
            child: Center(
              child: isPortrait
                  ? _buildPortrait(context, size, result, capturedImage, ref)
                  : _buildLandscape(context, size, result, capturedImage, ref),
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
  Widget _buildPortrait(BuildContext context, Size size, ScanResult result,
      Uint8List? capturedImage, WidgetRef ref) {
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
          _buildRightPanel(context, size, result, ref, isPortrait: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LANDSCAPE (iPad) — Figma exact layout
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size, ScanResult result,
      Uint8List? capturedImage, WidgetRef ref) {
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
            child: _buildRightPanel(context, size, result, ref,
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
    final catColor = result.category.color;

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

              // "BARU" badge — Figma: top:14.4
              // bg tinted dark with category-color border
              Positioned(
                top: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 11 * scale,
                      right: 12 * scale,
                      top: 6 * scale,
                      bottom: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: _darken(catColor, 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13 * scale,
                          color: catColor.withValues(alpha: 0.9),
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          'BARU',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                            color: catColor.withValues(alpha: 0.95),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
                            color: catColor,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${result.category.name} ·',
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
                                  color: catColor,
                                  height: 1.4,
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

  /// Inner placeholder when no captured image: dark gradient with a soft
  /// category-tinted glow ellipse + the captured-photo icon (matches the
  /// Figma "image 17" placeholder illustration pattern).
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

  /// Returns a darkened version of [color] by mixing it with black at [amount].
  Color _darken(Color color, double amount) {
    return Color.lerp(color, const Color(0xFF000000), amount)!;
  }

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Figma: 520px col, gap:24
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext context, Size size, ScanResult result,
      WidgetRef ref, {required bool isPortrait, double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap24 = (24.0 * scale).clamp(12.0, 24.0);
    final gap16 = (16.0 * scale).clamp(8.0, 16.0);

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

        // 3. Dataset chip
        _buildDatasetChip(size, result, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 4. Buttons
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16 * scale),
          child: _buildButtonsRow(context, ref, size, scale: scale),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY + SPEECH BUBBLE — Figma: Biny 84×88.2, bubble white r22 p20/12
  // "Asik, aku nemu yang baru!"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final mascotSize = isPhone ? 60.0 : 84.0 * scale;
    final bubblePadH = isPhone ? 14.0 : 20.0 * scale;
    final bubblePadV = isPhone ? 8.0 : 12.0 * scale;
    final bubbleRadius = isPhone ? 16.0 : 22.0 * scale;
    final fontSize = isPhone ? 13.0 : 17.0 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BinyHero(size: mascotSize, expression: BinyExpression.conclusionNew),
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
                  'Asik, aku nemu yang baru!',
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
                        borderRadius: BorderRadius.only(
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
  // CATEGORY SECTION — Figma: label 17px SemiBold + name 58px ExtraBold
  // + "KATEGORI BARU" gradient badge + description 17px Medium
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCategorySection(Size size, ScanResult result,
      {double scale = 1.0, bool isPhone = false}) {
    final labelSize = isPhone ? 13.0 : 17.0 * scale;
    final catSize = isPhone ? 36.0 : 58.0 * scale;
    final descSize = isPhone ? 14.0 : 17.0 * scale;
    final badgeSize = isPhone ? 11.0 : 14.0 * scale;
    final gap16 = isPhone ? 8.0 : 16.0 * scale;
    final catColor = result.category.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          'Biny menyimpulkan ini',
          style: GoogleFonts.plusJakartaSans(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: gap16),
        // Name + KATEGORI BARU badge
        Row(
          children: [
            Flexible(
              child: Text(
                result.category.name,
                style: GoogleFonts.baloo2(
                  fontSize: catSize,
                  fontWeight: FontWeight.w800,
                  color: catColor,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(width: 16 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [AppColors.primary, Color(0xFF34D6E0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: isPhone ? 12 : 20,
                    offset: Offset(0, isPhone ? 4 : 8),
                  ),
                ],
              ),
              child: Text(
                'KATEGORI BARU',
                style: GoogleFonts.baloo2(
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap16),
        // Description
        SizedBox(
          width: isPhone ? double.infinity : 480.0 * scale,
          child: Text(
            'Belum ada di daftarku — jadi aku buat kategori baru biar lain kali langsung kenal.',
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
  // DATASET CHIP — Figma: 520×74, white, r18, shadow 0/6/16 rgba(41,31,89,.08)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDatasetChip(Size size, ScanResult result,
      {double scale = 1.0, bool isPhone = false}) {
    final cardW = isPhone ? double.infinity : 520.0 * scale;
    final padH = isPhone ? 14.0 : 16.0 * scale;
    final padV = isPhone ? 12.0 : 14.0 * scale;
    final titleSize = isPhone ? 14.0 : 16.0 * scale;
    final subSize = isPhone ? 11.0 : 13.0 * scale;
    final xpSize = isPhone ? 14.0 : 17.0 * scale;
    final iconBox = isPhone ? 36.0 : 46.0 * scale;
    final catColor = result.category.color;

    return Container(
      width: cardW,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPhone ? 14 : 18.0 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.08),
            blurRadius: isPhone ? 10 : 16,
            offset: Offset(0, isPhone ? 3 : 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(isPhone ? 10 : 13.0 * scale),
            ),
            child: Icon(
              Icons.storage_rounded,
              size: (isPhone ? 18 : 24) * scale,
              color: catColor,
            ),
          ),
          SizedBox(width: 13 * scale),
          // Texts
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ditambahkan ke dataset',
                  style: GoogleFonts.baloo2(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Folder baru "${result.category.name}" tersimpan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: subSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.4,
                    letterSpacing: 0.026,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          // +25 XP pill
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '+${SessionService.xpNewCategory} XP',
              style: GoogleFonts.baloo2(
                fontSize: xpSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF9A6A00),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS ROW — Figma: gap:12, flex 1 each, py:16
  // "Koreksi"(#EDE8FF, drop-shadow #DDD3FF) + "Lanjutkan"(#7C5CFC)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtonsRow(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap = isPhone ? 8.0 : 12.0 * scale;

    return Row(
      children: [
        Expanded(
          child: _buildKoreksiButton(context, ref, size, scale: scale),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _buildLanjutkanButton(context, ref, size, scale: scale),
        ),
      ],
    );
  }

  /// "Koreksi" — let the user manually pick the category.
  Widget _buildKoreksiButton(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;

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
              context.go('/manual-correction', extra: '/conclusion-new'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Koreksi',
                style: GoogleFonts.baloo2(
                  fontSize: isPhone ? 14 : 19.0 * scale,
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

  /// "Lanjutkan" — save to history + award XP + add scan, go to /dataset-saved.
  Widget _buildLanjutkanButton(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;

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
          onTap: () {
            ref.read(scanProvider.notifier).saveToHistory();
            ref.read(sessionProvider.notifier).addXP(SessionService.xpNewCategory);
            ref.read(sessionProvider.notifier).addScan();
            ref.read(bluetoothProvider.notifier).sendCloseAll();
            context.go('/dataset-saved');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Lanjutkan',
                style: GoogleFonts.baloo2(
                  fontSize: isPhone ? 14 : 19.0 * scale,
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
