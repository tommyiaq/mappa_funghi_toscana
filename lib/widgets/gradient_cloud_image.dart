import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GradientCloudImage extends ImageProvider<GradientCloudImage> {
  final double opacity;
  final Color color;
  
  const GradientCloudImage({
    required this.opacity, 
    this.color = Colors.red,
  });

  @override
  Future<GradientCloudImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<GradientCloudImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      GradientCloudImage key, ImageDecoderCallback decode) {
    const int size = 512;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Color.alphaBlend(color.withAlpha((opacity * 255).toInt()), Colors.transparent),
          Color.alphaBlend(color.withAlpha(0), Colors.transparent),
        ],
        [0.0, 1.0],
        ui.TileMode.clamp,
      );

    canvas.drawCircle(center, radius, paint);
    final picture = recorder.endRecording();
    final imageFuture = picture.toImage(size, size);
    return OneFrameImageStreamCompleter(
      imageFuture.then((img) => ImageInfo(image: img, scale: 1.0)),
    );
  }

  @override
  bool operator ==(Object other) => 
      other is GradientCloudImage && 
      opacity == other.opacity && 
      color == other.color;

  @override
  int get hashCode => opacity.hashCode ^ color.hashCode;
}
