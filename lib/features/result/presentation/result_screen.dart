import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/scan_result.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';
import '../../../core/providers/bluetooth_provider.dart';
import '../../detail_item/presentation/detail_item_screen.dart';

/// Pixel-perfect "08 · Result Detection"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma)
/// - Container at left:92, vertically centered, horizontal flex, gap:60
/// - Left: image card 430×430 (white, r32, shadow 0/18/44 rgba(41,31,89,.13))
///   - inner img 400×400 at (15,15), r22, gradient 111.8° #2B2843→#191731
///   - "TERDETEKSI" badge top:14, centered
///   - tag bottom: "Plastik · 0.94" top:352
/// - Right: 520px column, gap:24
///   1. Biny(84×88) + speech bubble (white, border 2px #EDE8FF, r22, p20/12)
///   2. "Sampah kamu termasuk"(17px SemiBold) → "Plastik"(58px ExtraBold) + "Lihat informasi"(16px)
///   3. Stats card 520×155 (white, r20)
///   4. Buttons "Pindai Lagi" + "Selesai" (19px, flex 1)
///   5. "Kategori kurang tepat? Koreksi manual" (15px)
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

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

    // Background scale: Figma frame is 1194×834. Scale blobs/dots with screen.
    final bgScale = (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ──
          // SOLID #4DA3FF @ 0.2, LAYER_BLUR 110, (-90,-150) 440×440
          // SOLID #FFB02E @ 0.2, LAYER_BLUR 110, (920,540) 360×360
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
          // Image card
          SizedBox(
            height: isPhone ? size.width * 0.75 : size.width * 0.5,
            width: isPhone ? size.width * 0.75 : size.width * 0.5,
            child: _buildImageCard(result, capturedImage, isPhone: isPhone),
          ),
          SizedBox(height: isPhone ? 20 : 32),
          // Right panel content (stacked vertically in portrait)
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
    // Scale factor: fit the Figma 430+60+520=1010px content width
    final availW = size.width - 92.0 - 92.0; // Figma container at left:92
    final scale = (availW / 1010.0).clamp(0.5, 1.0);
    final gap = 60.0 * scale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 92),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Image card 430×430 ──
          _buildImageCard(result, capturedImage, scale: scale),
          SizedBox(width: gap),
          // ── Right panel 520px ──
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
  // IMAGE CARD — 430×430, white, r32
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildImageCard(ScanResult result, Uint8List? capturedImage,
      {double scale = 1.0, bool isPhone = false}) {
    final cardSize = 430.0 * scale;
    final innerSize = 400.0 * scale;
    final pad = 15.0 * scale;
    final cardRadius = 32.0 * scale;
    final innerRadius = 22.0 * scale;

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
            borderRadius:
                BorderRadius.circular(isPhone ? 18.0 : innerRadius),
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
              // Captured image
              if (capturedImage != null)
                Image.memory(capturedImage, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: (isPhone ? 28 : 48) * scale,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

              // "TERDETEKSI" badge — top:14
              Positioned(
                top: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 11 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18 * scale,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 7 * scale),
                        Text(
                          'TERDETEKSI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom tag "Plastik · 0.94"
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
                            color: result.category.color,
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
                                  color: AppColors.success,
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

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — 520px col, gap:24
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
        // 1. Biny + Speech bubble
        _buildBinyBubble(size, result, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 2. Category section
        _buildCategorySection(context, size, result, scale: scale),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 3. Stats card
        _buildStatsCard(size, result, scale: scale),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 4. Buttons
        _buildButtonsRow(context, ref, size, scale: scale),
        SizedBox(height: (16.0 * scale).clamp(8.0, 16.0)),

        // 5. Koreksi link
        _buildKoreksiLink(context, size, scale: scale),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY + SPEECH BUBBLE
  // Biny 84×88.2, bubble white border 2px #EDE8FF r22 p20/12
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size, ScanResult result,
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
        BinyHero(size: mascotSize, expression: BinyExpression.result),
        // Speech bubble with tail
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
                  'Berhasil dikenali!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Bubble tail — small triangle pointing left
              Positioned(
                left: -7,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398, // 45 degrees
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
  // CATEGORY SECTION
  // "Sampah kamu termasuk"(17px SemiBold) + "Plastik"(58px ExtraBold)
  // + "Lihat informasi"(16px ExtraBold) + arrow
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCategorySection(BuildContext context, Size size,
      ScanResult result, {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final labelSize = isPhone ? 13.0 : 17.0 * scale;
    final catSize = isPhone ? 36.0 : 58.0 * scale;
    final linkSize = isPhone ? 12.0 : 16.0 * scale;
    final gap16 = isPhone ? 8.0 : 16.0 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sampah kamu termasuk',
          style: GoogleFonts.plusJakartaSans(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: gap16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                result.category.name,
                style: GoogleFonts.baloo2(
                  fontSize: catSize,
                  fontWeight: FontWeight.w800,
                  color: result.category.color,
                  height: 1.0,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => DetailItemScreen.show(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat informasi',
                    style: GoogleFonts.baloo2(
                      fontSize: linkSize,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18 * scale,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // STATS CARD — 520×155, white, r20
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStatsCard(Size size, ScanResult result, {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final cardW = isPhone ? double.infinity : 520.0 * scale;
    final pad = isPhone ? 14.0 : 20.0 * scale;

    return Container(
      width: cardW,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20.0 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.08),
            blurRadius: isPhone ? 10 : 16,
            offset: Offset(0, isPhone ? 3 : 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: "Tingkat keyakinan AI" + "94%"
          Row(
            children: [
              Text(
                'Tingkat keyakinan AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isPhone ? 12 : 15.0 * scale,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                result.confidencePercent,
                style: GoogleFonts.baloo2(
                  fontSize: isPhone ? 18 : 22.0 * scale,
                  fontWeight: FontWeight.w800,
                  color: result.category.color,
                ),
              ),
            ],
          ),
          SizedBox(height: isPhone ? 10 : 12 * scale),
          // Progress bar — track #EDE8FF 480×13, fill gradient
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: isPhone ? 10 : 13.0 * scale,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: result.confidence.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            result.category.color.withValues(alpha: 0.7),
                            result.category.color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isPhone ? 10 : 12 * scale),
          // Divider — #ECE9F7
          Container(
            height: 1,
            color: AppColors.border,
          ),
          SizedBox(height: isPhone ? 10 : 12 * scale),
          // XP reward row
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 10 : 14.0 * scale,
                  vertical: isPhone ? 5 : 7.0 * scale,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+10 XP',
                  style: GoogleFonts.baloo2(
                    fontSize: isPhone ? 14 : 18.0 * scale,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9A6A00),
                  ),
                ),
              ),
              SizedBox(width: isPhone ? 10 : 13.0 * scale),
              Expanded(
                child: Text(
                  'Ditambahkan ke poin kamu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isPhone ? 12 : 15.0 * scale,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS ROW — gap:12, flex 1 each
  // "Pindai Lagi"(#EDE8FF, drop-shadow #DDD3FF) + "Selesai"(#7C5CFC)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtonsRow(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap = isPhone ? 8.0 : 12.0 * scale;

    return Row(
      children: [
        Expanded(
          child: _buildScanAgainButton(context, ref, size, scale: scale),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _buildSelesaiButton(context, size, ref, scale: scale),
        ),
      ],
    );
  }

  /// "Pindai Lagi" — kembali ke kamera live (Phase 0) supaya user bisa
  /// memotret ulang benda baru. Flag [useGeminiProvider] tetap diset;
  /// ia akan dikonsumsi [ScanningScreen._runClassification] setelah foto
  /// baru di-capture & dikonfirmasi.
  ///
  /// PENTING: jangan set [rescanProvider] = true di sini — flag itu bikin
  /// scanning_screen skip kamera dan langsung re-run AI di foto lama
  /// (itulah path "scanning ulang" yang ingin dihindari).
  void _onPindaiLagiTapped(BuildContext context, WidgetRef ref) {
    ref.read(useGeminiProvider.notifier).state = true;
    ref.read(rescanProvider.notifier).state = false;
    context.go('/scanning');
  }

  Widget _buildScanAgainButton(BuildContext context, WidgetRef ref, Size size,
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
          onTap: () => _onPindaiLagiTapped(context, ref),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Pindai Lagi',
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

  Widget _buildSelesaiButton(BuildContext context, Size size, WidgetRef ref,
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
            ref
                .read(sessionProvider.notifier)
                .addXP(SessionService.xpExistingCategory);
            ref.read(sessionProvider.notifier).addScan();
            ref.read(bluetoothProvider.notifier).sendCloseAll();
            context.go('/feedback');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Selesai',
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

  // ─────────────────────────────────────────────────────────────────────
  // KOREKSI LINK "Kategori kurang tepat? Koreksi manual"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildKoreksiLink(BuildContext context, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final fontSize = isPhone ? 12.0 : 15.0 * scale;

    return GestureDetector(
      onTap: () => context.go('/manual-correction', extra: '/result'),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
          children: [
            const TextSpan(text: 'Kategori kurang tepat? '),
            TextSpan(
              text: 'Koreksi manual',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a blurred solid-color ellipse — replicates Figma's SOLID fill +
/// LAYER_BLUR effect exactly.
///
/// Figma uses a solid-color ellipse with a gaussian layer blur. This painter
/// draws a filled ellipse with [MaskFilter.blur] to reproduce that, producing
/// a brighter, more saturated glow than a RadialGradient would.
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
