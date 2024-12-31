import 'package:flutter/material.dart';

class TimelineRulerPainter extends CustomPainter {
  final double secondWidth;
  final Duration duration;
  final double zoom;
  final bool isScrolling;

  TimelineRulerPainter({
    required this.secondWidth,
    required this.duration,
    required this.zoom,
    required this.isScrolling,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isScrolling) return; // Skip ruler drawing while scrolling for better performance

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final majorPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Calculate marker intervals based on zoom
    final markerInterval = _calculateMarkerInterval(zoom);
    final majorInterval = markerInterval * 5;

    // Draw vertical lines and time markers
    for (var i = 0; i <= duration.inSeconds; i++) {
      final x = i * secondWidth;
      final seconds = i;
      final isMajor = seconds % majorInterval == 0;
      final isMinor = seconds % markerInterval == 0;

      if (isMajor || isMinor) {
        // Draw marker line
        canvas.drawLine(
          Offset(x, isMajor ? 0 : size.height * 0.3),
          Offset(x, size.height),
          isMajor ? majorPaint : paint,
        );

        // Draw time label
        if (isMajor || (isMinor && zoom > 0.5)) {
          final time = Duration(seconds: seconds);
          final text = _formatDuration(time, isMajor);
          textPainter.text = TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.white.withOpacity(isMajor ? 0.8 : 0.5),
              fontSize: isMajor ? 11 : 9,
              fontWeight: isMajor ? FontWeight.w500 : FontWeight.normal,
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, isMajor ? 2 : 8),
          );
        }
      }
    }
  }

  int _calculateMarkerInterval(double zoom) {
    if (zoom >= 2.0) return 1;      // 1 second
    if (zoom >= 1.0) return 5;      // 5 seconds
    if (zoom >= 0.5) return 15;     // 15 seconds
    if (zoom >= 0.25) return 30;    // 30 seconds
    return 60;                      // 1 minute
  }

  String _formatDuration(Duration duration, bool isMajor) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return isMajor ? '$minutes:${seconds.toString().padLeft(2, '0')}' : seconds.toString();
    }
    return seconds.toString();
  }

  @override
  bool shouldRepaint(TimelineRulerPainter oldDelegate) =>
      oldDelegate.secondWidth != secondWidth ||
      oldDelegate.duration != duration ||
      oldDelegate.zoom != zoom ||
      oldDelegate.isScrolling != isScrolling;
} 