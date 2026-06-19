import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Pixel-perfect match to Figma 226:2006 "18 · Manual Correction"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma):
/// - Background #FBFAFF with two LAYER_BLUR blobs (top-right & bottom-left)
/// - Top-left column (gap 24):
///   1. Top bar: back 54×54 r16 + title col + AI Guess badge (right)
///   2. Biny mascot + speech bubble (white, border 2px #EDE8FF)
/// - Centered grid (w:1073, gap:22) — 3 cols × 2 rows of category cards
///   Each card: white r32 px24/22 + 84×84 icon box + name + subtitle
///   Selected: border 2.5px #FFB02E + checkmark top-right (cat color)
///   AI guess: "TEBAKAN AI" pill top-right
/// - Buttons right-aligned: "Batal" + "Simpan Koreksi"
/// - Bottom-left hint: "Butuh bantuan? Yuk coba tanya AI Agent ku"
///   ("AI Agent" tinted #7C5CFC)
class ManualCorrectionScreen extends ConsumerStatefulWidget {
  const ManualCorrectionScreen({super.key});

  @override
  ConsumerState<ManualCorrectionScreen> createState() =>
      _ManualCorrectionScreenState();
}

class _ManualCorrectionScreenState
    extends ConsumerState<ManualCorrectionScreen> {
  WasteCategory? _selectedCategory;

  static const _categoryOrder = [
    WasteCategory.plastik,
    WasteCategory.kertas,
    WasteCategory.organik,
    WasteCategory.logam,
    WasteCategory.residu,
    WasteCategory.kaca,
  ];

  bool _isPhone(Size s) => s.shortestSide < 600;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size) || AppResponsive.isPhone(size);
    final scanResult = ref.watch(scanResultProvider);
    // Fallback ke contoh "Plastik · 94%" ketika preview via debug menu
    // (belum lewat flow scanning) supaya AI guess badge tetap terlihat.
    final aiCategory = scanResult?.category ?? WasteCategory.plastik;
    final aiConfidence = scanResult?.confidence ?? 0.94;
    final bgScale = (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ──
          if (!isPortrait) ...[
            Positioned(
              left: 860 * bgScale,
              top: -160 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(420 * bgScale, 420 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFF4DA3FF),
                    opacity: 0.18,
                    blurSigma: 110 * bgScale,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 120 * bgScale,
              top: 540 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(340 * bgScale, 340 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFFFFB02E),
                    opacity: 0.18,
                    blurSigma: 110 * bgScale,
                  ),
                ),
              ),
            ),
          ],

          // ── Main content ──
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPortrait ? 20 : 56,
                  vertical: isPortrait ? 12 : 28,
                ),
                child: isPortrait
                    ? _buildPortrait(
                        context, size, aiCategory, aiConfidence)
                    : _buildLandscape(
                        context, size, aiCategory, aiConfidence),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // PORTRAIT
  // ────────────────────────────────────────────────
  Widget _buildPortrait(BuildContext context, Size size,
      WasteCategory aiCategory, double aiConfidence) {
    final isPhone = _isPhone(size);
    final cols = isPhone ? 2 : 3;

    return Column(
      children: [
        _buildTopBar(context, size, aiCategory, aiConfidence,
            isPortrait: true),
        SizedBox(height: isPhone ? 8 : 12),
        _buildBinyBubble(size),
        if (isPhone) ...[
          const SizedBox(height: 8),
          _buildAiGuessChip(size, aiCategory, aiConfidence),
        ],
        SizedBox(height: isPhone ? 10 : 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildGrid(size, cols, aiCategory, isPhone: isPhone),
                SizedBox(height: isPhone ? 14 : 20),
                _buildButtons(context, size),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // LANDSCAPE
  // ────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size,
      WasteCategory aiCategory, double aiConfidence) {
    final isPhone = _isPhone(size);
    final cols = isPhone ? 2 : 3;

    return Column(
      children: [
        _buildTopBar(context, size, aiCategory, aiConfidence,
            isPortrait: false),
        SizedBox(height: AppResponsive.rs(size, 24).clamp(16.0, 28.0)),
        _buildBinyBubble(size),
        SizedBox(height: AppResponsive.rs(size, 28).clamp(20.0, 36.0)),
        Expanded(
          child: Center(
            child: _buildGrid(size, cols, aiCategory, isPhone: isPhone),
          ),
        ),
        SizedBox(height: AppResponsive.rs(size, 20).clamp(14.0, 24.0)),
        _buildButtons(context, size),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // GRID — Figma: 3 cols × 2 rows, gap 22, w:1073
  // ────────────────────────────────────────────────
  Widget _buildGrid(Size size, int cols, WasteCategory? aiCategory,
      {required bool isPhone}) {
    final gap = isPhone ? 10.0 : 22.0;
    final rows = <Widget>[];
    for (var r = 0; r < _categoryOrder.length; r += cols) {
      final rowChildren = <Widget>[];
      for (var c = 0; c < cols; c++) {
        final idx = r + c;
        if (idx >= _categoryOrder.length) break;
        rowChildren.add(
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: c < cols - 1 ? gap : 0,
                bottom: gap,
              ),
              child: _buildCard(
                size,
                _categoryOrder[idx],
                isAiGuess: _categoryOrder[idx] == aiCategory,
                isPhone: isPhone,
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: rowChildren));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  // ────────────────────────────────────────────────
  // TOP BAR
  // ────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Size size,
      WasteCategory aiCategory, double aiConfidence,
      {required bool isPortrait}) {
    final isPhone = _isPhone(size);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button — 54×54 r16 shadow 0/6/16 rgba(91,63,214,0.08)
        GestureDetector(
          onTap: () => context.go('/result'),
          child: Container(
            width: isPhone ? 44 : 54,
            height: isPhone ? 44 : 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: isPhone ? 22 : 24,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: isPhone ? 12 : 24),
        // Title column — 198px in Figma
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Koreksi Kategori',
                style: GoogleFonts.baloo2(
                  fontSize: isPhone ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 28 / 26,
                ),
              ),
              Text(
                'Bantu Biny pilih yang benar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isPhone ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        // AI Guess badge (tablet/landscape) — right aligned
        if (!isPhone) _buildAiGuessBadge(size, aiCategory, aiConfidence),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // AI GUESS UI — uses actual category PNG illustration (matches Figma imgImage10)
  // ────────────────────────────────────────────────
  Widget _buildAiGuessBadge(
      Size size, WasteCategory aiCategory, double aiConfidence) {
    return Container(
      padding: const EdgeInsets.only(
          left: 10, right: 16, top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Image.asset(
              _iconAssetFor(aiCategory),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TEBAKAN AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '${aiCategory.name} · ${(aiConfidence * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact chip shown on phone below the Biny bubble.
  Widget _buildAiGuessChip(
      Size size, WasteCategory aiCategory, double aiConfidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Image.asset(
              _iconAssetFor(aiCategory),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'TEBAKAN AI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${aiCategory.name} · ${(aiConfidence * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Maps category to PNG illustration asset (matches Figma's 84×84 image
  /// illustrations used in cat/* cards). Same set as detail_item_screen.
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
      case WasteCategory.kaca:
        return 'assets/images/page_5/auto.png';
      case WasteCategory.residu:
        return 'assets/images/page_5/residu.png';
      case WasteCategory.lainnya:
        return 'assets/images/page_5/residu.png';
    }
  }

  // ────────────────────────────────────────────────
  // BINY + BUBBLE — Figma: Biny 58×60.9 + bubble r22 px20/12 border 2 #EDE8FF
  // ────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size) {
    final isPhone = _isPhone(size);
    final mascotSize = isPhone ? 44.0 : 60.9;
    final padH = isPhone ? 14.0 : 20.0;
    final padV = isPhone ? 10.0 : 12.0;
    final radius = isPhone ? 18.0 : 22.0;
    final fontSize = isPhone ? 13.0 : 17.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BinyHero(
          size: mascotSize,
          expression: BinyExpression.manualCorrection,
        ),
        SizedBox(width: isPhone ? 8 : 16),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: padH, vertical: padV),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border.all(color: AppColors.primarySoft, width: 2),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'Sepertinya tebakanku kurang pas — pilih kategori yang benar ya.',
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
                              color: AppColors.primarySoft, width: 2),
                          bottom: BorderSide(
                              color: AppColors.primarySoft, width: 2),
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

  // ────────────────────────────────────────────────
  // CARD — Figma: 343×128 r32 px24/22 + 84×84 icon box + name 26 + subtitle 15
  // ────────────────────────────────────────────────
  Widget _buildCard(Size size, WasteCategory category,
      {required bool isAiGuess, required bool isPhone}) {
    final isSelected = _selectedCategory == category;
    final catColor = category.color;

    final iconBox = isPhone ? 48.0 : 84.0;
    final nameSize = isPhone ? 16.0 : 26.0;
    final subSize = isPhone ? 11.0 : 15.0;
    final padH = isPhone ? 12.0 : 24.0;
    final padV = isPhone ? 14.0 : 22.0;
    final gap = isPhone ? 10.0 : 18.0;
    final radius = isPhone ? 20.0 : 32.0;
    final chkSize = isPhone ? 24.0 : 28.0;
    final chkR = isPhone ? 12.0 : 14.0;
    final chkIconSize = isPhone ? 14.0 : 15.0;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: isSelected
              ? Border.all(color: AppColors.warning, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                  alpha: isSelected ? 0.16 : 0.08),
              blurRadius: isSelected ? 22 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Icon box — uses PNG illustration (matches Figma imgImage10..18)
                Container(
                  width: iconBox,
                  height: iconBox,
                  padding: EdgeInsets.all(iconBox * 0.08),
                  child: Image.asset(
                    _iconAssetFor(category),
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: gap),
                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.baloo2(
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: subSize,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Spacer for badge/checkmark on right
                if (isAiGuess && !isSelected || isSelected)
                  SizedBox(width: chkSize + 8),
              ],
            ),
            // "TEBAKAN AI" pill (top right) — only when AI guess and not selected
            if (isAiGuess && !isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EFFB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPhone ? 'AI' : 'TEBAKAN AI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isPhone ? 9 : 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            // Checkmark (top right) — when selected
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: chkSize,
                  height: chkSize,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(chkR),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: chkIconSize,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // BUTTONS — Figma: "Batal" #EDE8FF + "Simpan Koreksi" #7C5CFC
  // Hint "Butuh bantuan? Yuk coba tanya AI Agent ku" diletakkan
  // di kiri row tombol (sejajar secara vertikal) supaya tidak
  // terlalu menempel di bawah layar.
  // ────────────────────────────────────────────────
  Widget _buildButtons(BuildContext context, Size size) {
    final isPhone = _isPhone(size);
    final padH = isPhone ? 16.0 : 32.0;
    final padV = isPhone ? 14.0 : 20.0;
    final fontSize = isPhone ? 14.0 : 19.0;
    final gap = isPhone ? 10.0 : 12.0;

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BATAL
        Container(
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
              onTap: () => context.go('/result'),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                child: Text(
                  'Batal',
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
        SizedBox(width: gap),
        // SIMPAN KOREKSI
        Container(
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
              onTap: _selectedCategory != null
                  ? () async {
                      await ref
                          .read(scanProvider.notifier)
                          .correctResult(_selectedCategory!);
                      // Persist the corrected category to the on-device
                      // dataset. correctResult updates an existing entry
                      // in-place if one was already saved; this call covers
                      // the case where the user opened manual correction
                      // straight from /result (no prior saveToHistory).
                      await ref
                          .read(scanProvider.notifier)
                          .saveCorrectedToLocalDataset();
                      if (context.mounted) context.go('/dataset-saved');
                    }
                  : null,
              child: Opacity(
                opacity: _selectedCategory != null ? 1.0 : 0.5,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: padH, vertical: padV),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: isPhone ? 16 : 20,
                        color: Colors.white,
                      ),
                      SizedBox(width: isPhone ? 6 : 8),
                      Text(
                        'Simpan Koreksi',
                        style: GoogleFonts.baloo2(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.095,
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
    );

    // Bungkus hint + buttons dalam satu row — hint di kiri, tombol di kanan.
    // Hint sejajar secara vertikal dengan tombol (tidak menempel di bawah).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _buildHelpHint(context, isPhone ? 0.85 : 1.0)),
        buttons,
      ],
    );
  }

  // ────────────────────────────────────────────────
  // HELP HINT — "Butuh bantuan? Yuk coba tanya AI Agent ku"
  // Klik → navigasi ke halaman analyzing (AI Agent).
  // "AI Agent ku" semuanya diberi warna primary #7C5CFC.
  // ────────────────────────────────────────────────
  Widget _buildHelpHint(BuildContext context, double scale) {
    final fontSize = (13.0 * scale).clamp(11.0, 14.0);

    return GestureDetector(
      onTap: () => context.go('/analyzing'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text.rich(
          TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Butuh bantuan? Yuk coba tanya '),
              TextSpan(
                text: 'AI Agent ku',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
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
