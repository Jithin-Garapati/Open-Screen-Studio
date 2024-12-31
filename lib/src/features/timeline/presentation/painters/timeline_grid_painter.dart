import 'package:flutter/material.dart';

const kGridColor = Color(0xFF2C2C2E);

class TimelineGridPainter extends CustomPainter {
  final double secondWidth;
  final Duration duration;
  final double zoom;
  final bool isScrolling;

  TimelineGridPainter({
    required this.secondWidth,
    required this.duration,
    required this.zoom,
    required this.isScrolling,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isScrolling) return; // Skip grid drawing while scrolling for better performance

    final paint = Paint()
      ..color = kGridColor.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw vertical grid lines
    for (var i = 0; i <= duration.inSeconds; i++) {
      final x = i * secondWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TimelineGridPainter oldDelegate) =>
      oldDelegate.secondWidth != secondWidth ||
      oldDelegate.zoom != zoom ||
      oldDelegate.isScrolling != isScrolling;
} 