import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Widget that displays the camera preview fullscreen.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;
  final double opacity;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off,
                size: 64,
                color: Colors.white24,
              ),
              SizedBox(height: 16),
              Text(
                'Inizializzazione fotocamera...',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final previewSize = controller!.value.previewSize!;
    final aspectRatio = previewSize.height / previewSize.width;

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fill the available space while maintaining aspect ratio.
          // Clip any overflow so the preview covers the screen without distortion.
          return ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / aspectRatio,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: CameraPreview(controller!),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
