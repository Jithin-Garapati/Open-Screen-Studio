import 'package:flutter/material.dart';

class TimelineGridOverlayPainter extends CustomPainter {
  final double secondWidth;
  final double zoom;

  const TimelineGridOverlayPainter({
    required this.secondWidth,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)  // Very subtle grid
      ..strokeWidth = 1;

    // Draw vertical grid lines
    for (var i = 0; i <= size.width / (secondWidth * zoom); i++) {
      final x = i * secondWidth * zoom;
      if (x > size.width) break;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal grid lines
    final spacing = 4.0;  // 4px spacing between lines
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Add a subtle gradient overlay
    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.02),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 1.0],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(gradientRect);

    canvas.drawRect(gradientRect, gradientPaint);
  }

  @override
  bool shouldRepaint(TimelineGridOverlayPainter oldDelegate) {
    return oldDelegate.secondWidth != secondWidth ||
           oldDelegate.zoom != zoom;
  }
} 