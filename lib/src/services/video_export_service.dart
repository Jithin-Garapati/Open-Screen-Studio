import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class VideoExportService {
  // Path to the C++ backend executable and build script
  static final String _backendPath = Platform.isWindows 
      ? 'Videoeditor'
      : 'Videoeditor';
  
  static final String _buildScript = Platform.isWindows 
      ? 'build.bat'
      : 'build.sh';

  static Future<String> _getExecutablePath() async {
    // Get the app's root directory (where pubspec.yaml is)
    final appDir = Directory.current.path;
    
    // First check if executable exists in the Flutter build directory
    final flutterBuildDir = path.join(
      appDir, 
      'build', 
      'windows', 
      'runner',
      kDebugMode ? 'Debug' : 'Release'
    );
    
    final executableInBuildDir = path.join(flutterBuildDir, 'Videoeditor.exe');
    print('Checking for executable in Flutter build dir: $executableInBuildDir');
    
    if (await File(executableInBuildDir).exists()) {
      // Verify DLLs exist in the same directory
      if (await _verifyDLLs(flutterBuildDir)) {
        return executableInBuildDir;
      }
    }
    
    // If not found in build dir, check backend build directory
    final backendDir = path.join(appDir, _backendPath);
    final buildType = kDebugMode ? 'Debug' : 'Release';
    final executableInBackendDir = path.join(
      backendDir,
      'x64',
      buildType,
      'Videoeditor.exe'
    );
    
    print('Checking for executable in backend dir: $executableInBackendDir');
    
    // If executable doesn't exist or DLLs are missing, try building
    if (!await File(executableInBackendDir).exists() || 
        !await _verifyDLLs(path.dirname(executableInBackendDir))) {
      print('Backend executable or DLLs not found, attempting to build...');
      
      final buildScriptPath = path.join(backendDir, _buildScript);
      
      // Verify build script exists
      if (!await File(buildScriptPath).exists()) {
        throw Exception('''Build script not found at: $buildScriptPath
Please ensure the C++ backend source code is present in the Videoeditor directory.''');
      }

      // Run build script with appropriate build type
      final buildResult = await Process.run(
        buildScriptPath,
        [buildType],  // Pass build type as argument
        workingDirectory: backendDir,
      );

      print('Build output: ${buildResult.stdout}');
      if (buildResult.stderr.toString().isNotEmpty) {
        print('Build errors: ${buildResult.stderr}');
      }

      if (buildResult.exitCode != 0) {
        throw Exception('''Failed to build backend:
Build type: $buildType
Error: ${buildResult.stderr}
Output: ${buildResult.stdout}
Please ensure Visual Studio 2022 and OpenCV are properly installed.''');
      }

      // Verify build succeeded and DLLs are present
      if (!await File(executableInBackendDir).exists()) {
        throw Exception('''Build completed but executable not found at: $executableInBackendDir
Please check the build output for errors.''');
      }
      
      if (!await _verifyDLLs(path.dirname(executableInBackendDir))) {
        throw Exception('''Build completed but required DLLs are missing.
Please ensure OpenCV is properly installed and its bin directory is in PATH.''');
      }

      print('Backend built successfully');
    }

    return executableInBackendDir;
  }

  static Future<bool> _verifyDLLs(String directory) async {
    final buildType = kDebugMode ? 'd' : '';
    final dllsToCheck = [
      'opencv_world4100$buildType.dll',
      'opencv_videoio_ffmpeg4100_64.dll',
      'opencv_videoio_msmf4100_64$buildType.dll'
    ];

    print('Checking for DLLs in: $directory');
    for (final dll in dllsToCheck) {
      final dllPath = path.join(directory, dll);
      print('Checking for DLL: $dllPath');
      if (!await File(dllPath).exists()) {
        print('Missing DLL: $dll');
        return false;
      }
    }
    return true;
  }

  static Future<String> exportVideo({
    required String inputPath,
    required String outputPath,
    required String cursorDataPath,
    required String zoomConfigPath,
    required double playbackSpeed,
    required VideoExportFormat format,
  }) async {
    try {
      // Verify all required files exist
      if (!await File(inputPath).exists()) {
        throw Exception('Input video file not found: $inputPath');
      }
      if (!await File(cursorDataPath).exists()) {
        throw Exception('Cursor data file not found: $cursorDataPath');
      }
      if (!await File(zoomConfigPath).exists()) {
        throw Exception('Zoom configuration file not found: $zoomConfigPath');
      }

      // Get or build the backend executable
      final executablePath = await _getExecutablePath();
      print('Using backend executable: $executablePath');

      // Prepare arguments for the C++ backend
      final args = [
        '--input', inputPath,
        '--output', outputPath,
        '--cursor-data', cursorDataPath,
        '--zoom-config', zoomConfigPath,
        '--speed', playbackSpeed.toString(),
        '--format', _formatToString(format),
      ];

      print('Running backend with args: $args');

      // Create output directory if it doesn't exist
      final outputDir = path.dirname(outputPath);
      await Directory(outputDir).create(recursive: true);

      // Run the C++ backend process
      final result = await Process.run(
        executablePath,
        args,
        workingDirectory: path.dirname(executablePath),
      );

      // Print process output for debugging
      print('Backend stdout: ${result.stdout}');
      print('Backend stderr: ${result.stderr}');

      // Check for processing errors
      if (result.exitCode != 0) {
        throw Exception('''Video processing failed:
Exit code: ${result.exitCode}
Error: ${result.stderr}
Command: $executablePath ${args.join(' ')}
Working directory: ${path.dirname(executablePath)}''');
      }

      // Verify output was created
      if (!await File(outputPath).exists()) {
        throw Exception('Backend did not create output file: $outputPath');
      }

      // Create a manifest file with export settings
      final manifestPath = path.join(path.dirname(outputPath), 'export_manifest.json');
      final manifest = {
        'timestamp': DateTime.now().toIso8601String(),
        'input_video': path.basename(inputPath),
        'output_video': path.basename(outputPath),
        'cursor_data': path.basename(cursorDataPath),
        'zoom_config': path.basename(zoomConfigPath),
        'playback_speed': playbackSpeed,
        'format': format.toString(),
        'processing_log': result.stdout.toString(),
        'backend_version': await _getBackendVersion(executablePath),
        'command_line': '$executablePath ${args.join(' ')}',
      };
      
      await File(manifestPath).writeAsString(jsonEncode(manifest));
      return outputPath;
    } catch (e) {
      print('Export error details: $e');
      rethrow;
    }
  }

  static Future<String> _getBackendVersion(String executablePath) async {
    try {
      final result = await Process.run(
        executablePath,
        ['--version'],
        workingDirectory: path.dirname(executablePath),
      );
      return result.stdout.toString().trim();
    } catch (e) {
      return 'unknown';
    }
  }

  static String _formatToString(VideoExportFormat format) {
    switch (format) {
      case VideoExportFormat.mp4_169:
        return '16:9';
      case VideoExportFormat.mp4_916:
        return '9:16';
      case VideoExportFormat.mp4_11:
        return '1:1';
      case VideoExportFormat.gif:
        return 'gif';
    }
  }
}

enum VideoExportFormat {
  mp4_169, // 16:9
  mp4_916, // 9:16 (vertical)
  mp4_11,  // 1:1 (square)
  gif
}
