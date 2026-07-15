import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/scan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../shared/widgets/biny_hero.dart';

/// Pixel-perfect "11 · Unknown Detected"
/// in 1194×834 frame (landscape iPad).
///
/// Layout (Figma)
/// - Background #FBFAFF with two LAYER_BLUR blobs + 5 decorative dots
/// - Container at left:92, vertically centered, horizontal flex, gap:60
/// - Left: image card 430×430 (white, r32, shadow 0/18/44 rgba(41,31,89,.13))
///   - inner img 400×400 at (15,15), r22, gradient 111.8° #2B2843→#191731
///   - inner glow ellipse 250×250 (purple-ish)
///   - "BELUM DIKENAL" badge top:14, centered
///   - tag bottom: "Keyakinan · X%" top:352
/// - Right: 520px column, gap:24
///   1. Biny(84×88.2) + speech bubble (white, border 2px #EDE8FF, r22, p20/12)
///      "Hmm, ini sesuatu yang baru buatku…"
///   2. Title 46px ExtraBold Baloo 2 #2B2A45 line 1.08
///      "Objek terdeteksi," / "tapi belum dikenali"
///   3. Subtitle 19px Medium Plus Jakarta Sans #5C5980 width 500 line 1.55
///      "Tidak masalah! AI Agent-ku bisa menganalisis…"
///   4. Button "Analisis dengan AI" (#7C5CFC, px32/20, r999)
class UnknownDetectedScreen extends ConsumerWidget {
  const UnknownDetectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isPortrait = AppResponsive.isPortrait(size);
    final capturedImage = ref.watch(capturedImageProvider);
    final scanResult = ref.watch(scanResultProvider);
    // Confidence for the "Keyakinan · X%" tag — fall back to 0 if no result.
    final confidence = scanResult?.confidence ?? 0.0;

    // Background scale: Figma frame is 1194×834. Scale blobs/dots with screen.
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
                  ? _buildPortrait(context, size, capturedImage, confidence, ref)
                  : _buildLandscape(context, size, capturedImage, confidence, ref),
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
  Widget _buildPortrait(BuildContext context, Size size,
      Uint8List? capturedImage, double confidence, WidgetRef ref) {
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
            child: _buildImageCard(capturedImage, confidence, isPhone: isPhone),
          ),
          SizedBox(height: isPhone ? 20 : 32),
          _buildRightPanel(context, size, ref, isPortrait: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LANDSCAPE (iPad) — Figma exact layout
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildLandscape(BuildContext context, Size size,
      Uint8List? capturedImage, double confidence, WidgetRef ref) {
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
          _buildImageCard(capturedImage, confidence, scale: scale),
          SizedBox(width: gap),
          SizedBox(
            width: 520.0 * scale,
            child: _buildRightPanel(context, size, ref,
                isPortrait: false, scale: scale),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // IMAGE CARD — Figma: 430×430, white, r32
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildImageCard(Uint8List? capturedImage, double confidence,
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
              // Captured photo, or placeholder
              if (capturedImage != null)
                Image.memory(capturedImage, fit: BoxFit.cover)
              else
                _buildPlaceholder(scale, isPhone: isPhone),

              // "BELUM DIKENAL" badge — Figma: top:14.4
              Positioned(
                top: 14 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA892FF).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFA892FF).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18 * scale,
                          height: 18 * scale,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA892FF),
                            borderRadius: BorderRadius.circular(9 * scale),
                          ),
                          child: Center(
                            child: Text(
                              '?',
                              style: GoogleFonts.baloo2(
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF3A2A7A),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          'BELUM DIKENAL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE7DEFF),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom tag — "Keyakinan · X%"
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF8FA6),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Keyakinan ·',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  ${(confidence * 100).round()}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF8FA6),
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

  /// Placeholder illustration for the inner image card when no captured image
  /// is available. Replicates Figma's "image 17" question-mark illustration
  /// sitting on top of a soft purple glow ellipse.
  Widget _buildPlaceholder(double scale, {bool isPhone = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft purple glow ellipse — Figma ellipse 250×250 at (75,70)
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
                    const Color(0xFFA892FF).withValues(alpha: 0.35),
                    const Color(0xFFA892FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Question-mark illustration — Figma "image 17" 156.9×335
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: (isPhone ? 80 : 156.9) * scale,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              SizedBox(height: 6 * scale),
              Text(
                '?',
                style: GoogleFonts.baloo2(
                  fontSize: (isPhone ? 40 : 80) * scale,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.16),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Figma: 520px col, gap:24
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext context, Size size, WidgetRef ref,
      {required bool isPortrait, double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final gap24 = (24.0 * scale).clamp(12.0, 24.0);
    final gap16 = (16.0 * scale).clamp(8.0, 16.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Biny + Speech bubble
        _buildBinyBubble(size, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 2. Title
        _buildTitle(size, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 3. Subtitle
        _buildSubtitle(size, scale: scale, isPhone: isPhone),
        SizedBox(height: isPortrait ? gap16 : gap24),

        // 4. Analisis dengan AI button
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16 * scale),
          child: _buildAnalisisButton(context, ref, size, scale: scale),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BINY + SPEECH BUBBLE — Figma: Biny 84×88.2, bubble white r22 p20/12
  // "Hmm, ini sesuatu yang baru buatku…"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildBinyBubble(Size size,
      {double scale = 1.0, bool isPhone = false}) {
    final mascotSize = isPhone ? 60.0 : 84.0 * scale;
    final bubblePadH = isPhone ? 14.0 : 20.0 * scale;
    final bubblePadV = isPhone ? 8.0 : 12.0 * scale;
    final bubbleRadius = isPhone ? 16.0 : 22.0 * scale;
    final fontSize = isPhone ? 13.0 : 18.0 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BinyHero(size: mascotSize, expression: BinyExpression.unknown),
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
                  'Hmm, ini sesuatu yang baru buatku…',
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
  // TITLE — Figma: 46px ExtraBold Baloo 2 #2B2A45 line 1.08
  // "Objek terdeteksi," / "tapi belum dikenali"
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildTitle(Size size, {double scale = 1.0, bool isPhone = false}) {
    final fontSize = isPhone ? 26.0 : 46.0 * scale;

    return Text(
      'Objek terdeteksi,\ntapi belum dikenali',
      style: GoogleFonts.baloo2(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.08,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUBTITLE — Figma: 19px Medium Plus Jakarta Sans #5C5980 line 1.55
  // "Tidak masalah! AI Agent-ku bisa menganalisis jenis sampah ini dan
  //  belajar darinya supaya makin pintar."
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSubtitle(Size size, {double scale = 1.0, bool isPhone = false}) {
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return SizedBox(
      width: isPhone ? double.infinity : 500.0 * scale,
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
          children: [
            const TextSpan(text: 'Tidak masalah! '),
            TextSpan(
              text: 'AI Agent',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const TextSpan(
              text: '-ku bisa menganalisis jenis sampah ini dan belajar '
                  'darinya supaya makin pintar.',
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // "ANALISIS DENGAN AI" BUTTON — Figma: bg #7C5CFC, px32/20, r999
  // shadow 0/12/22 rgba(124,92,252,.35) + 0/6/0 #5B3FD6
  // Icon "Multiple-Stars" 24×24 + text 19px Bold Baloo 2 white tracking 0.095
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAnalisisButton(BuildContext context, WidgetRef ref, Size size,
      {double scale = 1.0}) {
    final isPhone = AppResponsive.isPhone(size);
    final padH = isPhone ? 20.0 : 32.0 * scale;
    final padV = isPhone ? 14.0 : 20.0 * scale;
    final iconSize = isPhone ? 18.0 : 24.0 * scale;
    final fontSize = isPhone ? 14.0 : 19.0 * scale;

    return Container(
      width: double.infinity,
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
          onTap: () => _onAnalisisAiTapped(context, ref),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
                SizedBox(width: 12 * scale),
                Text(
                  'Analisis dengan AI',
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
    );
  }

  /// "Analisis AI" — send the already-captured photo straight to the
  /// Analyzing screen, which runs the Gemini cloud API (no on-device
  /// TFLite/RT-DETR, no fallback, no inline loading dialog — the analyzing
  /// animation IS the UI). The existing photo in [capturedImageProvider]
  /// is reused; no new camera capture is triggered.
  void _onAnalisisAiTapped(BuildContext context, WidgetRef ref) {
    ref.read(useGeminiProvider.notifier).state = true;
    context.go('/analyzing');
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
