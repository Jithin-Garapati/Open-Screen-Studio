import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioDevice {
  final String id;
  final String name;
  final bool isDefault;

  AudioDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
  });
}

class AudioDeviceService {
  Future<List<AudioDevice>> getAudioOutputDevices() async {
    try {
      print('Listing audio devices...');
      
      // Just return the virtual audio capturer
      final devices = <AudioDevice>[
        AudioDevice(
          id: 'virtual-audio-capturer',
          name: 'System Audio',
          isDefault: true,
        ),
      ];

      print('Found ${devices.length} devices:');
      for (var device in devices) {
        print('- ${device.name} (${device.id})');
      }

      return devices;
    } catch (e, stackTrace) {
      print('Error getting audio devices: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}

final audioDeviceServiceProvider = Provider((ref) => AudioDeviceService());
final selectedAudioDeviceProvider = StateProvider<AudioDevice?>((ref) => null); 