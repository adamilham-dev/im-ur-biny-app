import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Biny mascot expressions — matches website gallery exactly.
/// See https://trashscan.santodesign.id/ for reference.
enum BinyExpression {
  idle, // 01 · Idle
  welcome, // 02 · Welcome
  onboard1, // 03 · Onboarding 1/4
  onboard2, // 03 · Onboarding 2/4
  onboard3, // 03 · Onboarding 3/4
  onboard4, // 03 · Onboarding 4/4
  mode, // 04 · Pilih Mode
  category, // 05 · Pilih Kategori
  guide, // 06 · Camera Placement
  countdown, // 06b · Countdown
  scanning, // 07 · Scanning
  result, // 08 · Result
  multiResult, // 09 · Multi-Result
  detail, // 10 · Detail Item
  unknown, // 11 · Unknown
  analyzing, // 12 · Analyzing
  conclusionNew, // 13 · Kategori Baru
  conclusionExisting, // 14 · Kategori Existing
  datasetSaved, // 15 · Dataset Saved
  cont, // 16 · Continue / End
  feedback, // Feedback
  thankyou, // 17 · Thank You
  manualCorrection, // 18 · Manual Correction
  outOfFrame, // 19 · Out of Frame
  tooLarge, // 20 · Too Large
  lowConfidence, // 21 · Low Confidence
}

// ── Internal types ──

enum _Eye { happy, focus, think }
enum _Arm { wave, point, up, down }
enum _Mouth { smile, bigsmile, flat, o }
enum _Fx { none, sparkle, hearts, think, scan, celebrate }

class _ExprCfg {
  final _Eye eye;
  final _Arm arm;
  final _Mouth mouth;
  final String light;
  final _Fx fx;

  const _ExprCfg({
    required this.eye,
    required this.arm,
    required this.mouth,
    this.light = '#3AD6A0',
    this.fx = _Fx.none,
  });

  bool get hasBlink => eye == _Eye.happy;
  bool get hasBob => eye != _Eye.focus;
  bool get hasTilt => eye == _Eye.think;
  bool get isArmAnimated => arm == _Arm.wave || arm == _Arm.up;
}

// ── Expression configs from website ──

const _cfg = <BinyExpression, _ExprCfg>{
  // Pembuka & Onboarding
  BinyExpression.idle:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile, fx: _Fx.sparkle),
  BinyExpression.welcome:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.smile, fx: _Fx.hearts),
  BinyExpression.onboard1:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.smile),
  BinyExpression.onboard2:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.o, light: '#FF6B8A'),
  BinyExpression.onboard3:
      _ExprCfg(eye: _Eye.focus, arm: _Arm.down, mouth: _Mouth.flat, light: '#FFB02E', fx: _Fx.scan),
  BinyExpression.onboard4:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile, fx: _Fx.celebrate),
  // Pilih Mode & Kategori
  BinyExpression.mode:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.smile, fx: _Fx.sparkle),
  BinyExpression.category:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.smile),
  // Kamera & Pemindaian
  BinyExpression.guide:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile),
  BinyExpression.countdown:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.o),
  BinyExpression.scanning:
      _ExprCfg(eye: _Eye.focus, arm: _Arm.down, mouth: _Mouth.flat, light: '#FFB02E', fx: _Fx.scan),
  // Hasil Deteksi
  BinyExpression.result:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.bigsmile, fx: _Fx.celebrate),
  BinyExpression.multiResult:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.bigsmile, fx: _Fx.sparkle),
  BinyExpression.detail:
      _ExprCfg(eye: _Eye.think, arm: _Arm.point, mouth: _Mouth.smile, fx: _Fx.think),
  // AI Agent
  BinyExpression.unknown:
      _ExprCfg(eye: _Eye.think, arm: _Arm.point, mouth: _Mouth.o, fx: _Fx.think),
  BinyExpression.analyzing:
      _ExprCfg(eye: _Eye.think, arm: _Arm.point, mouth: _Mouth.o, fx: _Fx.think),
  BinyExpression.conclusionNew:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.bigsmile, fx: _Fx.celebrate),
  BinyExpression.conclusionExisting:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.point, mouth: _Mouth.bigsmile, fx: _Fx.sparkle),
  BinyExpression.datasetSaved:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.bigsmile, fx: _Fx.celebrate),
  // Akhir Sesi
  BinyExpression.cont:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile, fx: _Fx.hearts),
  BinyExpression.feedback:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.up, mouth: _Mouth.bigsmile, fx: _Fx.hearts),
  BinyExpression.thankyou:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile, fx: _Fx.hearts),
  // Edge Case
  BinyExpression.manualCorrection:
      _ExprCfg(eye: _Eye.think, arm: _Arm.point, mouth: _Mouth.smile),
  BinyExpression.outOfFrame:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile),
  BinyExpression.tooLarge:
      _ExprCfg(eye: _Eye.happy, arm: _Arm.wave, mouth: _Mouth.bigsmile),
  BinyExpression.lowConfidence:
      _ExprCfg(eye: _Eye.think, arm: _Arm.point, mouth: _Mouth.flat, fx: _Fx.think),
};

// ── SVG file paths ──
// All SVGs use viewBox "0 0 240 252"

String _bodyPath(BinyExpression e) {
  const m = <BinyExpression, String>{
    BinyExpression.idle: 'biny_01_idle_body.svg',
    BinyExpression.welcome: 'biny_02_welcome_body.svg',
    BinyExpression.onboard1: 'biny_03a_onboard1_body.svg',
    BinyExpression.onboard2: 'biny_03b_onboard2_body.svg',
    BinyExpression.onboard3: 'biny_03c_onboard3_body.svg',
    BinyExpression.onboard4: 'biny_03d_onboard4_body.svg',
    BinyExpression.mode: 'biny_04_mode_body.svg',
    BinyExpression.category: 'biny_05_category_body.svg',
    BinyExpression.guide: 'biny_06_guide_body.svg',
    BinyExpression.countdown: 'biny_06b_countdown_body.svg',
    BinyExpression.scanning: 'biny_07_scanning_body.svg',
    BinyExpression.result: 'biny_08_result_body.svg',
    BinyExpression.multiResult: 'biny_09_multi_result_body.svg',
    BinyExpression.detail: 'biny_10_detail_body.svg',
    BinyExpression.unknown: 'biny_11_unknown_body.svg',
    BinyExpression.analyzing: 'biny_12_analyzing_body.svg',
    BinyExpression.conclusionNew: 'biny_13_conclusion_new_body.svg',
    BinyExpression.conclusionExisting: 'biny_14_conclusion_existing_body.svg',
    BinyExpression.datasetSaved: 'biny_15_dataset_body.svg',
    BinyExpression.cont: 'biny_16_continue_body.svg',
    BinyExpression.feedback: 'biny_feedback_body.svg',
    BinyExpression.thankyou: 'biny_17_thankyou_body.svg',
    BinyExpression.manualCorrection: 'biny_18_manual_correction_body.svg',
    BinyExpression.outOfFrame: 'biny_19_out_of_frame_body.svg',
    BinyExpression.tooLarge: 'biny_20_too_large_body.svg',
    BinyExpression.lowConfidence: 'biny_21_low_confidence_body.svg',
  };
  return 'assets/images/${m[e]!}';
}

String? _leftArmPath(BinyExpression e) {
  if (!_cfg[e]!.isArmAnimated) return null;
  const m = <BinyExpression, String>{
    BinyExpression.idle: 'biny_01_idle_left_arm.svg',
    BinyExpression.onboard2: 'biny_03b_onboard2_left_arm.svg',
    BinyExpression.onboard4: 'biny_03d_onboard4_left_arm.svg',
    BinyExpression.guide: 'biny_06_guide_left_arm.svg',
    BinyExpression.countdown: 'biny_06b_countdown_left_arm.svg',
    BinyExpression.result: 'biny_08_result_left_arm.svg',
    BinyExpression.conclusionNew: 'biny_13_conclusion_new_left_arm.svg',
    BinyExpression.datasetSaved: 'biny_15_dataset_left_arm.svg',
    BinyExpression.cont: 'biny_16_continue_left_arm.svg',
    BinyExpression.feedback: 'biny_feedback_left_arm.svg',
    BinyExpression.thankyou: 'biny_17_thankyou_left_arm.svg',
    BinyExpression.outOfFrame: 'biny_19_out_of_frame_left_arm.svg',
    BinyExpression.tooLarge: 'biny_20_too_large_left_arm.svg',
  };
  final v = m[e];
  return v != null ? 'assets/images/$v' : null;
}

String? _rightArmPath(BinyExpression e) {
  if (!_cfg[e]!.isArmAnimated) return null;
  const m = <BinyExpression, String>{
    BinyExpression.idle: 'biny_01_idle_right_arm.svg',
    BinyExpression.onboard2: 'biny_03b_onboard2_right_arm.svg',
    BinyExpression.onboard4: 'biny_03d_onboard4_right_arm.svg',
    BinyExpression.guide: 'biny_06_guide_right_arm.svg',
    BinyExpression.countdown: 'biny_06b_countdown_right_arm.svg',
    BinyExpression.result: 'biny_08_result_right_arm.svg',
    BinyExpression.conclusionNew: 'biny_13_conclusion_new_right_arm.svg',
    BinyExpression.datasetSaved: 'biny_15_dataset_right_arm.svg',
    BinyExpression.cont: 'biny_16_continue_right_arm.svg',
    BinyExpression.feedback: 'biny_feedback_right_arm.svg',
    BinyExpression.thankyou: 'biny_17_thankyou_right_arm.svg',
    BinyExpression.outOfFrame: 'biny_19_out_of_frame_right_arm.svg',
    BinyExpression.tooLarge: 'biny_20_too_large_right_arm.svg',
  };
  final v = m[e];
  return v != null ? 'assets/images/$v' : null;
}

String? _staticArmsPath(BinyExpression e) {
  if (_cfg[e]!.isArmAnimated) return null;
  const m = <BinyExpression, String>{
    BinyExpression.welcome: 'biny_02_welcome_arms.svg',
    BinyExpression.onboard1: 'biny_03a_onboard1_arms.svg',
    BinyExpression.onboard3: 'biny_03c_onboard3_arms.svg',
    BinyExpression.mode: 'biny_04_mode_arms.svg',
    BinyExpression.category: 'biny_05_category_arms.svg',
    BinyExpression.scanning: 'biny_07_scanning_arms.svg',
    BinyExpression.multiResult: 'biny_09_multi_result_arms.svg',
    BinyExpression.detail: 'biny_10_detail_arms.svg',
    BinyExpression.unknown: 'biny_11_unknown_arms.svg',
    BinyExpression.analyzing: 'biny_12_analyzing_arms.svg',
    BinyExpression.conclusionExisting: 'biny_14_conclusion_existing_arms.svg',
    BinyExpression.manualCorrection: 'biny_18_manual_correction_arms.svg',
    BinyExpression.lowConfidence: 'biny_21_low_confidence_arms.svg',
  };
  final v = m[e];
  return v != null ? 'assets/images/$v' : null;
}

// ── Constants ──

// ViewBox = "0 0 240 252"
const double _vbW = 240;
const double _vbH = 252;
const double _vbAspect = _vbW / _vbH; // ≈0.9524

// Eye positions in viewBox coords
// Happy: left (99, 108) r=11, right (141, 108) r=11
// Focus: rectangles at same centers
// Think: left (99, 108), right (141, 112) — right eye 4px lower
const double _eyeLx = 99;
const double _eyeLy = 108;
const double _eyeRx = 141;
const double _eyeRyHappy = 108;
const double _eyeRyThink = 112;
const double _eyeR = 11;

// Arm pivot points in viewBox
const double _rightArmPivotX = 186;
const double _rightArmPivotY = 130;
const double _leftArmPivotX = 54;
const double _leftArmPivotY = 130;

// Pivot as Alignment coordinates
// Alignment x = (viewBoxX / _vbW) * 2 - 1
// Alignment y = (viewBoxY / _vbH) * 2 - 1
const Alignment _rightArmAlignment = Alignment(
  _rightArmPivotX / _vbW * 2 - 1, // 0.55
  _rightArmPivotY / _vbH * 2 - 1, // 0.032
);
const Alignment _leftArmAlignment = Alignment(
  _leftArmPivotX / _vbW * 2 - 1, // -0.55
  _leftArmPivotY / _vbH * 2 - 1, // 0.032
);

// ── FX particle data (positions from website JS) ──

class _FxP {
  final double x, y, size;
  final int color; // 0xAARRGGBB
  final double begin; // fraction of cycle
  const _FxP(this.x, this.y, this.size, this.color, this.begin);
}

const _sparkleParticles = <_FxP>[
  _FxP(48, 54, 9, 0xFFFFB02E, 0.0),
  _FxP(196, 46, 7, 0xFFFFB02E, 0.23),
  _FxP(150, 26, 5, 0xFFA892FF, 0.43),
  _FxP(38, 150, 6, 0xFFFFB02E, 0.63),
];

const _heartParticles = <_FxP>[
  _FxP(54, 84, 15, 0xFFFF6B8A, 0.0),
  _FxP(196, 96, 12, 0xFFFF6B8A, 0.35),
  _FxP(150, 40, 10, 0xFFC58CFF, 0.62),
];

const _thinkParticles = <_FxP>[
  _FxP(190, 70, 4, 0xFFC58CFF, 0.0),
  _FxP(200, 58, 5, 0xFFC58CFF, 0.30),
  _FxP(209, 45, 6, 0xFFC58CFF, 0.60),
];

const _scanParticles = <_FxP>[
  _FxP(40, 96, 6, 0xFFFFB02E, 0.0),
  _FxP(202, 98, 6, 0xFFFFB02E, 0.17),
  _FxP(48, 168, 4, 0xFFFFB02E, 0.30),
  _FxP(196, 168, 4, 0xFFFFB02E, 0.43),
];

const _confettiParticles = <_FxP>[
  _FxP(60, 60, 8, 0xFF7C5CFC, 0.0), // drift -14
  _FxP(120, 40, 8, 0xFF3AD6A0, 0.20), // drift +14
  _FxP(186, 64, 8, 0xFFFFB02E, 0.40), // drift +14
  _FxP(95, 52, 8, 0xFFFF6B8A, 0.60), // drift -14
  _FxP(160, 56, 8, 0xFF34D6E0, 0.80), // drift +8
  _FxP(40, 120, 8, 0xFFFFB02E, 0.07), // sparkle
  _FxP(206, 128, 8, 0xFF3AD6A0, 0.27), // sparkle
];

// Confetti rotation values from HTML: [-18, 12, 22, -30, 8]
const _confettiRotations = [-18.0, 12.0, 22.0, -30.0, 8.0];

// ── Widget ──

class BinyMascot extends StatefulWidget {
  final double height;
  final bool animate;
  final BinyExpression expression;

  const BinyMascot({
    super.key,
    double size = 200,
    this.animate = true,
    this.expression = BinyExpression.idle,
  }) : height = size;

  @override
  State<BinyMascot> createState() => _BinyMascotState();
}

class _BinyMascotState extends State<BinyMascot> with TickerProviderStateMixin {
  late AnimationController _bobCtrl; // 2.6s → bob (repeat reverse → 5.2s cycle... use 1.3s forward)
  late AnimationController _tiltCtrl; // 2.8s → head tilt for think
  late AnimationController _armCtrl; // arm wave
  late AnimationController _blinkCtrl; // 3.6s → blink
  late AnimationController _fxCtrl; // 3.0s → FX

  _ExprCfg get c => _cfg[widget.expression] ?? _cfg[BinyExpression.idle]!;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _tiltCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _armCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    _fxCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _start();
  }

  void _start() {
    if (!widget.animate) return;
    if (c.hasBob) _bobCtrl.repeat(reverse: true);
    if (c.hasTilt) _tiltCtrl.repeat(reverse: true);
    if (c.isArmAnimated) _armCtrl.repeat();
    if (c.hasBlink) _blinkCtrl.repeat();
    if (c.fx != _Fx.none) _fxCtrl.repeat();
  }

  void _stopAll() {
    _bobCtrl.stop();
    _tiltCtrl.stop();
    _armCtrl.stop();
    _blinkCtrl.stop();
    _fxCtrl.stop();
  }

  @override
  void didUpdateWidget(BinyMascot old) {
    super.didUpdateWidget(old);
    if (old.expression != widget.expression || old.animate != widget.animate) {
      _stopAll();
      // Reset controllers
      _bobCtrl.value = 0;
      _tiltCtrl.value = 0;
      _armCtrl.value = 0;
      _blinkCtrl.value = 0;
      _fxCtrl.value = 0;
      // Adjust arm duration based on arm type
      _armCtrl.duration = c.arm == _Arm.up
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 1100);
      _start();
    }
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _tiltCtrl.dispose();
    _armCtrl.dispose();
    _blinkCtrl.dispose();
    _fxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * _vbAspect;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bobCtrl, _tiltCtrl, _armCtrl, _blinkCtrl, _fxCtrl,
      ]),
      builder: (context, _) {
        // ── Bob: 0 → -6 → 0, dur 2.6s, easeInOut ──
        final double bobY = c.hasBob
            ? Curves.easeInOut.transform(_bobCtrl.value) * -6
            : 0.0;

        // ── Tilt: -4° → 4°, dur 2.8s (only think) ──
        final double tiltDeg = c.hasTilt ? -4 + 8 * _tiltCtrl.value : 0.0;
        final double tiltRad = tiltDeg * pi / 180;

        // ── Arm rotation ──
        // Wave: right arm -14°→16°→-14°, dur 1.1s (cos wave)
        // Up: right arm -8°→7°→-8°, left arm 8°→-7°→8°, dur 1.2s
        double rightArmDeg = 0, leftArmDeg = 0;
        if (c.isArmAnimated) {
          final t = _armCtrl.value;
          if (c.arm == _Arm.wave) {
            // -14 → 16 → -14 via cos
            rightArmDeg = 1 - 15 * cos(2 * pi * t);
          } else if (c.arm == _Arm.up) {
            rightArmDeg = -0.5 - 7.5 * cos(2 * pi * t); // -8 → 7 → -8
            leftArmDeg = 0.5 + 7.5 * cos(2 * pi * t); // 8 → -7 → 8
          }
        }

        // ── Blink ──
        final blinkV = _blinkCtrl.value;
        double blinkAmount = 0;
        if (c.hasBlink) {
          if (blinkV >= 0.86 && blinkV < 0.90) {
            blinkAmount = (blinkV - 0.86) / 0.04;
          } else if (blinkV >= 0.90 && blinkV < 0.94) {
            blinkAmount = 1.0 - (blinkV - 0.90) / 0.04;
          }
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Mascot group (bob + tilt) ──
              Transform.translate(
                offset: Offset(0, bobY * h / _vbH),
                child: Transform.rotate(
                  angle: tiltRad,
                  alignment: const Alignment(0, 0.2), // rotate around center-ish
                  child: Stack(
                    children: [
                      // Body (no arms)
                      _svgImg(_bodyPath(widget.expression), w, h),

                      // Static arms (point/down)
                      if (!c.isArmAnimated)
                        _svgImg(_staticArmsPath(widget.expression)!, w, h),

                      // Animated right arm
                      if (c.isArmAnimated && _rightArmPath(widget.expression) != null)
                        Transform.rotate(
                          angle: rightArmDeg * pi / 180,
                          alignment: _rightArmAlignment,
                          child: _svgImg(_rightArmPath(widget.expression)!, w, h),
                        ),

                      // Animated left arm
                      if (c.isArmAnimated &&
                          c.arm == _Arm.up &&
                          _leftArmPath(widget.expression) != null)
                        Transform.rotate(
                          angle: leftArmDeg * pi / 180,
                          alignment: _leftArmAlignment,
                          child: _svgImg(_leftArmPath(widget.expression)!, w, h),
                        ),

                      // Animated left arm for wave (static, just render)
                      if (c.isArmAnimated &&
                          c.arm == _Arm.wave &&
                          _leftArmPath(widget.expression) != null)
                        _svgImg(_leftArmPath(widget.expression)!, w, h),

                      // Blink overlay
                      if (blinkAmount > 0.01)
                        CustomPaint(
                          size: Size(w, h),
                          painter: _BlinkPainter(
                            blinkAmount: blinkAmount,
                            isThink: c.eye == _Eye.think,
                            scale: h / _vbH,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── FX layer (in front of mascot) ──
              if (c.fx != _Fx.none)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FxPainter(
                      type: c.fx,
                      progress: _fxCtrl.value,
                      vbW: _vbW,
                      vbH: _vbH,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _svgImg(String assetPath, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: SvgPicture.asset(
        assetPath,
        width: w,
        height: h,
        fit: BoxFit.fill,
      ),
    );
  }
}

// ── Blink painter ──

class _BlinkPainter extends CustomPainter {
  final double blinkAmount; // 0-1
  final bool isThink;
  final double scale; // h / vbH

  _BlinkPainter({
    required this.blinkAmount,
    required this.isThink,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (blinkAmount <= 0.01) return;

    final s = scale;
    final lidH = _eyeR * 2 * blinkAmount * s;
    final lidPaint = Paint()
      ..color = const Color(0xFF34314F)
      ..style = PaintingStyle.fill;

    // Left eye
    final lx = _eyeLx * s;
    final ly = _eyeLy * s;
    final er = _eyeR * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lx, ly), width: er * 2.2, height: lidH.clamp(0.0, er * 2)),
        Radius.circular(er * 0.6),
      ),
      lidPaint,
    );

    // Right eye
    final rx = _eyeRx * s;
    final ry = (isThink ? _eyeRyThink : _eyeRyHappy) * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(rx, ry), width: er * 2.2, height: lidH.clamp(0.0, er * 2)),
        Radius.circular(er * 0.6),
      ),
      lidPaint,
    );

    // Lid line when mostly closed
    if (blinkAmount > 0.5) {
      final linePaint = Paint()
        ..color = const Color(0xFF74F2CE).withValues(alpha: 0.8)
        ..strokeWidth = (er * 0.3).clamp(1.5, 3.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final lw = er * 1.5;
      canvas.drawLine(Offset(lx - lw, ly), Offset(lx + lw, ly), linePaint);
      canvas.drawLine(Offset(rx - lw, ry), Offset(rx + lw, ry), linePaint);
    }
  }

  @override
  bool shouldRepaint(_BlinkPainter old) => old.blinkAmount != blinkAmount;
}

// ── FX painter ──

class _FxPainter extends CustomPainter {
  final _Fx type;
  final double progress;
  final double vbW, vbH;

  _FxPainter({
    required this.type,
    required this.progress,
    required this.vbW,
    required this.vbH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / vbW;
    final sy = size.height / vbH;

    switch (type) {
      case _Fx.sparkle:
        _drawSparkle(canvas, sx, sy);
      case _Fx.hearts:
        _drawHearts(canvas, sx, sy);
      case _Fx.think:
        _drawThink(canvas, sx, sy);
      case _Fx.scan:
        _drawScan(canvas, sx, sy);
      case _Fx.celebrate:
        _drawCelebrate(canvas, sx, sy);
      case _Fx.none:
        break;
    }
  }

  double _localT(_FxP p, double cycleDur) {
    // Each particle has its own cycle with begin offset
    return (progress + p.begin) % 1.0;
  }

  void _drawSparkle(Canvas c, double sx, double sy) {
    for (final p in _sparkleParticles) {
      final t = _localT(p, 2.0);
      final cx = p.x * sx;
      final cy = p.y * sy;
      final s = 0.25 + 0.75 * (0.5 - 0.5 * cos(2 * pi * t));
      final op = 0.15 + 0.85 * s;
      _drawStar(c, cx, cy, p.size * s * sx, Color(p.color).withValues(alpha: op));
    }
  }

  void _drawHearts(Canvas c, double sx, double sy) {
    for (final p in _heartParticles) {
      final t = _localT(p, 2.6);
      final cx = p.x * sx;
      final cy = p.y * sy - 32 * t * sy; // float up 32 viewBox units (matching HTML)
      final op = t < 0.1 ? t / 0.1 : t > 0.8 ? (1 - t) / 0.2 : 1.0;
      _drawHeart(c, cx, cy, p.size * sx, Color(p.color).withValues(alpha: op.clamp(0.0, 1.0)));
    }
  }

  void _drawThink(Canvas c, double sx, double sy) {
    for (final p in _thinkParticles) {
      final t = _localT(p, 1.5);
      final cx = p.x * sx;
      final cy = p.y * sy;
      final s = 0.7 + 0.3 * sin(2 * pi * t);
      final op = 0.15 + 0.85 * sin(pi * t);
      final paint = Paint()
        ..color = Color(p.color).withValues(alpha: op.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvasDrawCircle(c, cx, cy, p.size * s * sx, paint);
    }
  }

  void _drawScan(Canvas c, double sx, double sy) {
    for (final p in _scanParticles) {
      final t = _localT(p, 2.0);
      final cx = p.x * sx;
      final cy = p.y * sy;
      final s = 0.25 + 0.75 * (0.5 - 0.5 * cos(2 * pi * t));
      final op = 0.15 + 0.85 * s;
      if (p.size <= 5) {
        // Dot
        final paint = Paint()
          ..color = Color(p.color).withValues(alpha: op.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvasDrawCircle(c, cx, cy, p.size * (0.7 + 0.3 * sin(2 * pi * t)) * sx, paint);
      } else {
        // Star
        _drawStar(c, cx, cy, p.size * s * sx, Color(p.color).withValues(alpha: op));
      }
    }
  }

  void _drawCelebrate(Canvas c, double sx, double sy) {
    // Confetti particles (first 5) — matching HTML: drift ±16, fall 70 units
    for (var i = 0; i < 5 && i < _confettiParticles.length; i++) {
      final p = _confettiParticles[i];
      final t = _localT(p, 1.5);
      // Match HTML: drift direction based on rotation sign (rot>0 → +16, rot<0 → -16)
      final rotSign = (i == 1 || i == 2 || i == 4) ? 16 : -16;
      final cx = (p.x + rotSign * t) * sx;
      final cy = (p.y + 70 * t) * sy; // fall down 70 viewBox units (matching HTML)
      final op = t < 0.1 ? t / 0.1 : t > 0.7 ? (1 - t) / 0.3 : 1.0;
      final rot = _confettiRotations[i] * pi / 180 + t * pi;
      _drawRect(c, cx, cy, 8 * sx, 12 * sy, rot, Color(p.color).withValues(alpha: op.clamp(0.0, 1.0)));
    }
    // Sparkle stars (last 2)
    for (var i = 5; i < _confettiParticles.length; i++) {
      final p = _confettiParticles[i];
      final t = _localT(p, 2.0);
      final cx = p.x * sx;
      final cy = p.y * sy;
      final s = 0.25 + 0.75 * (0.5 - 0.5 * cos(2 * pi * t));
      final op = 0.15 + 0.85 * s;
      _drawStar(c, cx, cy, p.size * s * sx, Color(p.color).withValues(alpha: op));
    }
  }

  void _drawStar(Canvas c, double cx, double cy, double r, Color color) {
    if (r < 0.5) return;
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = (i * pi / 4) - pi / 2;
      final rad = i.isEven ? r : r * 0.34;
      if (i == 0) {
        path.moveTo(cx + rad * cos(a), cy + rad * sin(a));
      } else {
        path.lineTo(cx + rad * cos(a), cy + rad * sin(a));
      }
    }
    path.close();
    c.drawPath(path, paint);
  }

  void _drawHeart(Canvas c, double cx, double cy, double size, Color color) {
    if (size < 0.5) return;
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    // Match JS exactly: scale by size/16, translate by (-8,-8), then translate to (cx,cy)
    final sc = size / 16;
    // JS path: M8 13.5 C8 13.5 1.5 8.8 1.5 4.6 C1.5 2.4 3.2 1 5 1 C6.4 1 7.6 2 8 2.9 C8.4 2 9.6 1 11 1 C12.8 1 14.5 2.4 14.5 4.6 C14.5 8.8 8 13.5 8 13.5 Z
    final ox = cx - 8 * sc;
    final oy = cy - 8 * sc;
    final path = Path();
    path.moveTo(ox + 8 * sc, oy + 13.5 * sc);
    path.cubicTo(ox + 8 * sc, oy + 13.5 * sc, ox + 1.5 * sc, oy + 8.8 * sc, ox + 1.5 * sc, oy + 4.6 * sc);
    path.cubicTo(ox + 1.5 * sc, oy + 2.4 * sc, ox + 3.2 * sc, oy + 1 * sc, ox + 5 * sc, oy + 1 * sc);
    path.cubicTo(ox + 6.4 * sc, oy + 1 * sc, ox + 7.6 * sc, oy + 2 * sc, ox + 8 * sc, oy + 2.9 * sc);
    path.cubicTo(ox + 8.4 * sc, oy + 2 * sc, ox + 9.6 * sc, oy + 1 * sc, ox + 11 * sc, oy + 1 * sc);
    path.cubicTo(ox + 12.8 * sc, oy + 1 * sc, ox + 14.5 * sc, oy + 2.4 * sc, ox + 14.5 * sc, oy + 4.6 * sc);
    path.cubicTo(ox + 14.5 * sc, oy + 8.8 * sc, ox + 8 * sc, oy + 13.5 * sc, ox + 8 * sc, oy + 13.5 * sc);
    path.close();
    c.drawPath(path, paint);
  }

  void _drawRect(Canvas c, double cx, double cy, double w, double h, double rot, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    c.save();
    c.translate(cx, cy);
    c.rotate(rot);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        const Radius.circular(2.5),
      ),
      paint,
    );
    c.restore();
  }

  void canvasDrawCircle(Canvas c, double cx, double cy, double r, Paint paint) {
    c.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.progress != progress || old.type != type;
}
