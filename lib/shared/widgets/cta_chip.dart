import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';

/// Pill-shaped CTA button matching Figma design exactly.
/// White background, no border, purple shadow, LED dot, Baloo 2 Bold text.
class CtaChip extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool pulse;

  const CtaChip({
    super.key,
    required this.label,
    this.onTap,
    this.pulse = true,
  });

  @override
  State<CtaChip> createState() => _CtaChipState();
}

class _CtaChipState extends State<CtaChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
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
    final size = MediaQuery.sizeOf(context);
    final ledSize = AppResponsive.sp(size, 14).clamp(10.0, 14.0);
    final dotSpacing = AppResponsive.rs(size, 12).clamp(8.0, 12.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: AppResponsive.paddingSymmetric(
            size,
            h: 30,
            v: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B3FD6).withValues(alpha: 0.14),
                blurRadius: 44,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LED dot (green circle matching Figma)
              Container(
                width: ledSize,
                height: ledSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3AD6A0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3AD6A0).withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: dotSpacing),
              Text(
                widget.label,
                style: GoogleFonts.baloo2(
                  fontSize: AppResponsive.sp(size, 19).clamp(14.0, 19.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPress,
                  height: 1.0,
                  letterSpacing: 0.095,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
