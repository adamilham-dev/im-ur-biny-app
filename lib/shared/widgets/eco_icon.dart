import 'package:flutter/material.dart';

/// Decorative eco-themed icon widget with floating animation.
/// Uses actual PNG assets from Figma.
class EcoIcon extends StatefulWidget {
  final String assetPath;
  final double size;
  final Duration duration;
  final double floatRange;
  final double rotation;

  const EcoIcon({
    super.key,
    required this.assetPath,
    this.size = 60,
    this.duration = const Duration(seconds: 3),
    this.floatRange = 10,
    this.rotation = 0,
  });

  @override
  State<EcoIcon> createState() => _EcoIconState();
}

class _EcoIconState extends State<EcoIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _floatAnimation = Tween<double>(begin: 0, end: widget.floatRange).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: child,
        );
      },
      child: Transform.rotate(
        angle: widget.rotation * 3.14159 / 180,
        child: Image.asset(
          widget.assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
