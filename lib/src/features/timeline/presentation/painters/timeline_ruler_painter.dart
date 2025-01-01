import 'package:flutter/material.dart';

class TimelineRulerPainter extends CustomPainter {
  final double secondWidth;
  final Duration duration;
  final double zoom;
  final bool isScrolling;
  final bool showTimestamps;
  final double height;

  const TimelineRulerPainter({
    required this.secondWidth,
    required this.duration,
    required this.zoom,
    required this.isScrolling,
    this.showTimestamps = false,
    this.height = 32,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(isScrolling ? 0.3 : 0.5)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw major ticks (seconds)
    for (var i = 0; i <= duration.inSeconds; i++) {
      final x = i * secondWidth * zoom;
      if (x > size.width) break;

      // Draw major tick (from top)
      canvas.drawLine(
        Offset(x, 0),  // Start from top
        Offset(x, 12), // 12px down
        paint,
      );

      // Draw timestamp for major ticks (at bottom)
      if (showTimestamps && i % 5 == 0) {  // Show timestamp every 5 seconds
        final minutes = (i / 60).floor();
        final seconds = i % 60;
        final timestamp = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        
        textPainter.text = TextSpan(
          text: timestamp,
          style: TextStyle(
            color: Colors.white.withOpacity(isScrolling ? 0.3 : 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, height - 16),  // Position at bottom with 4px padding
        );
      }

      // Draw minor ticks (100ms)
      if (zoom > 0.5) {  // Only show minor ticks when zoomed in enough
        for (var j = 1; j < 10; j++) {
          final minorX = x + (j * secondWidth * zoom / 10);
          if (minorX > size.width) break;
          
          canvas.drawLine(
            Offset(minorX, 0),  // Start from top
            Offset(minorX, 6),  // 6px down for minor ticks
            paint..color = Colors.white.withOpacity(isScrolling ? 0.15 : 0.25),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(TimelineRulerPainter oldDelegate) {
    return oldDelegate.secondWidth != secondWidth ||
           oldDelegate.duration != duration ||
           oldDelegate.zoom != zoom ||
           oldDelegate.isScrolling != isScrolling ||
           oldDelegate.showTimestamps != showTimestamps ||
           oldDelegate.height != height;
  }
} 