import 'package:flutter/material.dart';

/// Theme configuration for the [NsfwGuardWidget].
///
/// Controls the visual appearance of the default NSFW overlay,
/// loading indicator, and error state. Can be set globally via
/// [FlutterNsfwDetector.initialize] or per-widget.
class NsfwGuardTheme {
  /// The sigma value for the Gaussian blur applied to NSFW content.
  /// Higher values produce a stronger blur. Defaults to 20.0.
  final double blurSigma;

  /// The color overlay applied on top of the blurred NSFW content.
  /// Defaults to semi-transparent black.
  final Color overlayColor;

  /// The icon displayed on the NSFW overlay.
  /// Defaults to [Icons.warning_amber_rounded].
  final IconData warningIcon;

  /// The color of the warning icon.
  /// Defaults to white with 80% opacity.
  final Color warningIconColor;

  /// The size of the warning icon. Defaults to 48.0.
  final double warningIconSize;

  /// Optional text displayed below the warning icon.
  /// Defaults to "Content hidden".
  final String? warningText;

  /// The text style for the warning text.
  final TextStyle? warningTextStyle;

  /// The color of the loading indicator.
  /// Defaults to grey.
  final Color loadingIndicatorColor;

  /// The color of the error icon.
  /// Defaults to red with 70% opacity.
  final Color errorColor;

  const NsfwGuardTheme({
    this.blurSigma = 20.0,
    this.overlayColor = const Color(0x99000000),
    this.warningIcon = Icons.warning_amber_rounded,
    this.warningIconColor = const Color(0xCCFFFFFF),
    this.warningIconSize = 48.0,
    this.warningText = 'Content hidden',
    this.warningTextStyle,
    this.loadingIndicatorColor = const Color(0xFF9E9E9E),
    this.errorColor = const Color(0xB3F44336),
  });

  /// Creates a copy of this theme with the given fields replaced.
  NsfwGuardTheme copyWith({
    double? blurSigma,
    Color? overlayColor,
    IconData? warningIcon,
    Color? warningIconColor,
    double? warningIconSize,
    String? warningText,
    TextStyle? warningTextStyle,
    Color? loadingIndicatorColor,
    Color? errorColor,
  }) {
    return NsfwGuardTheme(
      blurSigma: blurSigma ?? this.blurSigma,
      overlayColor: overlayColor ?? this.overlayColor,
      warningIcon: warningIcon ?? this.warningIcon,
      warningIconColor: warningIconColor ?? this.warningIconColor,
      warningIconSize: warningIconSize ?? this.warningIconSize,
      warningText: warningText ?? this.warningText,
      warningTextStyle: warningTextStyle ?? this.warningTextStyle,
      loadingIndicatorColor:
          loadingIndicatorColor ?? this.loadingIndicatorColor,
      errorColor: errorColor ?? this.errorColor,
    );
  }
}
