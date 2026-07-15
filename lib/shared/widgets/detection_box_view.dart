import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One labelled detection box, in ORIGINAL-image pixel coordinates.
class DetectionBox {
  final Rect rectPx;
  final String label;
  final Color color;
  final bool highlighted;
  const DetectionBox({
    required this.rectPx,
    required this.label,
    required this.color,
    this.highlighted = false,
  });
}

/// Renders the full captured frame (BoxFit.contain) with dashed bounding-box
/// overlays + label chips — like a live-camera detection view. Replaces the
/// zoomed single-crop preview so every detected object stays in context.
class DetectionBoxView extends StatefulWidget {
  final Uint8List imageBytes;
  final List<DetectionBox> boxes;
  const DetectionBoxView({
    super.key,
    required this.imageBytes,
    required this.boxes,
  });

  @override
  State<DetectionBoxView> createState() => _DetectionBoxViewState();
}

class _DetectionBoxViewState extends State<DetectionBoxView> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(DetectionBoxView old) {
    super.didUpdateWidget(old);
    if (old.imageBytes != widget.imageBytes) {
      _image = null;
      _decode();
    }
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      // While decoding, show the frame plain (contain) to avoid a flash.
      return Image.memory(widget.imageBytes, fit: BoxFit.contain);
    }
    return CustomPaint(
      painter: _DetectionPainter(image, widget.boxes),
      size: Size.infinite,
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final ui.Image image;
  final List<DetectionBox> boxes;
  _DetectionPainter(this.image, this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw == 0 || ih == 0) return;

    // BoxFit.contain transform.
    final s = (size.width / iw).clamp(0.0, double.infinity);
    final scale = s < size.height / ih ? s : size.height / ih;
    final dw = iw * scale;
    final dh = ih * scale;
    final ox = (size.width - dw) / 2;
    final oy = (size.height - dh) / 2;

    // Draw the image.
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH(ox, oy, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );

    for (final b in boxes) {
      final r = Rect.fromLTRB(
        ox + b.rectPx.left * scale,
        oy + b.rectPx.top * scale,
        ox + b.rectPx.right * scale,
        oy + b.rectPx.bottom * scale,
      );
      if (r.width < 2 || r.height < 2) continue;

      final stroke = b.highlighted ? 3.5 : 2.2;
      _drawDashedRRect(canvas, r, b.color, stroke);
      _drawLabel(canvas, r, b.label, b.color);
    }
  }

  void _drawDashedRRect(Canvas canvas, Rect r, Color color, double stroke) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const dash = 9.0;
    const gap = 6.0;
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(8));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  void _drawLabel(Canvas canvas, Rect box, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 8.0;
    const padV = 4.0;
    const dot = 7.0;
    final chipW = tp.width + padH * 2 + dot + 5;
    final chipH = tp.height + padV * 2;

    // Place chip above the box; if no room, place inside the top edge.
    var cx = box.left;
    var cy = box.top - chipH - 4;
    if (cy < 0) cy = box.top + 4;
    if (cx + chipW > box.right + chipW) {} // keep left-aligned to box

    final chipRect = Rect.fromLTWH(cx, cy, chipW, chipH);
    final chipRR = RRect.fromRectAndRadius(chipRect, const Radius.circular(8));
    canvas.drawRRect(
      chipRR,
      Paint()..color = const Color(0xF20E0E14),
    );
    // colored dot
    canvas.drawCircle(
      Offset(cx + padH + dot / 2, cy + chipH / 2),
      dot / 2,
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(cx + padH + dot + 5, cy + padV));
  }

  @override
  bool shouldRepaint(_DetectionPainter old) =>
      old.image != image || old.boxes != boxes;
}
