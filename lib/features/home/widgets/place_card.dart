import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';
import '../models/place.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onPressed;

  const PlaceCard({
    super.key,
    required this.place,
    this.onFavoritePressed,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 240,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _PlaceImage(
                imageUrl: place.imageUrl,
              ),
            ),

            // =========================================================
            // GRADIENT
            // =========================================================

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [
                        0.25,
                        0.72,
                        1.0,
                      ],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xD9000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // =========================================================
            // RATING
            // =========================================================

            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: Color(0xFFFFB300),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================================================
            // FAVORITE
            // =========================================================

            Positioned(
              top: 14,
              left: 14,
              child: GestureDetector(
                onTap: onFavoritePressed,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),

            // =========================================================
            // INFORMATION
            // =========================================================

            Positioned(
              right: 16,
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),

                      const SizedBox(width: 3),

                      Expanded(
                        child: Text(
                          '${place.city} • ${place.category}',
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: place.isOpen
                              ? const Color(0xFF19A987)
                              : const Color(0xFFE45C5C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          place.isOpen
                              ? 'مفتوح الآن'
                              : 'مغلق',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// PLACE IMAGE
// ===================================================================

class _PlaceImage extends StatelessWidget {
  final String imageUrl;

  const _PlaceImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    if (url.isEmpty) {
      return const _ImagePlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 900,
      filterQuality: FilterQuality.low,

      // =============================================================
      // الصورة تظهر مباشرة عند وصول أول frame
      // =============================================================

      frameBuilder: (
        context,
        child,
        frame,
        wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded) {
          return child;
        }

        return AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 400,
          ),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (
            child,
            animation,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: frame == null
              ? const _QuietPlaceholder(
                  key: ValueKey('loading'),
                )
              : child,
        );
      },

      // =============================================================
      // لا يوجد Loading Indicator
      // =============================================================

      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return const _QuietPlaceholder();
      },

      // =============================================================
      // ERROR
      // =============================================================

      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        debugPrint(
          'Failed to load image: $url',
        );

        return const _ImagePlaceholder();
      },
    );
  }
}

// ===================================================================
// QUIET LOADING
// ===================================================================
//
// لا دائرة.
// لا Shimmer.
// لا Progress Bar.
//
// مجرد خلفية هادئة جدًا حتى تصل الصورة.
// ===================================================================

class _QuietPlaceholder extends StatelessWidget {
  const _QuietPlaceholder({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceAlt,
            colors.surface,
          ],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0.35,
            end: 0.65,
          ),
          duration: const Duration(
            milliseconds: 1100,
          ),
          curve: Curves.easeInOut,
          builder: (
            context,
            value,
            child,
          ) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: Icon(
            Icons.location_on_rounded,
            size: 34,
            color: colors.textMuted.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// ERROR PLACEHOLDER
// ===================================================================

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      color: colors.surfaceAlt,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: colors.textMuted,
        ),
      ),
    );
  }
}