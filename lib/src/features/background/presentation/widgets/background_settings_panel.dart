import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/background_settings_provider.dart';
import '../../models/background_settings.dart';

class BackgroundSettingsPanel extends ConsumerWidget {
  const BackgroundSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backgroundSettingsProvider);
    final notifier = ref.read(backgroundSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Background',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Color Picker
          Text(
            'Background Color',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: settings.color ?? Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Pick a color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: settings.color ?? Colors.black,
                            onColorChanged: notifier.setColor,
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Done'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Center(
                  child: Text(
                    'Change Color',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
            
          const SizedBox(height: 16),
          
          // Corner Radius Slider
          Text(
            'Corner Radius: ${settings.cornerRadius.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: settings.cornerRadius,
            min: 0,
            max: 48,
            onChanged: notifier.setCornerRadius,
          ),
          
          const SizedBox(height: 16),
          
          // Padding Slider
          Text(
            'Padding: ${settings.padding.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: settings.padding,
            min: 0,
            max: 100,
            onChanged: notifier.setPadding,
          ),
          
          const SizedBox(height: 16),
          
          // Scale Slider
          Text(
            'Scale: ${(settings.scale * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: settings.scale,
            min: 0.5,
            max: 1.0,
            onChanged: notifier.setScale,
          ),
          
          const SizedBox(height: 16),
          
          // Maintain Aspect Ratio Toggle
          SwitchListTile(
            title: const Text(
              'Maintain Aspect Ratio',
              style: TextStyle(color: Colors.white70),
            ),
            value: settings.maintainAspectRatio,
            onChanged: notifier.setMaintainAspectRatio,
          ),
        ],
      ),
    );
  }
} 