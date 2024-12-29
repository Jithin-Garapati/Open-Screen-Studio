import '../../domain/entities/recording_settings.dart';
import '../../domain/entities/screen_info.dart';
import '../../domain/repositories/recording_repository.dart';
import '../services/win32_screen_recorder.dart';

class RecordingRepositoryImpl implements RecordingRepository {
  final _screenRecorder = Win32ScreenRecorder();
  String? _lastRecordingPath;
  String? _outputDirectory;

  @override
  Future<List<String>> getAvailableCameras() async {
    // TODO: Implement camera detection
    return ['FaceTime HD Camera'];
  }

  @override
  Future<List<String>> getAvailableMicrophones() async {
    // TODO: Implement microphone detection
    return ['Default System Microphone'];
  }

  @override
  Future<List<ScreenInfo>> getAvailableScreens() {
    return _screenRecorder.getAvailableScreens();
  }

  @override
  Future<void> pauseRecording() async {
    // TODO: Implement pause recording
  }

  @override
  Future<void> resumeRecording() async {
    // TODO: Implement resume recording
  }

  @override
  Future<void> setOutputDirectory(String path) async {
    _outputDirectory = path;
  }

  @override
  Future<void> startRecording(RecordingSettings settings) async {
    if (settings.selectedScreen == null) {
      throw Exception('No screen selected for recording');
    }

    await _screenRecorder.startRecording(
      screen: settings.selectedScreen!,
      customOutputPath: _outputDirectory,
    );
  }

  @override
  Future<void> stopRecording() async {
    _lastRecordingPath = await _screenRecorder.stopRecording();
    if (_lastRecordingPath != null) {
      print('Recording saved to: $_lastRecordingPath');
    }
  }

  bool get isRecording => _screenRecorder.isRecording;
  Duration get recordingDuration => _screenRecorder.recordingDuration;
  String? get lastRecordingPath => _lastRecordingPath;
} 