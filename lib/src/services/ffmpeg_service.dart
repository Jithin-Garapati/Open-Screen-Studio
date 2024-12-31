import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/recording_config_panel.dart';

class FFmpegService {
  final ProviderRef ref;

  FFmpegService(this.ref);

  List<String> buildFFmpegArgs({
    required String outputPath,
    String? audioDevice,
    String? cameraDevice,
    Map<String, int>? region,
    bool showCursor = true,
    bool captureSystemAudio = false,
  }) {
    final fps = ref.read(fpsProvider);
    final bitrate = ref.read(bitrateProvider);
    final hwAccel = ref.read(hwAccelProvider);
    final probeSize = ref.read(probeSizeProvider);

    final args = <String>[
      // Input options
      '-f', 'gdigrab',
      '-probesize', '${probeSize}M',
      '-framerate', '$fps',
      '-draw_mouse', showCursor ? '1' : '0',
    ];

    // Add region parameters if specified
    if (region != null) {
      args.addAll([
        '-offset_x', '${region['x']}',
        '-offset_y', '${region['y']}',
        '-video_size', '${region['width']}x${region['height']}',
      ]);
    }

    args.addAll(['-i', 'desktop']);

    // Add camera input if specified
    if (cameraDevice != null) {
      args.addAll([
        '-f', 'dshow',
        '-i', 'video=$cameraDevice',
      ]);
    }

    // Add system audio input if enabled
    if (captureSystemAudio) {
      print('Adding system audio capture');
      args.addAll([
        '-f', 'dshow',
        // Add audio buffer and sync options
        '-audio_buffer_size', '20',
        '-i', 'audio=virtual-audio-capturer',
      ]);
    }

    // Add microphone input if specified
    if (audioDevice != null) {
      args.addAll([
        '-f', 'dshow',
        '-i', audioDevice,
      ]);
    }

    // Build filter complex for combining video streams
    final filters = <String>[];
    if (cameraDevice != null) {
      // Scale camera input to a reasonable size (e.g., 320x240) and position it in the corner
      filters.add('[1:v]scale=320:-1[camera]');
      filters.add('[0:v][camera]overlay=main_w-overlay_w-10:main_h-overlay_h-10[outv]');
    }

    // Output options
    if (filters.isNotEmpty) {
      args.addAll([
        '-filter_complex', filters.join(';'),
        '-map', '[outv]',
      ]);
    }

    args.addAll([
      '-c:v', hwAccel ? 'h264_nvenc' : 'libx264',
      '-preset', hwAccel ? 'p4' : 'veryfast',
      '-b:v', '${bitrate}k',
      '-pix_fmt', 'yuv420p',
    ]);

    // Audio codec settings if we have any audio
    if (captureSystemAudio || audioDevice != null) {
      args.addAll([
        '-c:a', 'aac',
        '-b:a', '192k',
        '-ac', '2',  // Force stereo output
        '-ar', '44100',  // Set sample rate
        '-vsync', '1',  // Video sync method
        '-max_interleave_delta', '0',  // Minimize interleave delay
      ]);

      // If both system audio and microphone are enabled, mix them
      if (captureSystemAudio && audioDevice != null) {
        args.addAll([
          '-filter_complex', '[1:a][2:a]amix=inputs=2[a]',
          '-map', '0:v',
          '-map', '[a]',
        ]);
      }
    }

    // Add overwrite flag
    args.add('-y');
    args.add(outputPath);

    print('FFmpeg command: ffmpeg ${args.join(' ')}');
    return args;
  }

  String getFfmpegCommand({
    required String outputPath,
    String? audioDevice,
    String? cameraDevice,
    Map<String, int>? region,
    bool showCursor = true,
  }) {
    final args = buildFFmpegArgs(
      outputPath: outputPath,
      audioDevice: audioDevice,
      cameraDevice: cameraDevice,
      region: region,
      showCursor: showCursor,
    );
    return 'ffmpeg ${args.join(' ')}';
  }
}

final ffmpegServiceProvider = Provider((ref) => FFmpegService(ref)); 