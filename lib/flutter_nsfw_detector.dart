import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'flutter_nsfw_detector_platform_interface.dart';
import 'src/models/scan_result.dart';
import 'src/models/nsfw_guard_theme.dart';

/// On-device NSFW content detection for Flutter.
///
/// Provides programmatic APIs to scan images and videos for NSFW content
/// using bundled ML models (TFLite on Android, CoreML on iOS).
/// All processing happens on-device — no data leaves the user's phone.
///
/// Usage:
/// ```dart
/// await FlutterNsfwDetector.initialize();
/// final result = await FlutterNsfwDetector.scanImage(file: myImageFile);
/// if (result.isNsfw) { /* handle */ }
/// ```
class FlutterNsfwDetector {
  FlutterNsfwDetector._();

  static bool _initialized = false;

  /// The global default theme for [NsfwGuardWidget].
  /// Set via [initialize] and can be overridden per-widget.
  static NsfwGuardTheme _defaultTheme = const NsfwGuardTheme();

  /// The global default threshold for NSFW detection.
  /// Content with a score >= this value is considered NSFW.
  /// Set via [initialize] and can be overridden per-scan or per-widget.
  static double _defaultThreshold = 0.5;

  /// Returns the current global default theme.
  static NsfwGuardTheme get defaultTheme => _defaultTheme;

  /// Returns the current global default threshold.
  static double get defaultThreshold => _defaultThreshold;

  /// Initialize the NSFW detection engine.
  ///
  /// Must be called before any scan methods. Loads the bundled ML model
  /// into memory on the native side.
  ///
  /// Optionally pass a [defaultTheme] to set the global theme for all
  /// [NsfwGuardWidget] instances, and [defaultThreshold] to set the global
  /// sensitivity.
  static Future<void> initialize({
    NsfwGuardTheme? defaultTheme,
    double defaultThreshold = 0.5,
  }) async {
    if (defaultTheme != null) {
      _defaultTheme = defaultTheme;
    }
    _defaultThreshold = defaultThreshold;
    await FlutterNsfwDetectorPlatform.instance.initialize();
    _initialized = true;
  }

  /// Whether the detector has been initialized.
  static bool get isInitialized => _initialized;

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'FlutterNsfwDetector has not been initialized. '
        'Call FlutterNsfwDetector.initialize() first.',
      );
    }
  }

  /// Scan an image file for NSFW content.
  ///
  /// Returns a [ScanResult] containing classification labels and
  /// confidence scores.
  static Future<ScanResult> scanImage({required File file}) async {
    _ensureInitialized();
    final map = await FlutterNsfwDetectorPlatform.instance.scanImageFile(file);
    return ScanResult.fromMap(map);
  }

  /// Scan raw image bytes for NSFW content.
  ///
  /// Useful when working with in-memory images from network responses
  /// or camera captures.
  static Future<ScanResult> scanImageBytes({required List<int> bytes}) async {
    _ensureInitialized();
    final map =
        await FlutterNsfwDetectorPlatform.instance.scanImageBytes(bytes);
    return ScanResult.fromMap(map);
  }

  /// Scan an [ImageProvider] for NSFW content.
  ///
  /// This automatically resolves the image stream, extracts the underlying
  /// bytes (as PNG), and scans them. Highly useful for compatibility with
  /// network image libraries like `cached_network_image`.
  static Future<ScanResult> scanImageProvider(
      {required ImageProvider provider}) async {
    _ensureInitialized();
    final completer = Completer<List<int>>();
    final stream = provider.resolve(ImageConfiguration.empty);

    late ImageStreamListener listener;
    listener =
        ImageStreamListener((ImageInfo info, bool synchronousCall) async {
      stream.removeListener(listener);
      try {
        final byteData =
            await info.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          completer.completeError(
              Exception('Failed to encode image provider to PNG bytes'));
        } else {
          completer.complete(byteData.buffer.asUint8List());
        }
      } catch (e) {
        completer.completeError(e);
      }
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(exception);
    });

    stream.addListener(listener);
    final bytes = await completer.future;
    return scanImageBytes(bytes: bytes);
  }

  /// Scan a video file for NSFW content.
  ///
  /// Extracts [frameCount] evenly-spaced keyframes from the video and
  /// scans each one. Uses a **fail-fast** strategy: if any single frame
  /// is detected as NSFW, scanning stops immediately and the video is
  /// marked as NSFW.
  ///
  /// [frameCount] defaults to 5 frames.
  /// [threshold] overrides the global [defaultThreshold] for fail-fast logic.
  static Future<ScanResult> scanVideo({
    required File file,
    int frameCount = 5,
    double? threshold,
  }) async {
    _ensureInitialized();
    final t = threshold ?? _defaultThreshold;
    final map = await FlutterNsfwDetectorPlatform.instance
        .scanVideoFile(file, frameCount, t);
    return ScanResult.fromMap(map);
  }
}
