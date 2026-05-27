import 'dart:io';
import 'package:flutter/services.dart';
import 'flutter_nsfw_detector_platform_interface.dart';

/// An implementation of [FlutterNsfwDetectorPlatform] that uses method channels.
class MethodChannelFlutterNsfwDetector extends FlutterNsfwDetectorPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('flutter_nsfw_detector');

  @override
  Future<void> initialize() async {
    await methodChannel.invokeMethod<void>('initialize');
  }

  @override
  Future<Map<String, dynamic>> scanImageFile(File file) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'scanFile',
      {'filePath': file.path},
    );
    if (result == null) {
      throw PlatformException(
        code: 'SCAN_FAILED',
        message: 'Native scan returned null',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> scanImageBytes(List<int> bytes) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'scanBytes',
      {'bytes': Uint8List.fromList(bytes)},
    );
    if (result == null) {
      throw PlatformException(
        code: 'SCAN_FAILED',
        message: 'Native scan returned null',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> scanVideoFile(
      File file, int frameCount, double threshold) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'scanVideo',
      {
        'filePath': file.path,
        'frameCount': frameCount,
        'threshold': threshold,
      },
    );
    if (result == null) {
      throw PlatformException(
        code: 'SCAN_FAILED',
        message: 'Native scan returned null',
      );
    }
    return Map<String, dynamic>.from(result);
  }
}
