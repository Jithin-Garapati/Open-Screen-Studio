import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/display_info.dart';

class ScreenSelectorService {
  static Future<List<DisplayInfo>> getDisplays() async {
    final displays = <DisplayInfo>[];
    final seenMonitors = <String>{};
    
    try {
      print('Starting display enumeration...');
      
      // Get virtual screen dimensions for debugging
      final virtualLeft = GetSystemMetrics(SM_XVIRTUALSCREEN);
      final virtualTop = GetSystemMetrics(SM_YVIRTUALSCREEN);
      final virtualWidth = GetSystemMetrics(SM_CXVIRTUALSCREEN);
      final virtualHeight = GetSystemMetrics(SM_CYVIRTUALSCREEN);
      final screenWidth = GetSystemMetrics(SM_CXSCREEN);
      final screenHeight = GetSystemMetrics(SM_CYSCREEN);
      
      print('Virtual screen: ${virtualWidth}x${virtualHeight} at (${virtualLeft},${virtualTop})');
      print('Primary screen: ${screenWidth}x${screenHeight}');
      
      // Get primary monitor first
      final primaryMonitor = MonitorFromWindow(
        GetDesktopWindow(),
        MONITOR_DEFAULTTOPRIMARY,
      );
      
      if (primaryMonitor != NULL) {
        final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();
        
        try {
          if (GetMonitorInfo(primaryMonitor, info) != 0) {
            final rcMonitor = info.ref.rcMonitor;
            final width = rcMonitor.right - rcMonitor.left;
            final height = rcMonitor.bottom - rcMonitor.top;
            
            print('Found primary monitor: ${width}x${height} at (${rcMonitor.left},${rcMonitor.top})');
            
            displays.add(DisplayInfo(
              id: primaryMonitor.toString(),
              name: 'Right Display',
              width: width,
              height: height,
              x: rcMonitor.left,
              y: rcMonitor.top,
              isPrimary: true,
            ));
            seenMonitors.add(primaryMonitor.toString());
          }
        } finally {
          free(info);
        }
      }
      
      // Check for secondary monitor at key points
      final checkPoints = [
        [virtualLeft, virtualTop],                    // Top-left
        [virtualLeft + virtualWidth - 1, virtualTop], // Top-right
        [virtualLeft, virtualTop + virtualHeight - 1], // Bottom-left
        [virtualLeft + virtualWidth - 1, virtualTop + virtualHeight - 1], // Bottom-right
        [virtualLeft + screenWidth, virtualTop],      // Right of primary
        [virtualLeft - screenWidth, virtualTop],      // Left of primary
      ];
      
      print('Checking ${checkPoints.length} points for monitors...');
      
      for (final point in checkPoints) {
        final pointStruct = calloc<POINT>()
          ..ref.x = point[0]
          ..ref.y = point[1];
        
        try {
          final hMonitor = MonitorFromPoint(pointStruct.ref, MONITOR_DEFAULTTONULL);
          if (hMonitor != NULL && !seenMonitors.contains(hMonitor.toString())) {
            final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();
            
            try {
              if (GetMonitorInfo(hMonitor, info) != 0) {
                final rcMonitor = info.ref.rcMonitor;
                final width = rcMonitor.right - rcMonitor.left;
                final height = rcMonitor.bottom - rcMonitor.top;
                
                print('Found monitor at (${point[0]}, ${point[1]}): ${width}x${height} at (${rcMonitor.left},${rcMonitor.top})');
                
                // Only add if it's at a different position
                if (!displays.any((d) => d.x == rcMonitor.left && d.y == rcMonitor.top)) {
                  displays.add(DisplayInfo(
                    id: hMonitor.toString(),
                    name: 'Right Display',
                    width: width,
                    height: height,
                    x: rcMonitor.left,
                    y: rcMonitor.top,
                    isPrimary: false,
                  ));
                  seenMonitors.add(hMonitor.toString());
                }
              }
            } finally {
              free(info);
            }
          }
        } finally {
          free(pointStruct);
        }
      }
      
      if (displays.isEmpty) {
        throw Exception('No displays detected');
      }
      
      // Sort displays by x coordinate only
      displays.sort((a, b) => a.x.compareTo(b.x));
      
      // Assign directional names based on position
      if (displays.length > 1) {
        for (var i = 0; i < displays.length; i++) {
          final isLeftmost = i == 0;
          final isRightmost = i == displays.length - 1;
          
          // Compare y positions with the display to the right (if any)
          String displayName;
          if (isLeftmost) {
            displayName = 'Left Display';
          } else if (isRightmost) {
            displayName = 'Right Display';
          } else {
            // For displays in between, check if they're significantly above or below their neighbors
            final leftY = displays[i-1].y;
            final rightY = displays[i+1].y;
            final currentY = displays[i].y;
            
            if (currentY < leftY && currentY < rightY) {
              displayName = 'Top Display';
            } else if (currentY > leftY && currentY > rightY) {
              displayName = 'Bottom Display';
            } else {
              displayName = 'Right Display'; // Default to right if not clearly top/bottom
            }
          }
          
          displays[i] = displays[i].copyWith(name: displayName);
        }
      } else if (displays.length == 1) {
        // If only one display, name it based on its position relative to (0,0)
        final display = displays[0];
        String displayName;
        if (display.x < 0) {
          displayName = 'Left Display';
        } else {
          displayName = 'Right Display';
        }
        displays[0] = display.copyWith(name: displayName);
      }
      
      // Print final display list
      print('Found ${displays.length} displays:');
      for (final display in displays) {
        print('- ${display.name}: ${display.width}x${display.height} at (${display.x}, ${display.y})');
      }
      
    } catch (e, stackTrace) {
      print('Error enumerating displays: $e');
      print('Stack trace: $stackTrace');
      
      // Fallback to at least getting primary monitor if enumeration fails
      final hMonitor = MonitorFromWindow(
        GetDesktopWindow(),
        MONITOR_DEFAULTTOPRIMARY,
      );
      
      final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();
      
      try {
        if (GetMonitorInfo(hMonitor, info) != 0) {
          final rcMonitor = info.ref.rcMonitor;
          final width = rcMonitor.right - rcMonitor.left;
          final height = rcMonitor.bottom - rcMonitor.top;
          
          displays.add(DisplayInfo(
            id: hMonitor.toString(),
            name: 'Right Display',
            width: width,
            height: height,
            x: rcMonitor.left,
            y: rcMonitor.top,
            isPrimary: true,
          ));
        }
      } finally {
        free(info);
      }
    }
    
    return displays;
  }
} 