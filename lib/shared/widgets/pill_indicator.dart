import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class PillIndicator extends StatefulWidget {
  final String text;
  final Color dotColor;

  const PillIndicator({
    super.key,
    required this.text,
    this.dotColor = AppColors.success,
  });

  @override
  State<PillIndicator> createState() => _PillIndicatorState();
}

class _PillIndicatorState extends State<PillIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPress.withValues(alpha: 0.14),
            blurRadius: 44,
            spreadRadius: 0,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: widget.dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.text,
            style: AppTypography.pillLabel,
          ),
        ],
      ),
    );
  }
}
