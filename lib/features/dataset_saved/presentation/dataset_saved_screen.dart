import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/category_option.dart';
import '../../../core/models/scan_result.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/category_options_provider.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';
import '../../../core/providers/bluetooth_provider.dart';

/// Pixel-perfect "15 · Dataset Saved"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma)
/// - Background #FBFAFF with two LAYER_BLUR blobs + 5 decorative dots (0.6 alpha)
/// - Centered column w:751, gap:24
///   1. Eyebrow pill (green): 20×20 box check + "TERSIMPAN KE DATASET"
///   2. Biny celebrate 128×134.4
///   3. Title "Biny jadi makin pintar!" 46px ExtraBold #2b2a45 line 1.08
///   4. Subtitle 18px Medium #5c5980 w:560 line 1.5: "Kategori baru [Cat]
///      sudah masuk ke pengetahuan Biny — lain kali langsung dikenali."
///   5. Category chips row gap:12 (6 chips, active = detected with "BARU" pill)
///   6. "Sekarang Biny mengenali 6 jenis sampah" 15px SemiBold #908dac
///   7. Buttons row gap:12 (w:240 each):
///      "Pindai Lagi" (#EDE8FF drop-shadow #DDD3FF) + "Selesai" (#7C5CFC)
class DatasetSavedScreen extends ConsumerWidget {
  const DatasetSavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final scanResult = ref.watch(scanResultProvider);
    final detectedCategory = scanResult?.category ?? WasteCategory.lainnya;

    // Background scale: Figma frame is 1194×834.
    final bgScale = (size.width / 1194.0).clamp(0.5, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ──
          if (!isPortrait) ...[
            Positioned(
              left: -69 * bgScale,
              top: -177 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(460 * bgScale, 460 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFF7C5CFC),
                    opacity: 0.18,
                    blurSigma: 120 * bgScale,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 720 * bgScale,
              top: 540 * bgScale,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(420 * bgScale, 420 * bgScale),
                  painter: _BlobPainter(
                    color: const Color(0xFF34D6E0),
                    opacity: 0.18,
                    blurSigma: 120 * bgScale,
                  ),
                ),
              ),
            ),

            // ── Decorative dots (Figma: 0.6 alpha) ──
            _buildDot(
              left: 300 * bgScale,
              top: 130 * bgScale,
              color: const Color(0xFF34D6E0),
              dotSize: 11 * bgScale,
              radius: 2,
            ),
            _buildDot(
              left: 860 * bgScale,
              top: 160 * bgScale,
              color: const Color(0xFF7C5CFC),
              dotSize: 9 * bgScale,
              radius: 2,
            ),
            _buildDot(
              left: 930 * bgScale,
              top: 110 * bgScale,
              color: const Color(0xFF3AD6A0),
              dotSize: 8 * bgScale,
              radius: 4,
            ),
            _buildDot(
              left: 300 * bgScale,
              top: 640 * bgScale,
              color: const Color(0xFFFFB02E),
              dotSize: 10 * bgScale,
              radius: 2,
            ),
            _buildDot(
              left: 880 * bgScale,
              top: 660 * bgScale,
              color: const Color(0xFFFF6B8A),
              dotSize: 10 * bgScale,
              radius: 2,
            ),
          ],

          // ── Main content ──
          SafeArea(
            child: Center(
              child: isPortrait
                  ? _buildPortrait(context, size, ref, scanResult, detectedCategory)
                  : _buildLandscape(context, size, ref, scanResult, detectedCategory),
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
            color: color.withValues(alpha: 0.6),
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
      ScanResult? scanResult, WasteCategory detectedCategory) {
    final isPhone = AppResponsive.isPhone(size);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 16 : 24,
        vertical: isPhone ? 16 : 24,
      ),
      child: _buildContent(
        context,
        size,
        ref,
        scanResult,
        detectedCategory,
        isPortrait: true,
        isPhone: isPhone,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LANDSCAPE (iPad) — Figma exact layout (centered column w:751)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size, WidgetRef ref,
      ScanResult? scanResult, WasteCategory detectedCategory) {
    final availW = size.width - 92.0 - 92.0;
    final scale = (availW / 1010.0).clamp(0.5, 1.0);

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 751.0 * scale,
          minWidth: 0,
        ),
        child: _buildContent(
          context,
          size,
          ref,
          scanResult,
          detectedCategory,
          isPortrait: false,
          isPhone: false,
          scale: scale,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // MAIN CONTENT — Figma column w:751, gap:24
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildContent(
    BuildContext context,
    Size size,
    WidgetRef ref,
    ScanResult? scanResult,
    WasteCategory detectedCategory, {
    required bool isPortrait,
    required bool isPhone,
    double scale = 1.0,
  }) {
    final gap24 = isPhone
        ? 14.0
        : isPortrait
            ? 18.0
            : 24.0 * scale;
    final gap16 = isPhone ? 8.0 : 16.0 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Eyebrow pill "TERSIMPAN KE DATASET"
        _buildEyebrowPill(scale: scale, isPhone: isPhone),
        SizedBox(height: gap16),

        // 2. Biny celebrate 128×134.4
        _buildBiny(scale: scale, isPhone: isPhone),
        SizedBox(height: gap24),

        // 3. Title
        _buildTitle(scale: scale, isPhone: isPhone),
        SizedBox(height: gap16),

        // 4. Subtitle
        _buildSubtitle(scanResult, detectedCategory, scale: scale, isPhone: isPhone),
        SizedBox(height: gap24),

        // 5. Category chips row
        _buildCategoryChips(size, ref, scanResult, detectedCategory,
            scale: scale, isPhone: isPhone),
        SizedBox(height: gap16),

        // 6. Recognition count
        _buildRecognitionCount(ref, scanResult, detectedCategory, scale: scale, isPhone: isPhone),
        SizedBox(height: gap24),

        // 7. Buttons
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16 * scale),
          child: _buildButtons(context, ref, size,
              scale: scale, isPhone: isPhone, isPortrait: isPortrait),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // EYEBROW PILL — Figma: bg #e1faf1, 20×20 r10 box bg #3ad6a0 + check
  // text "TERSIMPAN KE DATASET" 14px ExtraBold Baloo 2 #15936b tracking 0.8
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildEyebrowPill({double scale = 1.0, bool isPhone = false}) {
    final boxSize = isPhone ? 18.0 : 20.0 * scale;
    final padH = isPhone ? 12.0 : 18.0 * scale;
    final padV = isPhone ? 6.0 : 9.0 * scale;
    final textSize = isPhone ? 11.0 : 14.0 * scale;
    final iconSize = isPhone ? 12.0 : 14.0 * scale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: const Color(0xFFE1FAF1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: const Color(0xFF3AD6A0),
              borderRadius: BorderRadius.circular(isPhone ? 6 : 10.0 * scale),
            ),
            child: Icon(
              Icons.check_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8 * scale),
          Text(
            'TERSIMPAN KE DATASET',
            style: GoogleFonts.baloo2(
              fontSize: textSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF15936B),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY — Figma: 128×134.4
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBiny({double scale = 1.0, bool isPhone = false}) {
    final h = isPhone ? 100.0 : 134.4 * scale;
    return BinyHero(
      size: h,
      expression: BinyExpression.datasetSaved,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // TITLE — Figma: 46px ExtraBold Baloo 2 #2b2a45 line 1.08 center
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildTitle({double scale = 1.0, bool isPhone = false}) {
    final size = isPhone ? 28.0 : 46.0 * scale;
    return Text(
      'Biny jadi makin pintar!',
      style: GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF2B2A45),
        height: 1.08,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUBTITLE — Figma: 18px Medium Plus Jakarta Sans #5c5980 w:560 line 1.5
  // "Kategori baru [Cat] (cat-colored bold) sudah masuk ke pengetahuan Biny
  //  — lain kali langsung dikenali."
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSubtitle(ScanResult? scanResult, WasteCategory detectedCategory,
      {double scale = 1.0, bool isPhone = false}) {
    final fontSize = isPhone ? 14.0 : 18.0 * scale;
    final catColor = scanResult?.displayColor ?? detectedCategory.color;
    final catName = scanResult?.dynamicCategoryName ?? detectedCategory.name;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isPhone ? double.infinity : 560.0 * scale,
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF5C5980),
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Kategori baru '),
            TextSpan(
              text: catName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: catColor,
                height: 1.5,
              ),
            ),
            const TextSpan(
              text:
                  ' sudah masuk ke pengetahuan Biny — lain kali langsung dikenali.',
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  List<CategoryOption> _visibleCategories(WidgetRef ref, ScanResult? scanResult, WasteCategory detected) {
    final options = ref.watch(categoryOptionsProvider).toList();

    // If it's a new custom category from Gemini that hasn't been saved yet, add it manually
    if (scanResult != null && scanResult.category == WasteCategory.lainnya && scanResult.dynamicCategoryName != null) {
      final customName = scanResult.dynamicCategoryName!;
      final alreadyExists = options.any((opt) => opt.name == customName);
      if (!alreadyExists) {
        options.add(CategoryOption.custom(customName));
      }
    }

    // Move detected to the front
    CategoryOption? activeOpt;
    if (scanResult != null && scanResult.category == WasteCategory.lainnya && scanResult.dynamicCategoryName != null) {
      final idx = options.indexWhere((opt) => opt.name == scanResult.dynamicCategoryName);
      if (idx != -1) {
        activeOpt = options.removeAt(idx);
      } else {
        // If it's not in the provider yet (because it's not saved to Hive until 'Selesai'),
        // create a temporary option so it still appears visually.
        activeOpt = CategoryOption.custom(scanResult.dynamicCategoryName!);
      }
    } else {
      final idx = options.indexWhere((opt) => opt.baseCategory == detected && !opt.isCustom);
      if (idx != -1) {
        activeOpt = options.removeAt(idx);
      }
    }

    if (activeOpt != null) {
      options.insert(0, activeOpt);
    }
    
    return options;
  }

  // ─────────────────────────────────────────────────────────────────────
  // CATEGORY CHIPS — Figma: row gap:12
  // - Normal: bg white r999 px18/11 shadow 0/6/18 rgba(91,63,214,0.08),
  //           11×11 dot ellipse + name 16px Bold Baloo 2 #2b2a45
  // - Active: bg #e7fafb border 2px cat color, shadow 0/10/24 rgba(cat,0.35)
  //           + 0/6/18 rgba(91,63,214,0.08), + "BARU" pill bg cat color,
  //           text 11px ExtraBold Plus Jakarta Sans #063 tracking 0.4
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCategoryChips(Size size, WidgetRef ref, ScanResult? scanResult, WasteCategory detected,
      {double scale = 1.0, bool isPhone = false}) {
    final categories = _visibleCategories(ref, scanResult, detected);

    final gap = isPhone ? 6.0 : 12.0 * scale;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: categories.map((catOpt) {
        bool isActive = false;
        if (scanResult != null && scanResult.category == WasteCategory.lainnya && scanResult.dynamicCategoryName != null) {
          isActive = catOpt.name == scanResult.dynamicCategoryName;
        } else {
          isActive = catOpt.baseCategory == detected && !catOpt.isCustom;
        }

        return _buildChip(
          catOpt,
          isActive: isActive,
          scanResult: scanResult,
          scale: scale,
          isPhone: isPhone,
        );
      }).toList(),
    );
  }

  Widget _buildChip(CategoryOption catOpt,
      {required bool isActive, ScanResult? scanResult, double scale = 1.0, bool isPhone = false}) {
    final padH = isPhone ? 10.0 : 18.0 * scale;
    final padV = isPhone ? 6.0 : 11.0 * scale;
    final dotSize = isPhone ? 9.0 : 11.0 * scale;
    final textSize = isPhone ? 12.0 : 16.0 * scale;
    final catColor = (isActive && scanResult != null) ? scanResult.displayColor : catOpt.color;
    final catName = catOpt.name;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE7FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: isActive
            ? Border.all(color: catColor, width: 2.0)
            : null,
        boxShadow: [
          if (isActive) ...[
            BoxShadow(
              color: catColor.withValues(alpha: 0.35),
              blurRadius: isPhone ? 8 : 24,
              offset: Offset(0, isPhone ? 4 : 10),
            ),
            BoxShadow(
              color: const Color(0xFF5B3FD6).withValues(alpha: 0.08),
              blurRadius: isPhone ? 6 : 18,
              offset: const Offset(0, 6),
            ),
          ] else ...[
            BoxShadow(
              color: const Color(0xFF5B3FD6).withValues(alpha: 0.08),
              blurRadius: isPhone ? 6 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            (isActive && scanResult != null) ? scanResult.displayIconAsset : catOpt.iconAsset,
            width: isPhone ? 16 : 22 * scale,
            height: isPhone ? 16 : 22 * scale,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 8 * scale),
          Text(
            catName,
            style: GoogleFonts.baloo2(
              fontSize: textSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2A45),
            ),
          ),
          if (isActive) ...[
            SizedBox(width: 8 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6 * scale,
                vertical: 2 * scale,
              ),
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: (isPhone ? 9 : 11.0 * scale),
                    color: const Color(0xFF06393A).withValues(alpha: 0.95),
                  ),
                  SizedBox(width: 3 * scale),
                  Text(
                    'BARU',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: (isPhone ? 8 : 11.0 * scale),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF06393A),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RECOGNITION COUNT — Figma: 15px SemiBold Plus Jakarta Sans #908dac
  // "Sekarang Biny mengenali " + ExtraBold purple "N jenis sampah"
  // N = number of user-facing categories (base 5: Plastik, Kertas, Organik,
  // Logam, Residu). Could grow to 6+ if a future classifier emits a category
  // outside that set, but currently stays at 5.
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRecognitionCount(WidgetRef ref, ScanResult? scanResult, WasteCategory detectedCategory,
      {double scale = 1.0, bool isPhone = false}) {
    final fontSize = isPhone ? 12.0 : 15.0 * scale;
    final count = _visibleCategories(ref, scanResult, detectedCategory).length;

    return Text.rich(
      TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF908DAC),
        ),
        children: [
          const TextSpan(text: 'Sekarang Biny mengenali '),
          TextSpan(
            text: '$count jenis sampah',
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUTTONS — Figma: gap:12, py:16, w:240 each
  // "Pindai Lagi" #EDE8FF drop-shadow #DDD3FF
  // "Selesai" #7C5CFC shadow 0/12/22 rgba(124,92,252,0.35) + 0/6/0 #5B3FD6
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildButtons(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0,
      bool isPhone = false,
      bool isPortrait = false}) {
    final gap = isPhone ? 8.0 : 12.0 * scale;
    final btnW = isPhone ? null : 240.0 * scale;

    if (isPhone || isPortrait) {
      return Column(
        children: [
          SizedBox(
            width: btnW ?? double.infinity,
            child: _buildPindaiLagi(context, ref, size,
                scale: scale, isPhone: isPhone),
          ),
          SizedBox(height: gap),
          SizedBox(
            width: btnW ?? double.infinity,
            child: _buildSelesai(context, ref, size,
                scale: scale, isPhone: isPhone),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: btnW,
          child: _buildPindaiLagi(context, ref, size,
              scale: scale, isPhone: isPhone),
        ),
        SizedBox(width: gap),
        SizedBox(
          width: btnW,
          child: _buildSelesai(context, ref, size,
              scale: scale, isPhone: isPhone),
        ),
      ],
    );
  }

  /// "Pindai Lagi" — Figma: bg #EDE8FF drop-shadow 0/6/0 #DDD3FF
  /// Text 19px Bold Baloo 2 #5B3FD6 tracking 0.095
  Widget _buildPindaiLagi(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
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
          onTap: () async {
            ref.read(bluetoothProvider.notifier).sendCloseAll();
            ref.read(scanProvider.notifier).clearResult();
            ref.read(capturedImageProvider.notifier).state = null;
            ref.read(rescanProvider.notifier).state = false;
            ref.read(useGeminiProvider.notifier).state = false;
            context.go('/scanning');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Pindai Lagi',
                style: GoogleFonts.baloo2(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B3FD6),
                  letterSpacing: 0.095,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Selesai" — Figma: bg #7C5CFC shadow 0/12/22 rgba(124,92,252,0.35)
  /// + 0/6/0 #5B3FD6. Text 19px Bold Baloo 2 white tracking 0.095
  Widget _buildSelesai(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final padH = isPhone ? 16.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7C5CFC),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.35),
            blurRadius: isPhone ? 12 : 22,
            offset: Offset(0, isPhone ? 6 : 12),
          ),
          BoxShadow(
            color: const Color(0xFF5B3FD6),
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
            await ref.read(scanProvider.notifier).saveToHistory();
            ref.read(sessionProvider.notifier).addXP(SessionService.xpNewCategory);
            ref.read(sessionProvider.notifier).addScan();
            if (context.mounted) {
              context.go('/feedback');
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Center(
              child: Text(
                'Selesai',
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
