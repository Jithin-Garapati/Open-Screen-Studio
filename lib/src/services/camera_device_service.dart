import 'package:flutter_riverpod/flutter_riverpod.dart';

final cameraDeviceServiceProvider = Provider((ref) => CameraDeviceService());
final selectedCameraDeviceProvider = StateProvider<String?>((ref) => null);

class CameraDeviceService {
  Future<List<String>> getAvailableCameras() async {
    // TODO: Implement Windows camera device enumeration
    return [];
  }

  Future<void> startCamera(String deviceId) async {
    // TODO: Implement camera start
  }

  Future<void> stopCamera() async {
    // TODO: Implement camera stop
  }
} 