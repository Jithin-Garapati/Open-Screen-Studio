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
  static bool _isUpdating = false;

  static void setSelectedDisplay(DisplayInfo display) {
    _selectedDisplay = display;
  }

  static CursorInfo? getCurrentInfo() {
    if (_selectedDisplay == null || _isUpdating) return null;

    _isUpdating = true;
    try {
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
              mapCursorType(LoadCursor(NULL, IDC_ARROW)),
              false,
            );
          }

          // Convert to relative coordinates (0.0 to 1.0) within the selected display
          final relativeX = (x - _selectedDisplay!.x) / _selectedDisplay!.width;
          final relativeY = (y - _selectedDisplay!.y) / _selectedDisplay!.height;

          // Check if cursor is visible and get its handle
          final cursorHandle = (cursorInfo.ref.flags & 0x00000001 != 0) 
              ? cursorInfo.ref.hCursor 
              : LoadCursor(NULL, IDC_ARROW);

          return CursorInfo(
            Offset(relativeX, relativeY),
            mapCursorType(cursorHandle),
            true,
          );
        }
        return null;
      } finally {
        free(point);
        free(cursorInfo);
      }
    } finally {
      _isUpdating = false;
    }
  }

  // Map Windows cursor handles to our fixed cursor types
  static int mapCursorType(int windowsCursorHandle) {
    // Get standard cursor handles for comparison
    final arrowHandle = LoadCursor(NULL, IDC_ARROW);
    final ibeamHandle = LoadCursor(NULL, IDC_IBEAM);
    final handHandle = LoadCursor(NULL, IDC_HAND);
    final sizeweHandle = LoadCursor(NULL, IDC_SIZEWE);
    final sizensHandle = LoadCursor(NULL, IDC_SIZENS);

    debugPrint('Mapping cursor handle: $windowsCursorHandle');
    debugPrint('Standard handles - Arrow: $arrowHandle, IBeam: $ibeamHandle, Hand: $handHandle');

    // Compare with standard cursor handles
    if (windowsCursorHandle == arrowHandle) {
      return 65539; // Normal cursor
    } else if (windowsCursorHandle == ibeamHandle) {
      return 65541; // Text cursor
    } else if (windowsCursorHandle == handHandle) {
      return 65567; // Hand pointer
    } else if (windowsCursorHandle == sizeweHandle) {
      return 65569; // Horizontal resize
    } else if (windowsCursorHandle == sizensHandle) {
      return 65551; // Vertical resize
    }
    return 65539; // Default to normal cursor
  }

  // Helper method to get cursor image path based on type
  static String getCursorImage(int cursorType) {
    // Map our fixed cursor types to image paths
    switch (cursorType) {
      case 65541: // Text cursor
        return 'assets/cursors/cursor_text.png';
      case 65551: // Vertical resize
        return 'assets/cursors/cursor_resize_vertical.png';
      case 65569: // Horizontal resize
        return 'assets/cursors/cursor_resize_horizontal.png';
      case 65567: // Hand pointer
        return 'assets/cursors/cursor_pointer.png';
      default:
        return 'assets/cursors/cursor_normal.png';
    }
  }
} 