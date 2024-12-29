import '../entities/recording_settings.dart';
import '../entities/screen_info.dart';

abstract class RecordingRepository {
  Future<void> startRecording(RecordingSettings settings);
  Future<void> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<List<String>> getAvailableCameras();
  Future<List<String>> getAvailableMicrophones();
  Future<List<ScreenInfo>> getAvailableScreens();
  Future<void> setOutputDirectory(String path);
} 