import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/recording_settings.dart';
import '../../domain/entities/screen_info.dart';
import '../../domain/repositories/recording_repository.dart';
import '../../data/repositories/recording_repository_impl.dart';

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepositoryImpl();
});

final availableScreensProvider = FutureProvider<List<ScreenInfo>>((ref) {
  final repository = ref.watch(recordingRepositoryProvider);
  return repository.getAvailableScreens();
});

final recordingControllerProvider = StateNotifierProvider<RecordingController, RecordingSettings>((ref) {
  final repository = ref.watch(recordingRepositoryProvider);
  return RecordingController(repository);
});

class RecordingController extends StateNotifier<RecordingSettings> {
  final RecordingRepository _repository;

  RecordingController(this._repository) : super(const RecordingSettings()) {
    _initializeDevices();
  }

  Future<void> _initializeDevices() async {
    final cameras = await _repository.getAvailableCameras();
    final microphones = await _repository.getAvailableMicrophones();
    final screens = await _repository.getAvailableScreens();

    if (cameras.isNotEmpty) {
      state = state.copyWith(selectedCamera: cameras.first);
    }
    if (microphones.isNotEmpty) {
      state = state.copyWith(selectedMicrophone: microphones.first);
    }
    if (screens.isNotEmpty) {
      state = state.copyWith(selectedScreen: screens.firstWhere((s) => s.isPrimary));
    }
  }

  void setMode(RecordingMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setScreen(ScreenInfo screen) {
    state = state.copyWith(selectedScreen: screen);
  }

  void setOutputDirectory(String path) {
    state = state.copyWith(outputDirectory: path);
    _repository.setOutputDirectory(path);
  }

  void toggleCamera() {
    state = state.copyWith(isCameraEnabled: !state.isCameraEnabled);
  }

  void toggleMicrophone() {
    state = state.copyWith(isMicrophoneEnabled: !state.isMicrophoneEnabled);
  }

  void setCamera(String camera) {
    state = state.copyWith(selectedCamera: camera);
  }

  void setMicrophone(String microphone) {
    state = state.copyWith(selectedMicrophone: microphone);
  }

  Future<void> startRecording() async {
    if (state.selectedScreen == null) {
      throw Exception('No screen selected for recording');
    }
    
    state = state.copyWith(state: RecordingState.recording);
    await _repository.startRecording(state);
  }

  Future<void> stopRecording() async {
    await _repository.stopRecording();
    state = state.copyWith(state: RecordingState.idle);
  }

  Future<void> pauseRecording() async {
    await _repository.pauseRecording();
    state = state.copyWith(state: RecordingState.paused);
  }

  Future<void> resumeRecording() async {
    await _repository.resumeRecording();
    state = state.copyWith(state: RecordingState.recording);
  }
} 