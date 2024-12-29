import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CursorPainter extends CustomPainter {
  final ui.Image frame;
  final ui.Image cursor;
  final Offset cursorPosition;
  final double scale;

  CursorPainter({
    required this.frame,
    required this.cursor,
    required this.cursorPosition,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the frame
    canvas.drawImage(frame, Offset.zero, Paint());

    // Calculate cursor position relative to the frame size
    final cursorOffset = Offset(
      cursorPosition.dx * size.width / frame.width,
      cursorPosition.dy * size.height / frame.height,
    );

    // Draw the cursor with proper scaling
    final cursorSize = Size(cursor.width * scale, cursor.height * scale);
    final cursorRect = cursorOffset & cursorSize;
    canvas.drawImageRect(
      cursor,
      Offset.zero & Size(cursor.width.toDouble(), cursor.height.toDouble()),
      cursorRect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(CursorPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.cursor != cursor ||
        oldDelegate.cursorPosition != cursorPosition ||
        oldDelegate.scale != scale;
  }
} 