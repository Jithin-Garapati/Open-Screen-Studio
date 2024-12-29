import 'package:flutter/material.dart';
import '../widgets/recording_controls.dart';
import '../widgets/preview_area.dart';
import '../widgets/settings_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Main content area (70% of width)
                Expanded(
                  flex: 7,
                  child: PreviewArea(),
                ),
                // Settings panel (30% of width)
                Expanded(
                  flex: 3,
                  child: SettingsPanel(),
                ),
              ],
            ),
          ),
          // Recording controls at bottom
          RecordingControls(),
        ],
      ),
    );
  }
} 