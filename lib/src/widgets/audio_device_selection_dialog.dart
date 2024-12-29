import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_device_service.dart';

class AudioDeviceSelectionDialog extends ConsumerWidget {
  const AudioDeviceSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.black.withOpacity(0.8),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volume_up_outlined, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Select Audio Output',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AudioDevice>>(
              future: ref.read(audioDeviceServiceProvider).getAudioOutputDevices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading audio devices',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  );
                }

                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return const Center(
                    child: Text(
                      'No audio devices found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isSelected = ref.watch(selectedAudioDeviceProvider)?.id == device.id;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Text(
                          device.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: device.isDefault
                            ? Text(
                                'Default Device',
                                style: TextStyle(
                                  color: Colors.blue[300],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onTap: () {
                          ref.read(selectedAudioDeviceProvider.notifier).state = device;
                          Navigator.of(context).pop(device);
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 