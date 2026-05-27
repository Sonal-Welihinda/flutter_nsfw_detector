# flutter_nsfw_detector

[![pub package](https://img.shields.io/pub/v/flutter_nsfw_detector.svg)](https://pub.dev/packages/flutter_nsfw_detector)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

Privacy-first, **on-device** NSFW content detection for Flutter apps. No telemetry, no media uploads, no server costs.

Uses **CoreML** on iOS and **LiteRT** (TFLite) on Android for high-performance, offline inference. Works with images, video frames, and in-memory bytes. Includes a ready-to-use `NsfwGuardWidget` that automatically blurs unsafe content.

## Features
- **Privacy-first**: All scanning happens entirely on the user's device.
- **Cross-platform Native Performance**: CoreML (`.mlmodelc`) for iOS and LiteRT (`.tflite`) for Android.
- **Fail-Fast Video Scanning**: Efficiently scans videos by extracting keyframes and stopping immediately if NSFW content is detected.
- **UI Integration**: Drop-in `NsfwGuardWidget` to seamlessly protect your users from unexpected explicit content.
- **Network Compatibility**: Built-in support for `ImageProvider` allows seamless integration with network image libraries like `cached_network_image`.

## Supported Platforms
| Platform | Minimum Version |
| :--- | :--- |
| **Android** | API 21 (Android 5.0) |
| **iOS** | iOS 13.0 |

---

## Installation

Add the dependency to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_nsfw_detector: ^0.0.1
```

---

## Getting Started

Initialize the detector before use, typically during app startup:

```dart
import 'package:flutter_nsfw_detector/flutter_nsfw_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNsfwDetector.initialize();
  runApp(const MyApp());
}
```

### 1. The `NsfwGuardWidget`
The easiest way to use this plugin is through the auto-blurring widget. It supports files, raw bytes, and standard Flutter `ImageProvider`s.

```dart
import 'package:flutter_nsfw_detector/safe_media_scanner.dart';

// With a local file
NsfwGuardWidget.file(
  mediaFile: myImageFile,
  child: Image.file(myImageFile),
)

// With network images (works great with cached_network_image)
CachedNetworkImage(
  imageUrl: "https://example.com/image.jpg",
  imageBuilder: (context, imageProvider) => NsfwGuardWidget.provider(
    imageProvider: imageProvider,
    child: Image(image: imageProvider),
  ),
)
```
The widget automatically displays a loading indicator while scanning, shows the clean image if safe, and applies a heavy Gaussian blur with a warning icon if the content is flagged as NSFW.

### 2. Programmatic Scanning
If you need to scan files in the background or build custom moderation flows:

```dart
// Scan an image file
final result = await FlutterNsfwDetector.scanImage(file: myFile);
if (result.isNsfw) {
  print("NSFW Score: ${result.nsfwScore}"); // 0.0 to 1.0
}

// Scan a video (extracts 5 frames by default, stops early if NSFW found)
final videoResult = await FlutterNsfwDetector.scanVideo(file: videoFile, frameCount: 5);

// Scan raw bytes or ImageProviders
final byteResult = await FlutterNsfwDetector.scanImageBytes(bytes: myImageBytes);
final providerResult = await FlutterNsfwDetector.scanImageProvider(provider: myProvider);
```

---

## App Size Impact

Because this plugin is **privacy-first** and runs entirely offline without internet dependencies, the ML models must be bundled directly within your app.

*   **Android (.tflite)**: Adds ~17 MB to your APK size.
*   **iOS (.mlmodelc)**: Adds ~12 MB to your IPA size.

These are highly optimized models (MobileNet v2 / OpenNSFW2 architecture) that provide the absolute best balance of extreme performance, low battery usage, and high accuracy for on-device detection.

---

## Models & Attributions

This plugin comes bundled with highly-capable MobileNet/OpenNSFW2 derived models out of the box to guarantee a crash-free, zero-configuration experience.

The included models and architecture owe their existence to the open-source community. If you need to evaluate or download the raw models directly, you can find them here:

*   **OpenNSFW2**: [Download OpenNSFW2.tflite.zip](https://github.com/nexas105/flutter_nsfw_scaner/releases/download/models-v1/OpenNSFW2.tflite.zip) (Fast, default CNN classifier)
*   **FalconsaiNSFW**: [Download FalconsaiNSFW.tflite.zip](https://github.com/nexas105/flutter_nsfw_scaner/releases/download/models-v1/FalconsaiNSFW.tflite.zip) (ViT classifier)
*   **AdamCoddNSFW**: [Download AdamCoddNSFW.tflite.zip](https://github.com/nexas105/flutter_nsfw_scaner/releases/download/models-v1/AdamCoddNSFW.tflite.zip) (Higher resolution ViT)
*   **NudeNetDetector**: [Download NudeNetDetector.tflite.zip](https://github.com/nexas105/flutter_nsfw_scaner/releases/download/models-v1/NudeNetDetector.tflite.zip) (YOLO-based spatial detector)

*(Note: Custom model injection is explicitly disabled in this plugin to ensure tensor-shape stability and prevent runtime crashes. The bundled models provide an excellent balance of speed and accuracy for mobile use cases.)*

---

## Threshold Control & Theming

You can customize the sensitivity of the NSFW detection (the `threshold`) and the visual appearance of the `NsfwGuardWidget` either globally or per-instance.

```dart
// Set globally during initialization
await FlutterNsfwDetector.initialize(
  defaultThreshold: 0.6, // Default is 0.5. Higher means less sensitive (fewer false positives).
  defaultTheme: const NsfwGuardTheme(
    blurSigma: 25.0,
    overlayColor: Colors.black87,
    warningIcon: Icons.visibility_off,
  ),
);

// Or override on a specific widget or programmatic scan
NsfwGuardWidget.file(
  mediaFile: file,
  threshold: 0.7, // Local override for just this image
  theme: NsfwGuardTheme(warningText: "Tap to reveal"),
  child: myImage,
)

// The threshold also applies to fail-fast video scanning
final videoResult = await FlutterNsfwDetector.scanVideo(
  file: videoFile, 
  threshold: 0.7, 
);
```

---

## Vibe Coded ✌️
This library was built with good vibes and AI assistance. Designed for developer happiness and a safer internet.

---

## License
MIT License. See [LICENSE](LICENSE) for more details.
