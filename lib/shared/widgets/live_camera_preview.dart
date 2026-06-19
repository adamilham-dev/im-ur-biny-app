import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera feed scaled with [BoxFit.cover] to fill the parent bounds.
class LiveCameraPreview extends StatelessWidget {
  final CameraController controller;

  const LiveCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF19162B));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }

        // previewSize is always in sensor (landscape) orientation; swap when
        // the preview texture is rotated for portrait UI.
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final w = isPortrait ? previewSize.height : previewSize.width;
        final h = isPortrait ? previewSize.width : previewSize.height;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: w,
                height: h,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
