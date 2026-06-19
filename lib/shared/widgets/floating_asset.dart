import 'package:flutter/material.dart';
import 'dart:math' as math;

class FloatingAsset extends StatefulWidget {
  final Widget child;
  final double width;
  final double height;
  final double rotationDegree;
  final Duration animationDuration;
  final Offset movementRange;
  final double initialPhase;

  const FloatingAsset({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.rotationDegree = 0.0,
    this.animationDuration = const Duration(seconds: 4),
    this.movementRange = const Offset(10, 10),
    this.initialPhase = 0.0,
  });

  @override
  State<FloatingAsset> createState() => _FloatingAssetState();
}

class _FloatingAssetState extends State<FloatingAsset>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _controller.value = widget.initialPhase;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double rotationRadian = widget.rotationDegree * (math.pi / 180);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double dx =
            math.sin(_controller.value * 2 * math.pi) * widget.movementRange.dx;
        final double dy =
            math.cos(_controller.value * 2 * math.pi) * widget.movementRange.dy;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rotationRadian,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
