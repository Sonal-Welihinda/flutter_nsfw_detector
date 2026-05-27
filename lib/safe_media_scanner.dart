/// On-device NSFW content detection for Flutter.
///
/// Provides programmatic APIs and a ready-to-use widget for detecting
/// NSFW content in images and videos. All processing runs on-device
/// using TFLite (Android) and CoreML (iOS) — no data leaves the phone.
library;

export 'flutter_nsfw_detector.dart';
export 'src/models/scan_result.dart';
export 'src/models/nsfw_guard_theme.dart';
export 'src/widgets/nsfw_guard_widget.dart';
