import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../flutter_nsfw_detector.dart';
import '../models/nsfw_guard_theme.dart';
import '../models/scan_result.dart';

/// The current state of the [NsfwGuardWidget] scan lifecycle.
enum NsfwGuardState {
  /// The widget is currently scanning the media.
  loading,

  /// The media has been scanned and is safe to display.
  safe,

  /// The media has been scanned and is NSFW. The default overlay is shown.
  unsafe,

  /// An error occurred during scanning.
  error,
}

/// A widget that automatically scans media for NSFW content and either
/// displays it normally or applies a protective overlay.
///
/// By default, the widget shows:
/// - A loading indicator while scanning
/// - The media normally if it's safe
/// - A blurred overlay with a warning icon if it's NSFW
/// - An error icon if scanning fails
///
/// All default states can be overridden with custom builders.
///
/// ```dart
/// NsfwGuardWidget(
///   mediaFile: myImageFile,
///   child: Image.file(myImageFile), // The content to protect
/// )
/// ```
class NsfwGuardWidget extends StatefulWidget {
  /// The child widget to display (typically an Image widget).
  /// This is the content that will be protected by the guard.
  final Widget child;

  /// Optional theme override for this specific widget.
  /// Falls back to [FlutterNsfwDetector.defaultTheme] if not provided.
  final NsfwGuardTheme? theme;

  /// Optional NSFW confidence threshold (0.0 - 1.0).
  /// Defaults to [FlutterNsfwDetector.defaultThreshold].
  final double? threshold;

  /// Custom builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Custom builder for the safe state. Receives the child widget.
  final Widget Function(BuildContext context, Widget child)? safeBuilder;

  /// Custom builder for the unsafe/NSFW state.
  final WidgetBuilder? unsafeBuilder;

  /// Custom builder for the error state.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Called when the scan completes with the result.
  final ValueChanged<ScanResult>? onScanComplete;

  final File? _mediaFile;
  final List<int>? _mediaBytes;
  final ImageProvider? _mediaProvider;

  /// Scan a local [File].
  const NsfwGuardWidget.file({
    super.key,
    required File mediaFile,
    required this.child,
    this.theme,
    this.threshold,
    this.loadingBuilder,
    this.safeBuilder,
    this.unsafeBuilder,
    this.errorBuilder,
    this.onScanComplete,
  })  : _mediaFile = mediaFile,
        _mediaBytes = null,
        _mediaProvider = null;

  /// Scan raw image bytes in memory.
  const NsfwGuardWidget.bytes({
    super.key,
    required List<int> bytes,
    required this.child,
    this.theme,
    this.threshold,
    this.loadingBuilder,
    this.safeBuilder,
    this.unsafeBuilder,
    this.errorBuilder,
    this.onScanComplete,
  })  : _mediaBytes = bytes,
        _mediaFile = null,
        _mediaProvider = null;

  /// Scan an [ImageProvider], resolving it asynchronously.
  /// Excellent for compatibility with cached_network_image.
  const NsfwGuardWidget.provider({
    super.key,
    required ImageProvider imageProvider,
    required this.child,
    this.theme,
    this.threshold,
    this.loadingBuilder,
    this.safeBuilder,
    this.unsafeBuilder,
    this.errorBuilder,
    this.onScanComplete,
  })  : _mediaProvider = imageProvider,
        _mediaFile = null,
        _mediaBytes = null;

  @override
  State<NsfwGuardWidget> createState() => _NsfwGuardWidgetState();
}

class _NsfwGuardWidgetState extends State<NsfwGuardWidget>
    with SingleTickerProviderStateMixin {
  NsfwGuardState _state = NsfwGuardState.loading;
  // ignore: unused_field
  ScanResult? _scanResult;
  Object? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  NsfwGuardTheme get _theme =>
      widget.theme ?? FlutterNsfwDetector.defaultTheme;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _scan();
  }

  @override
  void didUpdateWidget(NsfwGuardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._mediaFile?.path != widget._mediaFile?.path ||
        oldWidget._mediaProvider != widget._mediaProvider ||
        oldWidget._mediaBytes != widget._mediaBytes) {
      _scan();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (!mounted) return;
    setState(() {
      _state = NsfwGuardState.loading;
      _error = null;
    });

    try {
      final ScanResult result;
      if (widget._mediaFile != null) {
        result = await FlutterNsfwDetector.scanImage(file: widget._mediaFile!);
      } else if (widget._mediaProvider != null) {
        result = await FlutterNsfwDetector.scanImageProvider(
            provider: widget._mediaProvider!);
      } else if (widget._mediaBytes != null) {
        result =
            await FlutterNsfwDetector.scanImageBytes(bytes: widget._mediaBytes!);
      } else {
        throw ArgumentError('No valid media source provided to NsfwGuardWidget.');
      }

      if (!mounted) return;
      _scanResult = result;
      widget.onScanComplete?.call(result);

      final t = widget.threshold ?? FlutterNsfwDetector.defaultThreshold;
      final isNsfw = result.isNsfwAbove(t);
      setState(() {
        _state = isNsfw ? NsfwGuardState.unsafe : NsfwGuardState.safe;
      });
      if (_state == NsfwGuardState.safe) {
        _fadeController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      _error = e;
      setState(() {
        _state = NsfwGuardState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      NsfwGuardState.loading => _buildLoading(context),
      NsfwGuardState.safe => _buildSafe(context),
      NsfwGuardState.unsafe => _buildUnsafe(context),
      NsfwGuardState.error => _buildError(context),
    };
  }

  Widget _buildLoading(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: _theme.loadingIndicatorColor,
        ),
      ),
    );
  }

  Widget _buildSafe(BuildContext context) {
    if (widget.safeBuilder != null) {
      return widget.safeBuilder!(context, widget.child);
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }

  Widget _buildUnsafe(BuildContext context) {
    if (widget.unsafeBuilder != null) {
      return widget.unsafeBuilder!(context);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // The child is rendered behind the blur so it contributes
        // to the blurred visual, but is not directly visible.
        widget.child,
        // Strong blur overlay
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _theme.blurSigma,
              sigmaY: _theme.blurSigma,
            ),
            child: Container(
              color: _theme.overlayColor,
            ),
          ),
        ),
        // Warning icon and text
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _theme.warningIcon,
                color: _theme.warningIconColor,
                size: _theme.warningIconSize,
              ),
              if (_theme.warningText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _theme.warningText!,
                  style: _theme.warningTextStyle ??
                      TextStyle(
                        color: _theme.warningIconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _error ?? 'Unknown error');
    }
    // On error, show the child (safe fallback) with a subtle error indicator.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          bottom: 4,
          right: 4,
          child: Icon(
            Icons.error_outline,
            color: _theme.errorColor,
            size: 16,
          ),
        ),
      ],
    );
  }
}
