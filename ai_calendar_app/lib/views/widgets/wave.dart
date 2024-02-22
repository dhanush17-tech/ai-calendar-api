import 'dart:ui';

import 'package:flutter/material.dart';

class AudioWavePainter extends CustomPainter {
  final double amplitude;

  AudioWavePainter(this.amplitude);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0;

    final middle = size.height / 2;
    final width = size.width;
    final height = size.height;

    // Draw a simple line for the wave
    final path = Path();
    path.moveTo(0, middle);
    path.lineTo(width * amplitude, middle - (height * amplitude / 2));
    path.lineTo(width, middle);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
