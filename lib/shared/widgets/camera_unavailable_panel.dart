import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/camera_init_failure.dart';
import '../../core/theme/app_colors.dart';

/// Shown inside the camera preview frame when init fails.
class CameraUnavailablePanel extends StatelessWidget {
  final CameraInitFailure? failure;
  final VoidCallback onRetry;
  final bool compact;

  const CameraUnavailablePanel({
    super.key,
    required this.failure,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final reason = failure ?? CameraInitFailure.hardwareError;
    final iconSize = compact ? 40.0 : 56.0;
    final titleSize = compact ? 13.0 : 15.0;
    final bodySize = compact ? 11.0 : 13.0;

    return ColoredBox(
      color: const Color(0xFF19162B),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                reason.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                reason.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: bodySize,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: onRetry,
                    child: Text(
                      'Coba lagi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (reason.canOpenSettings)
                    TextButton(
                      onPressed: openAppSettings,
                      child: Text(
                        'Buka Pengaturan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: bodySize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
