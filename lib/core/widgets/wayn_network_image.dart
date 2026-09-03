import 'package:flutter/material.dart';

/// Shared network-image widget that decodes images close to their rendered
/// size. Flutter's built-in [ImageCache] continues to provide memory caching;
/// this widget supplies cache dimensions to avoid large decoded bitmaps.
class WaynNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const WaynNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          cacheWidth: _cacheDimension(
            _renderedDimension(width, constraints.maxWidth),
            devicePixelRatio,
          ),
          cacheHeight: _cacheDimension(
            _renderedDimension(height, constraints.maxHeight),
            devicePixelRatio,
          ),
          frameBuilder: frameBuilder,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
        );
      },
    );
  }

  int? _cacheDimension(double dimension, double devicePixelRatio) {
    if (!dimension.isFinite || dimension <= 0) {
      return null;
    }

    return (dimension * devicePixelRatio).round();
  }

  double _renderedDimension(double? explicit, double constrained) {
    if (explicit != null && explicit.isFinite && explicit > 0) {
      return explicit;
    }

    return constrained;
  }
}
