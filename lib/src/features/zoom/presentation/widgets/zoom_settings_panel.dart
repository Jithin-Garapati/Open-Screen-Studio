import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/zoom_settings_provider.dart';

class ZoomSettingsPanel extends ConsumerWidget {
  const ZoomSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(zoomSettingsProvider);
    final notifier = ref.read(zoomSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zoom Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Auto Zoom Toggle
          SwitchListTile(
            title: const Text(
              'Auto Zoom',
              style: TextStyle(color: Colors.white70),
            ),
            subtitle: const Text(
              'Automatically follow cursor',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            value: settings.isAutoZoom,
            onChanged: notifier.setAutoZoom,
          ),
          
          const SizedBox(height: 16),
          
          // Manual Target Position (when auto-zoom is off)
          if (!settings.isAutoZoom) ...[
            const Text(
              'Target Position',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'X: ${settings.target.dx.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      Slider(
                        value: settings.target.dx,
                        min: 0,
                        max: 1,
                        onChanged: (value) {
                          notifier.setTarget(Offset(value, settings.target.dy));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Y: ${settings.target.dy.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      Slider(
                        value: settings.target.dy,
                        min: 0,
                        max: 1,
                        onChanged: (value) {
                          notifier.setTarget(Offset(settings.target.dx, value));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Scale Slider
          Text(
            'Scale: ${(settings.scale * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: settings.scale,
            min: 1.0,
            max: 5.0,
            onChanged: notifier.setScale,
          ),
          
          const SizedBox(height: 16),
          
          // Animation Duration
          Text(
            'Animation Duration: ${settings.duration.inMilliseconds}ms',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: settings.duration.inMilliseconds.toDouble(),
            min: 100,
            max: 1000,
            divisions: 9,
            onChanged: (value) {
              notifier.setDuration(Duration(milliseconds: value.round()));
            },
          ),
          
          const SizedBox(height: 16),
          
          // Reset Button
          Center(
            child: ElevatedButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Zoom'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 