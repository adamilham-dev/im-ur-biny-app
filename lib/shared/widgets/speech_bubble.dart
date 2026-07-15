import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SpeechBubble extends StatelessWidget {
  final Widget child;

  const SpeechBubble({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 13, right: 20, bottom: 26),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: const SpeechBubbleShape(
          cornerRadius: 20.0,
          tailWidth: 18.0,
          tailHeight: 12.0,
          tailOffsetFromLeft: 25.0,
        ),
        shadows: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SpeechBubbleShape extends ShapeBorder {
  final double cornerRadius;
  final double tailWidth;
  final double tailHeight;
  final double tailOffsetFromLeft;

  const SpeechBubbleShape({
    this.cornerRadius = 20.0,
    this.tailWidth = 22.0,
    this.tailHeight = 13.0,
    this.tailOffsetFromLeft = 25.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = cornerRadius;
    final tw = tailWidth;
    final th = tailHeight;

    final bodyRect =
        Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - th);

    final path = Path();

    path.moveTo(bodyRect.left + r, bodyRect.top);
    path.lineTo(bodyRect.right - r, bodyRect.top);
    path.arcToPoint(Offset(bodyRect.right, bodyRect.top + r),
        radius: Radius.circular(r));

    path.lineTo(bodyRect.right, bodyRect.bottom - r);
    path.arcToPoint(Offset(bodyRect.right - r, bodyRect.bottom),
        radius: Radius.circular(r));

    final tailLeftX = bodyRect.left + tailOffsetFromLeft;
    final tailRightX = tailLeftX + tw;
    final tailCenterX = tailLeftX + (tw / 2);

    path.lineTo(tailRightX, bodyRect.bottom);
    path.lineTo(tailCenterX, bodyRect.bottom + th);
    path.lineTo(tailLeftX, bodyRect.bottom);

    path.lineTo(bodyRect.left + r, bodyRect.bottom);
    path.arcToPoint(Offset(bodyRect.left, bodyRect.bottom - r),
        radius: Radius.circular(r));
    path.lineTo(bodyRect.left, bodyRect.top + r);
    path.arcToPoint(Offset(bodyRect.left + r, bodyRect.top),
        radius: Radius.circular(r));
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = AppColors.primarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
