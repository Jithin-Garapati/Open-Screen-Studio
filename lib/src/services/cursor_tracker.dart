import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';
import '../models/display_info.dart';

class CursorInfo {
  final Offset position;
  final int cursorType;
  final bool isInSelectedDisplay;

  CursorInfo(this.position, this.cursorType, this.isInSelectedDisplay);
}

class CursorTracker {
  static DisplayInfo? _selectedDisplay;

  static void setSelectedDisplay(DisplayInfo display) {
    _selectedDisplay = display;
  }

  static CursorInfo? getCurrentInfo() {
    if (_selectedDisplay == null) return null;

    final point = calloc<POINT>();
    final cursorInfo = calloc<CURSORINFO>();
    cursorInfo.ref.cbSize = sizeOf<CURSORINFO>();

    try {
      final posResult = GetCursorPos(point);
      final infoResult = GetCursorInfo(cursorInfo);

      if (posResult != 0 && infoResult != 0) {
        final x = point.ref.x;
        final y = point.ref.y;

        // Check if cursor is within the selected display
        final isInSelectedDisplay = x >= _selectedDisplay!.x && 
                                  x < _selectedDisplay!.x + _selectedDisplay!.width &&
                                  y >= _selectedDisplay!.y && 
                                  y < _selectedDisplay!.y + _selectedDisplay!.height;

        if (!isInSelectedDisplay) {
          return CursorInfo(
            const Offset(-1, -1),  // Out of bounds position
            cursorInfo.ref.hCursor,
            false,
          );
        }

        // Convert to relative coordinates (0.0 to 1.0) within the selected display
        final relativeX = (x - _selectedDisplay!.x) / _selectedDisplay!.width;
        final relativeY = (y - _selectedDisplay!.y) / _selectedDisplay!.height;

        return CursorInfo(
          Offset(relativeX, relativeY),
          cursorInfo.ref.hCursor,
          true,
        );
      }
      return null;
    } finally {
      free(point);
      free(cursorInfo);
    }
  }

  // Helper method to get cursor image path based on type
  static String getCursorImage(int cursorType) {
    // Map Windows cursor handles to our custom cursor images
    if (cursorType == LoadCursor(NULL, IDC_IBEAM)) {
      return 'assets/cursors/cursor_text.png';
    } else if (cursorType == LoadCursor(NULL, IDC_SIZENS)) {
      return 'assets/cursors/cursor_resize_vertical.png';
    } else if (cursorType == LoadCursor(NULL, IDC_SIZEWE)) {
      return 'assets/cursors/cursor_resize_horizontal.png';
    } else if (cursorType == LoadCursor(NULL, IDC_HAND)) {
      return 'assets/cursors/cursor_pointer.png';
    }
    return 'assets/cursors/cursor_normal.png';
  }
} 