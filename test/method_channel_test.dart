import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nsfw_detector/flutter_nsfw_detector_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterNsfwDetector();
  const channel = MethodChannel('flutter_nsfw_detector');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return null;
        case 'scanFile':
          return {
            'identifier': (call.arguments as Map)['filePath'],
            'mediaType': 'image',
            'labels': [
              {'category': 'safe', 'confidence': 0.9},
              {'category': 'nudity', 'confidence': 0.1},
            ],
            'frameCount': 1,
          };
        case 'scanBytes':
          return {
            'identifier': 'bytes_mock',
            'mediaType': 'image',
            'labels': [
              {'category': 'safe', 'confidence': 0.8},
              {'category': 'nudity', 'confidence': 0.2},
            ],
            'frameCount': 1,
          };
        case 'scanVideo':
          return {
            'identifier': (call.arguments as Map)['filePath'],
            'mediaType': 'video',
            'labels': [
              {'category': 'nudity', 'confidence': 0.85},
              {'category': 'safe', 'confidence': 0.15},
            ],
            'frameCount': (call.arguments as Map)['frameCount'] ?? 5,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize completes without error', () async {
    await platform.initialize();
  });

  test('scanImageFile returns correct result map', () async {
    final result = await platform.scanImageFile(
      File('/test/image.jpg'),
    );
    expect(result['identifier'], '/test/image.jpg');
    expect(result['mediaType'], 'image');
    expect((result['labels'] as List).length, 2);
  });

  test('scanImageBytes returns correct result map', () async {
    final result = await platform.scanImageBytes([0, 1, 2, 3]);
    expect(result['identifier'], 'bytes_mock');
    expect(result['mediaType'], 'image');
  });

  test('scanVideoFile returns correct result map', () async {
    final result = await platform.scanVideoFile(
      File('/test/video.mp4'),
      5,
      0.5,
    );
    expect(result['identifier'], '/test/video.mp4');
    expect(result['mediaType'], 'video');
    expect(result['frameCount'], 5);
  });
}
