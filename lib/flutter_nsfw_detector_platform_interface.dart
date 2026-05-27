import 'dart:io';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'flutter_nsfw_detector_method_channel.dart';

/// The interface that implementations of flutter_nsfw_detector must implement.
abstract class FlutterNsfwDetectorPlatform extends PlatformInterface {
  FlutterNsfwDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterNsfwDetectorPlatform _instance =
      MethodChannelFlutterNsfwDetector();

  /// The default instance of [FlutterNsfwDetectorPlatform] to use.
  static FlutterNsfwDetectorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterNsfwDetectorPlatform].
  static set instance(FlutterNsfwDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the native ML engine.
  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Scan an image file and return the raw result map.
  Future<Map<String, dynamic>> scanImageFile(File file) {
    throw UnimplementedError('scanImageFile() has not been implemented.');
  }

  /// Scan image bytes and return the raw result map.
  Future<Map<String, dynamic>> scanImageBytes(List<int> bytes) {
    throw UnimplementedError('scanImageBytes() has not been implemented.');
  }

  /// Scan a video file by extracting [frameCount] frames, using [threshold] for fail-fast.
  Future<Map<String, dynamic>> scanVideoFile(
      File file, int frameCount, double threshold) {
    throw UnimplementedError('scanVideoFile() has not been implemented.');
  }
}
