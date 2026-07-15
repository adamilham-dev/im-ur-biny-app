import 'package:flutter/material.dart';

/// Decorative blob background matching Figma design.
/// Three gradient-filled circles positioned for 1194x834 landscape layout.
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scaleX = size.width / 1194;
    final scaleY = size.height / 834;

    return Stack(
      children: [
        // Top-left large purple blob (560x560 at -140,-180)
        Positioned(
          left: -140 * scaleX,
          top: -180 * scaleY,
          child: Container(
            width: 560 * scaleX,
            height: 560 * scaleY,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB9A3FF).withValues(alpha: 0.15),
            ),
          ),
        ),
        // Bottom-right large blob (520x520 at 804,494)
        Positioned(
          left: 804 * scaleX,
          top: 494 * scaleY,
          child: Container(
            width: 520 * scaleX,
            height: 520 * scaleY,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFA8D8FF).withValues(alpha: 0.12),
            ),
          ),
        ),
        // Center-right medium blob (380x380 at 621,384)
        Positioned(
          left: 621 * scaleX,
          top: 384 * scaleY,
          child: Container(
            width: 380 * scaleX,
            height: 380 * scaleY,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFA3FFCF).withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}
