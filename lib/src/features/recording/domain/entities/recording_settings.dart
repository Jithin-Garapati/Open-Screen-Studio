import 'screen_info.dart';

enum RecordingMode {
  screenOnly,
  fullScreen,
}

enum RecordingState {
  idle,
  recording,
  paused,
}

class RecordingSettings {
  final RecordingMode mode;
  final bool isCameraEnabled;
  final bool isMicrophoneEnabled;
  final bool isSystemAudioEnabled;
  final String? selectedCamera;
  final String? selectedMicrophone;
  final RecordingState state;
  final ScreenInfo? selectedScreen;
  final String? outputDirectory;

  const RecordingSettings({
    this.mode = RecordingMode.screenOnly,
    this.isCameraEnabled = false,
    this.isMicrophoneEnabled = false,
    this.isSystemAudioEnabled = false,
    this.selectedCamera,
    this.selectedMicrophone,
    this.state = RecordingState.idle,
    this.selectedScreen,
    this.outputDirectory,
  });

  RecordingSettings copyWith({
    RecordingMode? mode,
    bool? isCameraEnabled,
    bool? isMicrophoneEnabled,
    bool? isSystemAudioEnabled,
    String? selectedCamera,
    String? selectedMicrophone,
    RecordingState? state,
    ScreenInfo? selectedScreen,
    String? outputDirectory,
  }) {
    return RecordingSettings(
      mode: mode ?? this.mode,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      isSystemAudioEnabled: isSystemAudioEnabled ?? this.isSystemAudioEnabled,
      selectedCamera: selectedCamera ?? this.selectedCamera,
      selectedMicrophone: selectedMicrophone ?? this.selectedMicrophone,
      state: state ?? this.state,
      selectedScreen: selectedScreen ?? this.selectedScreen,
      outputDirectory: outputDirectory ?? this.outputDirectory,
    );
  }
} 