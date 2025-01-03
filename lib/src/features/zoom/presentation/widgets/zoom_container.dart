import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/zoom_settings_provider.dart';

class ZoomContainer extends ConsumerStatefulWidget {
  final Widget child;

  const ZoomContainer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends ConsumerState<ZoomContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _translateAnimation;
  
  ZoomSettings? _lastSettings;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize with default values
    final settings = const ZoomSettings();
    _scaleAnimation = Tween<double>(
      begin: settings.scale,
      end: settings.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _translateAnimation = Tween<Offset>(
      begin: settings.translate,
      end: settings.translate,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAnimations(ZoomSettings settings) {
    if (_lastSettings == null) {
      _lastSettings = settings;
      return;
    }

    _scaleAnimation = Tween<double>(
      begin: _lastSettings!.scale,
      end: settings.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _translateAnimation = Tween<Offset>(
      begin: _lastSettings!.translate,
      end: settings.translate,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.duration = settings.duration;
    _lastSettings = settings;
    
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(zoomSettingsProvider);
    
    if (settings != _lastSettings) {
      _updateAnimations(settings);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _scaleAnimation?.value ?? settings.scale;
        final translate = _translateAnimation?.value ?? settings.translate;
        
        return Transform(
          transform: Matrix4.identity()
            ..translate(translate.dx, translate.dy)
            ..scale(scale),
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          child: child,
        );
      },
      child: widget.child,
    );
  }
} 