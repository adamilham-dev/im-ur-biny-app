import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// LED indicator dot with pulse animation.
class LedIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;

  const LedIndicator({
    super.key,
    this.color = AppColors.ledActive,
    this.size = 10,
    this.pulse = true,
  });

  @override
  State<LedIndicator> createState() => _LedIndicatorState();
}

class _LedIndicatorState extends State<LedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
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
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glowAnimation.value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
