import '../../flutter_nsfw_detector.dart';

/// Represents a single classification label with its confidence score.
class NsfwLabel {
  /// The category name (e.g., "safe", "nudity").
  final String category;

  /// Confidence score in the range [0.0, 1.0].
  final double confidence;

  const NsfwLabel({
    required this.category,
    required this.confidence,
  });

  factory NsfwLabel.fromMap(Map<String, dynamic> map) {
    return NsfwLabel(
      category: map['category'] as String? ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'confidence': confidence,
      };

  @override
  String toString() => 'NsfwLabel($category: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// The result of scanning a single media file (image or video).
class ScanResult {
  /// The file path or identifier of the scanned media.
  final String identifier;

  /// The media type ("image" or "video").
  final String mediaType;

  /// All classification labels sorted by confidence (highest first).
  final List<NsfwLabel> labels;

  /// Number of frames scanned (1 for images, N for videos).
  final int frameCount;

  /// Whether the content is considered NSFW based on the global default threshold.
  bool get isNsfw {
    final nudityLabel = labels.cast<NsfwLabel?>().firstWhere(
          (l) => l!.category == 'nudity',
          orElse: () => null,
        );
    return nudityLabel != null && nudityLabel.confidence >= FlutterNsfwDetector.defaultThreshold;
  }

  /// The NSFW confidence score (0.0 to 1.0). Returns 0.0 if no nudity label.
  double get nsfwScore {
    final nudityLabel = labels.cast<NsfwLabel?>().firstWhere(
          (l) => l!.category == 'nudity',
          orElse: () => null,
        );
    return nudityLabel?.confidence ?? 0.0;
  }

  /// Whether the content was classified as NSFW above a custom [threshold].
  bool isNsfwAbove(double threshold) => nsfwScore >= threshold;

  const ScanResult({
    required this.identifier,
    required this.mediaType,
    required this.labels,
    this.frameCount = 1,
  });

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    final rawLabels = map['labels'] as List<dynamic>? ?? [];
    return ScanResult(
      identifier: map['identifier'] as String? ?? '',
      mediaType: map['mediaType'] as String? ?? 'image',
      labels: rawLabels
          .map((e) => NsfwLabel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      frameCount: map['frameCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'identifier': identifier,
        'mediaType': mediaType,
        'labels': labels.map((l) => l.toMap()).toList(),
        'frameCount': frameCount,
      };

  @override
  String toString() =>
      'ScanResult($identifier, $mediaType, isNsfw=$isNsfw, score=${nsfwScore.toStringAsFixed(3)}, frames=$frameCount)';
}
