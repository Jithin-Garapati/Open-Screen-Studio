import 'package:flutter/material.dart';
import '../../constants/timeline_colors.dart';

class TimelinePlayhead extends StatefulWidget {
  final double position;
  final bool isDragging;
  final bool isMoving;
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;

  const TimelinePlayhead({
    super.key,
    required this.position,
    this.isDragging = false,
    this.isMoving = false,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<TimelinePlayhead> createState() => _TimelinePlayheadState();
}

class _TimelinePlayheadState extends State<TimelinePlayhead> with SingleTickerProviderStateMixin {
  double _visualPosition = 0;
  bool _isDragging = false;
  double _startDragX = 0;
  double _lastDragX = 0;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _visualPosition = widget.position;
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(TimelinePlayhead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _visualPosition = widget.position;
      if (widget.isMoving && !_scaleController.isAnimating) {
        _scaleController.forward().then((_) => _scaleController.reverse());
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isDragging || widget.isMoving;
    final Color lineColor = isActive ? kPlayheadColor : Colors.white.withOpacity(0.6);
    final Color handleColor = isActive ? kPlayheadColor : Colors.white.withOpacity(0.8);

    return RepaintBoundary(
      child: Stack(
        children: [
          // Main playhead line
          Positioned(
            left: _visualPosition - 0.5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 1,
              decoration: BoxDecoration(
                color: lineColor,
                boxShadow: isActive ? [
                  BoxShadow(
                    color: kPlayheadColor.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Top handle
          Positioned(
            left: _visualPosition - 8,
            top: 4,
            child: MouseRegion(
              cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  _isDragging = true;
                  _startDragX = details.globalPosition.dx;
                  _lastDragX = _visualPosition;
                  _scaleController.forward();
                  setState(() {});
                },
                onHorizontalDragUpdate: (details) {
                  if (_isDragging) {
                    final delta = details.globalPosition.dx - _startDragX;
                    setState(() {
                      _visualPosition = _lastDragX + delta;
                    });
                    widget.onDragUpdate?.call(_visualPosition);
                  }
                },
                onHorizontalDragEnd: (details) {
                  _isDragging = false;
                  _scaleController.reverse();
                  widget.onDragEnd?.call(_visualPosition);
                  setState(() {});
                },
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 150),
                    tween: Tween<double>(
                      begin: 0.0,
                      end: isActive ? 1.0 : 0.0,
                    ),
                    builder: (context, value, child) {
                      return Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: handleColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? kPlayheadColor : Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kPlayheadColor.withOpacity(0.5 * value),
                              blurRadius: 8 + (4 * value),
                              spreadRadius: 2 * value,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3 * (1 - value)),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 4 + (value * 2),
                            height: 4 + (value * 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? kPlayheadColor : Colors.black.withOpacity(0.3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 