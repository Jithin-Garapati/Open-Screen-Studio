import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/background_settings_provider.dart';
import '../../models/background_settings.dart';

class VideoBackgroundContainer extends ConsumerWidget {
  final Widget child;
  final Size videoSize;
  final double containerWidth;
  final double containerHeight;

  const VideoBackgroundContainer({
    super.key,
    required this.child,
    required this.videoSize,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backgroundSettingsProvider);
    
    // Calculate video dimensions while maintaining aspect ratio
    final videoAspectRatio = videoSize.width / videoSize.height;
    final containerAspectRatio = containerWidth / containerHeight;
    
    double videoWidth;
    double videoHeight;
    
    if (settings.maintainAspectRatio) {
      if (containerAspectRatio > videoAspectRatio) {
        videoHeight = containerHeight * settings.scale;
        videoWidth = videoHeight * videoAspectRatio;
      } else {
        videoWidth = containerWidth * settings.scale;
        videoHeight = videoWidth / videoAspectRatio;
      }
    } else {
      videoWidth = containerWidth * settings.scale;
      videoHeight = containerHeight * settings.scale;
    }
    
    final videoX = (containerWidth - videoWidth) / 2;
    final videoY = (containerHeight - videoHeight) / 2;

    return Container(
      width: containerWidth,
      height: containerHeight,
      color: settings.type == BackgroundType.color ? settings.color : Colors.transparent,
      child: Stack(
        children: [
          // Video container with padding and corner radius
          Positioned(
            left: videoX,
            top: videoY,
            width: videoWidth,
            height: videoHeight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(settings.cornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(settings.cornerRadius),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 