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
import '../../../core/providers/bluetooth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';
import '../../detail_item/presentation/detail_item_screen.dart';

/// Pixel-perfect match to Figma 226:3428 "09 · Multi-Result (Mixed Waste)"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma):
/// - Container centered horizontally, horizontal flex, gap:60
/// - Left: image card 430×430 + dot indicators (gap:16)
/// - Right: 560px column, gap:24
///   1. Biny (82×86.1) + speech bubble "Banyak yang kena sekaligus!"
///   2. "3 terdeteksi" (30px) + MIXED WASTE pill + XP pill + description
///   3. Item cards list (gap:16, each 86px)
///   4. Buttons "Pindai Lagi" + "Selesai" (gap:12)
class MultiResultScreen extends ConsumerStatefulWidget {
  const MultiResultScreen({super.key});

  @override
  ConsumerState<MultiResultScreen> createState() => _MultiResultScreenState();
}

class _MultiResultScreenState extends ConsumerState<MultiResultScreen> {
  int _selectedIndex = 0;

  static const double _readableThreshold = 0.65;
  static const double _unsureThreshold = 0.45;

  // Read multi-results DIRECTLY from the ScanNotifier instead of via
  // `multiResultsProvider`. The Provider caches its value on first read
  // (it uses ref.read internally, so it doesn't re-subscribe to notifier
  // mutations), which means when the user taps "Pindai Lagi" on this
  // screen → scanning → routes back here, the cached Provider would still
  // return the PREVIOUS TFLite/RT-DETR results instead of the new Gemini
  // ones. Reading from the notifier each time bypasses that cache.
  List<ScanResult> get results => ref.read(scanProvider.notifier).multiResults;

  _ResultType _resultType(ScanResult r) {
    if (r.confidence < _unsureThreshold || r.category == WasteCategory.lainnya) {
      return _ResultType.unknown;
    }
    if (r.confidence < _readableThreshold) return _ResultType.unsure;
    return _ResultType.readable;
  }

  int get _readableCount =>
      results.where((r) => _resultType(r) == _ResultType.readable).length;
  int get _unknownCount =>
      results.where((r) => _resultType(r) == _ResultType.unknown).length;
  int get _unsureCount =>
      results.where((r) => _resultType(r) == _ResultType.unsure).length;
  int get _needCheckCount => _unknownCount + _unsureCount;

  int _itemXP(ScanResult r) {
    if (r.confidence >= 0.80) return 12;
    if (r.confidence >= _readableThreshold) return 10;
    if (r.confidence >= _unsureThreshold) return 8;
    return 0;
  }

  int get _totalXP => results.fold(0, (sum, r) => sum + _itemXP(r));

  String get _speechText {
    if (_needCheckCount == 0) return 'Banyak yang kena sekaligus!';
    if (_readableCount > _needCheckCount) {
      return 'Hampir semua kebaca — sebagian perlu dicek dulu.';
    }
    return 'Ada yang belum dikenali. Coba pindai lagi ya!';
  }

  String get _headerText {
    if (_needCheckCount > 0) {
      return '$_needCheckCount perlu dicek';
    }
    return 'terdeteksi';
  }

  String get _headerNumber {
    if (_needCheckCount > 0) return '$_needCheckCount ';
    return '${results.length} ';
  }

  void _selectObject(int i) {
    if (i >= 0 && i < results.length) setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    final capturedImage = ref.watch(capturedImageProvider);
    final bgScale = (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs — Figma 226:3429, 226:3430 ──
          // 226:3429: SOLID #4DA3FF @ 0.2, LAYER_BLUR 110, (-90,-150) 440×440
          // 226:3430: SOLID #FFB02E @ 0.2, LAYER_BLUR 110, (920,540) 360×360
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
            // ── Decorative dots — Figma 226:3431-3435 ──
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
                  ? _buildPortrait(context, size, capturedImage)
                  : _buildLandscape(context, size, capturedImage),
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
  Widget _buildPortrait(BuildContext context, Size size, Uint8List? img) {
    final isPhone = AppResponsive.isPhone(size);
    final scale = isPhone ? (size.width / 390.0).clamp(0.4, 1.0) : 1.0;
    final imageHeight = isPhone
        ? (size.height * 0.22).clamp(140.0, 200.0)
        : (size.height * 0.30).clamp(180.0, 260.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 16 : 24,
        vertical: isPhone ? 12 : 20,
      ),
      child: Column(
        children: [
          SizedBox(
            height: imageHeight,
            child: _buildImagePreviewPortrait(size, img, isPhone: isPhone),
          ),
          SizedBox(height: isPhone ? 12 : 16),
          // Dot indicators
          if (results.length > 1) _buildDotIndicators(isPhone: isPhone, scale: scale),
          SizedBox(height: isPhone ? 16 : 24),
          // Right panel — fills remaining space so the item list scrolls
          // internally and the buttons stay visible without overflowing.
          Expanded(
            child: _buildRightPanel(context, size, isPortrait: true, scale: scale),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LANDSCAPE (iPad) — Figma exact layout
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size, Uint8List? img) {
    // Scale factor: fit Figma 430+60+560=1050px content width
    final availW = size.width - 184.0; // ~92px margins each side
    final scale = (availW / 1050.0).clamp(0.5, 1.0);
    final gap = 60.0 * scale;
    final leftColW = 430.0 * scale;
    final rightColW = 560.0 * scale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 92),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left column: image card + dot indicators ──
          SizedBox(
            width: leftColW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImageCard(size, img, scale: scale),
                SizedBox(height: 16 * scale),
                if (results.length > 1)
                  _buildDotIndicators(scale: scale, isPhone: false),
              ],
            ),
          ),
          SizedBox(width: gap),
          // ── Right column ──
          SizedBox(
            width: rightColW,
            child: _buildRightPanel(context, size,
                isPortrait: false, scale: scale),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // IMAGE CARD — Figma 226:3437: 430×430 white r32
  //   inner img 400×400 (15,15) r22 gradient #2B2843 → #191731
  //   4 corner brackets #3AD6A0 3.5px border 26×26
  //   TERDETEKSI badge top:14 center
  //   tag pill bottom:14 center "Plastik · 0.94"
  //   nav chevrons left/right 42×42 white-translucent r999
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildImageCard(Size size, Uint8List? capturedImage,
      {double scale = 1.0}) {
    final cardSize = 430.0 * scale;
    final innerSize = 400.0 * scale;
    final pad = 15.0 * scale;
    final cardRadius = 32.0 * scale;
    final innerRadius = 22.0 * scale;

    final hasResults = results.isNotEmpty;
    final selected =
        hasResults ? results[_selectedIndex.clamp(0, results.length - 1)] : null;
    final displayImage = selected?.croppedImage ?? capturedImage;

    return Container(
      width: cardSize,
      height: cardSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF291F59).withValues(alpha: 0.13),
            blurRadius: 44 * scale,
            offset: Offset(0, 18 * scale),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
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
              if (displayImage != null)
                Image.memory(displayImage, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 48 * scale,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

              // ── Corner brackets — Figma 226:3441-3444 ──
              // 26×26, #3AD6A0 3.5px border, position at corners of inner img
              _buildCornerBracket(
                top: 12 * scale,
                left: 12 * scale,
                isTopLeft: true,
                scale: scale,
              ),
              _buildCornerBracket(
                top: 12 * scale,
                right: 12 * scale,
                isTopRight: true,
                scale: scale,
              ),
              _buildCornerBracket(
                bottom: 12 * scale,
                left: 12 * scale,
                isBottomLeft: true,
                scale: scale,
              ),
              _buildCornerBracket(
                bottom: 12 * scale,
                right: 12 * scale,
                isBottomRight: true,
                scale: scale,
              ),

              // ── "TERDETEKSI" badge — Figma 226:3445: top:14 center ──
              Positioned(
                top: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 8 * scale,
                      right: 11 * scale,
                      top: 6 * scale,
                      bottom: 6 * scale,
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

              // ── Tag pill bottom — Figma 226:3450 ──
              if (selected != null)
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
                              color: selected.category.color,
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${selected.category.name} ·',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '  ${selected.confidence.toStringAsFixed(2)}',
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

              // ── Nav chevron left — Figma 226:3561: 42×42 ──
              if (results.length > 1)
                Positioned(
                  left: 12 * scale,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _selectObject(
                        (_selectedIndex - 1).clamp(0, results.length - 1),
                      ),
                      child: Container(
                        width: 42 * scale,
                        height: 42 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 22 * scale,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Nav chevron right — Figma 226:3565: 42×42 ──
              if (results.length > 1)
                Positioned(
                  right: 12 * scale,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _selectObject(
                        (_selectedIndex + 1).clamp(0, results.length - 1),
                      ),
                      child: Container(
                        width: 42 * scale,
                        height: 42 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 22 * scale,
                        ),
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

  /// Corner bracket — L-shaped border, 26×26, #3AD6A0 3.5px border.
  /// Figma 226:3441-3444.
  Widget _buildCornerBracket({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
    double scale = 1.0,
  }) {
    final sz = 26.0 * scale;
    final bw = 3.5 * scale;
    final br1 = 12.0 * scale; // outer corner
    final br2 = 4.0 * scale; // inner corners

    BorderRadius borderRadius;
    if (isTopLeft) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(br1),
        topRight: Radius.circular(br2),
        bottomLeft: Radius.circular(br2),
        bottomRight: Radius.circular(br2),
      );
    } else if (isTopRight) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(br2),
        topRight: Radius.circular(br1),
        bottomLeft: Radius.circular(br2),
        bottomRight: Radius.circular(br2),
      );
    } else if (isBottomLeft) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(br2),
        topRight: Radius.circular(br2),
        bottomLeft: Radius.circular(br1),
        bottomRight: Radius.circular(br2),
      );
    } else {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(br2),
        topRight: Radius.circular(br2),
        bottomLeft: Radius.circular(br2),
        bottomRight: Radius.circular(br1),
      );
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            border: Border(
              top: isTopLeft || isTopRight
                  ? BorderSide(color: AppColors.success, width: bw)
                  : BorderSide.none,
              bottom: isBottomLeft || isBottomRight
                  ? BorderSide(color: AppColors.success, width: bw)
                  : BorderSide.none,
              left: isTopLeft || isBottomLeft
                  ? BorderSide(color: AppColors.success, width: bw)
                  : BorderSide.none,
              right: isTopRight || isBottomRight
                  ? BorderSide(color: AppColors.success, width: bw)
                  : BorderSide.none,
            ),
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // IMAGE PREVIEW (portrait)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildImagePreviewPortrait(Size size, Uint8List? capturedImage,
      {required bool isPhone}) {
    final hasResults = results.isNotEmpty;
    final selected =
        hasResults ? results[_selectedIndex.clamp(0, results.length - 1)] : null;
    final displayImage = selected?.croppedImage ?? capturedImage;
    final borderRadius = isPhone ? 18.0 : 24.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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
          if (displayImage != null)
            Image.memory(displayImage, fit: BoxFit.cover)
          else
            Center(
              child: Icon(
                Icons.camera_alt_rounded,
                size: isPhone ? 28 : 48,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),

          // TERDETEKSI badge
          Positioned(
            top: isPhone ? 8 : 12,
            right: isPhone ? 8 : 12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 6 : 10,
                vertical: isPhone ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: isPhone ? 10 : 14,
                    color: AppColors.success,
                  ),
                  SizedBox(width: isPhone ? 2 : 4),
                  Text(
                    'TERDETEKSI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isPhone ? 8 : 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nav arrows
          if (results.length > 1) ...[
            Positioned(
              left: isPhone ? 4 : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _selectObject(
                    (_selectedIndex - 1).clamp(0, results.length - 1),
                  ),
                  child: Container(
                    width: isPhone ? 24 : 32,
                    height: isPhone ? 24 : 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: isPhone ? 16 : 22,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: isPhone ? 4 : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _selectObject(
                    (_selectedIndex + 1).clamp(0, results.length - 1),
                  ),
                  child: Container(
                    width: isPhone ? 24 : 32,
                    height: isPhone ? 24 : 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: isPhone ? 16 : 22,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Bottom tag
          if (selected != null)
            Positioned(
              bottom: isPhone ? 10 : 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPhone ? 8 : 12,
                    vertical: isPhone ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0A14).withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isPhone ? 6 : 8,
                        height: isPhone ? 6 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected.category.color,
                        ),
                      ),
                      SizedBox(width: isPhone ? 4 : 6),
                      Text(
                        '${selected.category.name}  ${selected.confidence.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isPhone ? 10 : 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // DOT INDICATORS — Figma 226:3551: gap:8
  //   active: 26×9 #7C5CFC r999
  //   inactive: 9×9 #E0D9F7 r999
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDotIndicators({double scale = 1.0, required bool isPhone}) {
    if (results.isEmpty) return const SizedBox.shrink();
    final activeW = ((isPhone ? 18.0 : 26.0) * scale);
    final dotSz = ((isPhone ? 7.0 : 9.0) * scale);
    final gap = ((isPhone ? 6.0 : 8.0) * scale);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(results.length, (i) {
        final isActive = i == _selectedIndex;
        return GestureDetector(
          onTap: () => _selectObject(i),
          child: Container(
            width: isActive ? activeW : dotSz,
            height: dotSz,
            margin: EdgeInsets.symmetric(horizontal: gap / 2),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : const Color(0xFFE0D9F7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Figma 226:3453: 560px col, gap:24
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext context, Size size,
      {required bool isPortrait, double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap24 = isPortrait
        ? (isPhone ? 12.0 : 18.0)
        : (24.0 * scale).clamp(12.0, 24.0);

    final cardH = (isPhone ? 76.0 : 86.0) * scale;
    final itemGap = isPortrait ? (isPhone ? 8.0 : 12.0) : 16.0 * scale;

    // Shared items-list builder.
    Widget buildItems() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < results.length; i++) ...[
              _buildItemCard(context, size, results[i], i,
                  scale: scale, isPhone: isPhone),
              if (i < results.length - 1) SizedBox(height: itemGap),
            ],
          ],
        );

    // Portrait: items section expands to fill remaining vertical space so
    // the screen never overflows; items scroll inside, buttons stay fixed.
    // Landscape: items bounded to ~3 visible cards, compact & centered.
    final Widget itemsSection;
    if (isPortrait) {
      itemsSection = Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: buildItems(),
        ),
      );
    } else {
      final itemsMaxCards = 3;
      final itemsMaxH = itemsMaxCards * cardH + (itemsMaxCards - 1) * itemGap;
      itemsSection = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: itemsMaxH),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: buildItems(),
        ),
      );
    }

    return Column(
      mainAxisSize: isPortrait ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Biny + speech bubble — Figma 226:3454
        _buildBinyBubble(size, scale: scale, isPhone: isPhone),
        SizedBox(height: gap24),

        // 2. Header row — Figma 226:3603
        _buildHeader(size, scale: scale, isPhone: isPhone),
        SizedBox(height: gap24),

        // 3. Item cards list — Figma 226:3628
        itemsSection,

        SizedBox(height: gap24),

        // 4. Buttons — Figma 226:3511
        _buildButtonsRow(context, size, scale: scale, isPhone: isPhone),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY + SPEECH BUBBLE — Figma 226:3454
  //   Biny 82×86.1, bubble white border 2px #EDE8FF r22 p20/12
  //   Text: PJS Bold 17px #2B2A45
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final mascotW = (isPhone ? 56.0 : 82.0) * scale;
    final bubblePadH = (isPhone ? 14.0 : 20.0) * scale;
    final bubblePadV = (isPhone ? 8.0 : 12.0) * scale;
    final bubbleRadius = (isPhone ? 16.0 : 22.0) * scale;
    final fontSize = (isPhone ? 13.0 : 17.0) * scale;
    final gap = (isPhone ? 10.0 : 16.0) * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BinyHero(
          size: mascotW,
          expression: BinyExpression.multiResult,
        ),
        SizedBox(width: gap),
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
                      color: const Color(0xFF5B3FD6).withValues(alpha: 0.08),
                      blurRadius: isPhone ? 10 : 18,
                      offset: Offset(0, isPhone ? 3 : 6),
                    ),
                  ],
                ),
                child: Text(
                  _speechText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Bubble tail pointing left
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
  // HEADER — Figma 226:3603: w:560
  //   Row 1: "3 terdeteksi" (30px) + MIXED WASTE pill + XP pill (gap:12)
  //   Row 2: "XP tiap kategori mengikuti tingkat keyakinan AI." (16px)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader(Size size, {double scale = 1.0, bool isPhone = false}) {
    final titleFS = (isPhone ? 22.0 : 30.0) * scale;
    final titleLH = (isPhone ? 26.0 : 34.0) * scale;
    final mwFS = (isPhone ? 10.0 : 13.0) * scale;
    final mwPadH = (isPhone ? 7.0 : 9.0) * scale;
    final mwPadV = (isPhone ? 2.0 : 3.0) * scale;
    final mwRadius = (isPhone ? 5.0 : 7.0) * scale;
    final xpFS = (isPhone ? 13.0 : 18.0) * scale;
    final xpPadH = (isPhone ? 9.0 : 13.0) * scale;
    final xpPadV = (isPhone ? 4.0 : 6.0) * scale;
    final descFS = (isPhone ? 12.0 : 16.0) * scale;
    final gap12 = (isPhone ? 8.0 : 12.0) * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1
        Row(
          children: [
            // Title + MIXED WASTE pill (flex-1)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _headerNumber,
                            style: GoogleFonts.baloo2(
                              fontSize: titleFS,
                              fontWeight: FontWeight.w800,
                              color: _needCheckCount > 0
                                  ? AppColors.warning
                                  : AppColors.primary,
                              height: titleLH / titleFS,
                            ),
                          ),
                          TextSpan(
                            text: _headerText,
                            style: GoogleFonts.baloo2(
                              fontSize: titleFS,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: titleLH / titleFS,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: gap12),
                  // MIXED WASTE pill — Figma 226:3675: bg #EDE8FF r7 p9/3
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: mwPadH,
                      vertical: mwPadV,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(mwRadius),
                    ),
                    child: Text(
                      'MIXED WASTE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: mwFS,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryPress,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: gap12),
            // +XP pill — Figma 226:3609: bg #FFF2D9 r999 p13/6
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: xpPadH,
                vertical: xpPadV,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+$_totalXP XP',
                style: GoogleFonts.baloo2(
                  fontSize: xpFS,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A6A00),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: (isPhone ? 6 : 12.0) * scale),
        // Row 2: description
        Text(
          'XP tiap kategori mengikuti tingkat keyakinan AI.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: descFS,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // ITEM CARD — Figma 226:3629 (readable), 226:3642, 226:3655
  //   86px tall, white, r20, p18/16, gap:16
  //   - 54×54 image
  //   - name (Baloo 2 Bold 21px) + subtitle (PJS SemiBold 14px #908DAC)
  //   - +XP pill (15px #9A6A00)
  //   - % (Baloo 2 ExtraBold 18px) + 72×7 progress bar
  //   - chevron-right 22×22
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildItemCard(
    BuildContext ctx,
    Size size,
    ScanResult result,
    int index, {
    double scale = 1.0,
    bool isPhone = false,
  }) {
    final type = _resultType(result);
    final xp = _itemXP(result);
    final confPct = (result.confidence * 100).round();
    final cat = result.category;

    // Card sizing
    final cardH = (isPhone ? 76.0 : 86.0) * scale;
    final padH = (isPhone ? 14.0 : 18.0) * scale;
    final padV = (isPhone ? 12.0 : 16.0) * scale;
    final gap = (isPhone ? 12.0 : 16.0) * scale;
    final imgSz = (isPhone ? 44.0 : 54.0) * scale;
    final imgR = (isPhone ? 10.0 : 12.0) * scale;

    // Text sizes
    final nameFS = (isPhone ? 17.0 : 21.0) * scale;
    final subFS = (isPhone ? 11.0 : 14.0) * scale;
    final xpFS = (isPhone ? 12.0 : 15.0) * scale;
    final xpPadH = (isPhone ? 9.0 : 13.0) * scale;
    final xpPadV = (isPhone ? 5.0 : 7.0) * scale;
    final pctFS = (isPhone ? 14.0 : 18.0) * scale;
    final barW = (isPhone ? 56.0 : 72.0) * scale;
    final barH = (isPhone ? 5.0 : 7.0) * scale;
    final chevSz = (isPhone ? 18.0 : 22.0) * scale;
    final cardR = (isPhone ? 16.0 : 20.0) * scale;

    final categoryImageAsset = _categoryImageAsset(cat);

    return GestureDetector(
      onTap: () {
        ref.read(selectedDetailIndexProvider.notifier).state = index;
        DetailItemScreen.show(ctx);
      },
      child: Container(
        width: double.infinity,
        height: cardH,
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cardR),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B3FD6).withValues(alpha: 0.08),
              blurRadius: isPhone ? 8 : 18,
              offset: Offset(0, isPhone ? 3 : 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon — matches category-select page exactly
            // (uses the same PNG illustrations from assets/images/page_5/)
            categoryImageAsset != null
                ? Image.asset(
                    categoryImageAsset,
                    width: imgSz,
                    height: imgSz,
                    fit: BoxFit.contain,
                  )
                : Container(
                    width: imgSz,
                    height: imgSz,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(imgR),
                      color: cat.color.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Icon(
                        cat.icon,
                        size: imgSz * 0.5,
                        color: cat.color,
                      ),
                    ),
                  ),
            SizedBox(width: gap),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.itemName,
                    style: GoogleFonts.baloo2(
                      fontSize: nameFS,
                      fontWeight: FontWeight.w700,
                      color: type == _ResultType.unknown
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.0 * scale),
                  Text(
                    _cardSubtitle(type, result),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: subFS,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: gap),

            // +XP pill
            if (xp > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: xpPadH,
                  vertical: xpPadV,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$xp XP',
                  style: GoogleFonts.baloo2(
                    fontSize: xpFS,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9A6A00),
                  ),
                ),
              ),
            SizedBox(width: gap),

            // Confidence % + bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$confPct%',
                  style: GoogleFonts.baloo2(
                    fontSize: pctFS,
                    fontWeight: FontWeight.w800,
                    color: type == _ResultType.readable
                        ? cat.color
                        : (type == _ResultType.unsure
                            ? AppColors.warning
                            : AppColors.primary),
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 5 * scale),
                SizedBox(
                  width: barW,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: barH,
                      child: LinearProgressIndicator(
                        value: result.confidence.clamp(0.0, 1.0),
                        minHeight: barH,
                        backgroundColor: cat.color.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          type == _ResultType.readable
                              ? cat.color
                              : (type == _ResultType.unsure
                                  ? AppColors.warning
                                  : AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: gap),

            // Chevron right
            if (type == _ResultType.readable)
              Icon(
                Icons.chevron_right_rounded,
                size: chevSz,
                color: AppColors.textMuted,
              ),
          ],
        ),
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

  String _cardSubtitle(_ResultType type, ScanResult r) {
    switch (type) {
      case _ResultType.readable:
        return '${r.category.subtitle.toLowerCase()} · 1 item';
      case _ResultType.unknown:
        final pct = (r.confidence * 100).round();
        return 'Belum dikenali · keyakinan $pct%';
      case _ResultType.unsure:
        final pct = (r.confidence * 100).round();
        return 'Keyakinan rendah: $pct%';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS ROW — Figma 226:3511: gap:12, padding-y:16
  //   "Pindai Lagi" (#EDE8FF drop-shadow #DDD3FF) + "Selesai" (#7C5CFC)
  //   Text 19px Bold ls 0.095px
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtonsRow(BuildContext ctx, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final gap = (isPhone ? 8.0 : 12.0) * scale;

    return Row(
      children: [
        Expanded(child: _buildPindaiLagiButton(ctx, size, scale: scale, isPhone: isPhone)),
        SizedBox(width: gap),
        Expanded(child: _buildSelesaiButton(ctx, size, scale: scale, isPhone: isPhone)),
      ],
    );
  }

  Widget _buildPindaiLagiButton(BuildContext ctx, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = (isPhone ? 16.0 : 32.0) * scale;
    final padV = (isPhone ? 14.0 : 20.0) * scale;

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
          onTap: () {
            // Flag the next classification to use the Gemini cloud API —
            // same behavior as ResultScreen's "Pindai Lagi". Scanning screen
            // reads useGeminiProvider and routes mixed mode through Gemini's
            // multi-item classifier instead of the on-device TFLite/RT-DETR
            // pipeline.
            ref.read(useGeminiProvider.notifier).state = true;
            ref.read(rescanProvider.notifier).state = true;
            ctx.go('/scanning');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Pindai Lagi',
                style: GoogleFonts.baloo2(
                  fontSize: (isPhone ? 14 : 19.0) * scale,
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

  Widget _buildSelesaiButton(BuildContext ctx, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = (isPhone ? 16.0 : 32.0) * scale;
    final padV = (isPhone ? 14.0 : 20.0) * scale;

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
            ref.read(bluetoothProvider.notifier).sendCloseAll();
            ref.read(sessionProvider.notifier).addToHistory(results);
            ref.read(sessionProvider.notifier).addXP(_totalXP);
            ref.read(sessionProvider.notifier).addScan();
            // Persist each (possibly user-corrected) item to the on-device
            // dataset. Each item is saved with its own croppedImage so future
            // scans match it individually.
            ref
                .read(scanProvider.notifier)
                .saveMultiToLocalDataset(results);
            ctx.go('/feedback');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Selesai',
                style: GoogleFonts.baloo2(
                  fontSize: (isPhone ? 14 : 19.0) * scale,
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

enum _ResultType { readable, unsure, unknown }

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
