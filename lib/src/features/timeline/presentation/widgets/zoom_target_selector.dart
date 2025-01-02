import 'package:flutter/material.dart';
import '../../models/zoom_settings.dart';

class ZoomTargetSelector extends StatefulWidget {
  final ZoomSettings settings;
  final ValueChanged<ZoomSettings> onSettingsChanged;
  final Size videoSize;
  final bool isActive;

  const ZoomTargetSelector({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.videoSize,
    this.isActive = false,
  });

  @override
  State<ZoomTargetSelector> createState() => _ZoomTargetSelectorState();
}

class _ZoomTargetSelectorState extends State<ZoomTargetSelector> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTargetPosition(Offset localPosition) {
    final normalizedPosition = Offset(
      (localPosition.dx / widget.videoSize.width).clamp(0.0, 1.0),
      (localPosition.dy / widget.videoSize.height).clamp(0.0, 1.0),
    );

    widget.onSettingsChanged(
      widget.settings.copyWith(target: normalizedPosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Transparent overlay for drag detection
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              setState(() => _isDragging = true);
              _updateTargetPosition(details.localPosition);
            },
            onPanUpdate: (details) {
              _updateTargetPosition(details.localPosition);
            },
            onPanEnd: (_) {
              setState(() => _isDragging = false);
            },
            child: Container(
              color: Colors.transparent,
              child: MouseRegion(
                cursor: widget.isActive ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
          ),
        ),

        // Zoom target indicator
        if (widget.isActive)
          Positioned(
            left: widget.settings.target.dx * widget.videoSize.width - 24,
            top: widget.settings.target.dy * widget.videoSize.height - 24,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _isDragging ? 1.2 : _pulseAnimation.value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
} 