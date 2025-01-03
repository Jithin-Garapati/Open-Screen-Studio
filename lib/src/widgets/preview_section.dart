import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preview_service.dart';
import '../models/display_info.dart';

class PreviewSection extends ConsumerStatefulWidget {
  final DisplayInfo? selectedDisplay;
  final bool isMicEnabled;
  final bool isSystemAudioEnabled;

  const PreviewSection({
    super.key,
    this.selectedDisplay,
    this.isMicEnabled = false,
    this.isSystemAudioEnabled = false,
  });

  @override
  ConsumerState<PreviewSection> createState() => _PreviewSectionState();
}

class _PreviewSectionState extends ConsumerState<PreviewSection> {
  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void didUpdateWidget(PreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDisplay != oldWidget.selectedDisplay ||
        widget.isMicEnabled != oldWidget.isMicEnabled ||
        widget.isSystemAudioEnabled != oldWidget.isSystemAudioEnabled) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    final previewService = ref.read(previewServiceProvider);
    previewService.stopPreview();
    previewService.stopAudioMonitoring();

    if (widget.selectedDisplay != null) {
      previewService.startPreview(widget.selectedDisplay!);
    }
    if (widget.isMicEnabled || widget.isSystemAudioEnabled) {
      previewService.startAudioMonitoring();
    }
  }

  @override
  void dispose() {
    final previewService = ref.read(previewServiceProvider);
    previewService.stopPreview();
    previewService.stopAudioMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (widget.isMicEnabled)
                StreamBuilder<double>(
                  stream: ref.watch(previewServiceProvider).micLevelStream,
                  builder: (context, snapshot) {
                    return AudioVisualizer(
                      level: snapshot.data ?? 0,
                      color: Colors.blue,
                      icon: Icons.mic,
                    );
                  },
                ),
              if (widget.isSystemAudioEnabled) ...[
                const SizedBox(width: 8),
                StreamBuilder<double>(
                  stream: ref.watch(previewServiceProvider).systemAudioLevelStream,
                  builder: (context, snapshot) {
                    return AudioVisualizer(
                      level: snapshot.data ?? 0,
                      color: Colors.green,
                      icon: Icons.volume_up,
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.selectedDisplay == null
                  ? const Center(
                      child: Text(
                        'Select a display or window to preview',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : StreamBuilder<ui.Image?>(
                      stream: ref.watch(previewServiceProvider).previewStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Text(
                              'No Preview',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return RawImage(
                          image: snapshot.data,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioVisualizer extends StatelessWidget {
  final double level;
  final Color color;
  final IconData icon;

  const AudioVisualizer({
    super.key,
    required this.level,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Container(
          width: 50,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: level,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
} 