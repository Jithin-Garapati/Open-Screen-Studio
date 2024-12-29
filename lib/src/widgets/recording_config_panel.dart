import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fpsProvider = StateProvider<int>((ref) => 30);
final bitrateProvider = StateProvider<int>((ref) => 5000); // kbps
final hwAccelProvider = StateProvider<bool>((ref) => true);
final probeSizeProvider = StateProvider<int>((ref) => 5); // MB

class RecordingConfigPanel extends ConsumerWidget {
  const RecordingConfigPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fps = ref.watch(fpsProvider);
    final bitrate = ref.watch(bitrateProvider);
    final hwAccel = ref.watch(hwAccelProvider);
    final probeSize = ref.watch(probeSizeProvider);

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
            'Recording Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // FPS Setting
          Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FPS: $fps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: fps.toDouble(),
                      min: 15,
                      max: 60,
                      divisions: 45,
                      onChanged: (value) {
                        ref.read(fpsProvider.notifier).state = value.toInt();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bitrate Setting
          Row(
            children: [
              const Icon(Icons.high_quality, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bitrate: ${bitrate}kbps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: bitrate.toDouble(),
                      min: 1000,
                      max: 10000,
                      divisions: 18,
                      onChanged: (value) {
                        ref.read(bitrateProvider.notifier).state = value.toInt();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Probe Size Setting
          Row(
            children: [
              const Icon(Icons.memory, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Probe Size: ${probeSize}MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: probeSize.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (value) {
                        ref.read(probeSizeProvider.notifier).state = value.toInt();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Hardware Acceleration Toggle
          SwitchListTile(
            title: const Text('Hardware Acceleration'),
            subtitle: Text(
              'Use GPU for encoding (recommended)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: hwAccel,
            onChanged: (value) {
              ref.read(hwAccelProvider.notifier).state = value;
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 16),
          
          // Info Text
          Text(
            'Higher values may impact performance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
} 