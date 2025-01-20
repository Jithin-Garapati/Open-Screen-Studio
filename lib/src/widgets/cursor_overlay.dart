import 'package:flutter/material.dart';
import '../models/cursor_type.dart';

class CursorOverlay extends StatelessWidget {
  final int cursorType;
  final Animation<double>? scaleAnimation;
  
  const CursorOverlay({
    super.key,
    this.cursorType = 65539, // Default to normal cursor
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Image.asset(
        CursorType.fromValue(cursorType).fullAssetPath,
        key: ValueKey(cursorType),
        width: 32,
        height: 32,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }
} 