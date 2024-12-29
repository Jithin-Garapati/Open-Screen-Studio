import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cursorSizeProvider = StateProvider<double>((ref) => 32.0);
final cursorOpacityProvider = StateProvider<double>((ref) => 1.0);
final cursorSmoothingProvider = StateProvider<bool>((ref) => true);

class CursorCustomizationPanel extends ConsumerWidget {
  const CursorCustomizationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursorSize = ref.watch(cursorSizeProvider);
    final cursorOpacity = ref.watch(cursorOpacityProvider);
    final cursorSmoothing = ref.watch(cursorSmoothingProvider);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cursor Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Cursor Size
          Row(
            children: [
              const Icon(Icons.zoom_in, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Size: ${cursorSize.toStringAsFixed(1)}px',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: cursorSize,
                      min: 16,
                      max: 64,
                      divisions: 48,
                      onChanged: (value) {
                        ref.read(cursorSizeProvider.notifier).state = value;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Cursor Opacity
          Row(
            children: [
              const Icon(Icons.opacity, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opacity: ${(cursorOpacity * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: cursorOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (value) {
                        ref.read(cursorOpacityProvider.notifier).state = value;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Cursor Smoothing
          SwitchListTile(
            title: const Text('Smooth Movement'),
            subtitle: Text(
              'Interpolate cursor position',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: cursorSmoothing,
            onChanged: (value) {
              ref.read(cursorSmoothingProvider.notifier).state = value;
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
} 