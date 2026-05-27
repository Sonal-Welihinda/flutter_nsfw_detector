import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nsfw_detector/src/models/scan_result.dart';

void main() {
  group('NsfwLabel', () {
    test('fromMap parses correctly', () {
      final label = NsfwLabel.fromMap({
        'category': 'nudity',
        'confidence': 0.85,
      });
      expect(label.category, 'nudity');
      expect(label.confidence, 0.85);
    });

    test('fromMap handles missing fields', () {
      final label = NsfwLabel.fromMap({});
      expect(label.category, 'unknown');
      expect(label.confidence, 0.0);
    });

    test('toMap round-trips', () {
      const label = NsfwLabel(category: 'safe', confidence: 0.95);
      final map = label.toMap();
      final restored = NsfwLabel.fromMap(map);
      expect(restored.category, label.category);
      expect(restored.confidence, label.confidence);
    });

    test('toString includes percentage', () {
      const label = NsfwLabel(category: 'nudity', confidence: 0.7321);
      expect(label.toString(), contains('73.2%'));
    });
  });

  group('ScanResult', () {
    test('fromMap parses correctly', () {
      final result = ScanResult.fromMap({
        'identifier': '/path/to/image.jpg',
        'mediaType': 'image',
        'labels': [
          {'category': 'nudity', 'confidence': 0.8},
          {'category': 'safe', 'confidence': 0.2},
        ],
        'frameCount': 1,
      });
      expect(result.identifier, '/path/to/image.jpg');
      expect(result.mediaType, 'image');
      expect(result.labels.length, 2);
      expect(result.frameCount, 1);
      expect(result.isNsfw, true);
      expect(result.nsfwScore, 0.8);
    });

    test('isNsfw returns false for safe content', () {
      final result = ScanResult.fromMap({
        'identifier': 'test',
        'mediaType': 'image',
        'labels': [
          {'category': 'safe', 'confidence': 0.9},
          {'category': 'nudity', 'confidence': 0.1},
        ],
      });
      expect(result.isNsfw, false);
      expect(result.nsfwScore, 0.1);
    });

    test('isNsfwAbove works with custom threshold', () {
      final result = ScanResult.fromMap({
        'identifier': 'test',
        'mediaType': 'image',
        'labels': [
          {'category': 'nudity', 'confidence': 0.6},
          {'category': 'safe', 'confidence': 0.4},
        ],
      });
      expect(result.isNsfwAbove(0.5), true);
      expect(result.isNsfwAbove(0.7), false);
    });

    test('nsfwScore returns 0.0 when no nudity label', () {
      final result = ScanResult.fromMap({
        'identifier': 'test',
        'mediaType': 'image',
        'labels': [
          {'category': 'safe', 'confidence': 1.0},
        ],
      });
      expect(result.nsfwScore, 0.0);
      expect(result.isNsfw, false);
    });

    test('fromMap handles empty labels', () {
      final result = ScanResult.fromMap({
        'identifier': 'test',
        'mediaType': 'image',
        'labels': [],
      });
      expect(result.labels.isEmpty, true);
      expect(result.isNsfw, false);
    });

    test('toMap round-trips', () {
      const original = ScanResult(
        identifier: 'test.jpg',
        mediaType: 'image',
        labels: [
          NsfwLabel(category: 'safe', confidence: 0.7),
          NsfwLabel(category: 'nudity', confidence: 0.3),
        ],
        frameCount: 1,
      );
      final map = original.toMap();
      final restored = ScanResult.fromMap(map);
      expect(restored.identifier, original.identifier);
      expect(restored.mediaType, original.mediaType);
      expect(restored.labels.length, original.labels.length);
      expect(restored.frameCount, original.frameCount);
    });

    test('video result with multiple frames', () {
      final result = ScanResult.fromMap({
        'identifier': 'video.mp4',
        'mediaType': 'video',
        'labels': [
          {'category': 'nudity', 'confidence': 0.9},
          {'category': 'safe', 'confidence': 0.1},
        ],
        'frameCount': 3,
      });
      expect(result.mediaType, 'video');
      expect(result.frameCount, 3);
      expect(result.isNsfw, true);
    });
  });
}
