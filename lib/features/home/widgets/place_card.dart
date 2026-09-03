import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';
import '../models/place.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final double? distanceKm;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onPressed;

  const PlaceCard({
    super.key,
    required this.place,
    this.distanceKm,
    this.onFavoritePressed,
    this.onPressed,
  });

  // =========================================================
  // DISTANCE FORMAT
  // =========================================================
  //
  // distanceKm contains the raw distance in meters.
  //
  // Examples:
  // 2756 m   -> 2.8 كم
  // 2039.7 m -> 2.0 كم
  // 850 m    -> 850 م
  //
  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()} م';
    }

    final distanceInKm = distance / 1000;

    return '${distanceInKm.toStringAsFixed(1)} كم';
  }

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
            // =========================================================
            // IMAGE
            // =========================================================

            Positioned.fill(
              child: _PlaceImage(
                imageUrl: place.imageUrl,
              ),
            ),

            // =========================================================
            // TOP INFORMATION
            // =========================================================

            Positioned(
              top: 14,
              right: 14,
              left: 14,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    // -------------------------------------------------
                    // RATING
                    // -------------------------------------------------

                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
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
                          const SizedBox(width: 5),
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

                    const SizedBox(width: 8),

                    // -------------------------------------------------
                    // OPEN STATUS
                    // -------------------------------------------------

                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: place.isOpen
                                  ? const Color(0xFF19A987)
                                  : const Color(0xFFE45C5C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            place.isOpen ? 'مفتوح الآن' : 'مغلق',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: place.isOpen
                                  ? const Color(0xFF168B72)
                                  : const Color(0xFFD94F4F),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // -------------------------------------------------
                    // SAVE
                    // -------------------------------------------------

                    GestureDetector(
                      onTap: onFavoritePressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================================================
            // FROSTED INFORMATION PANEL
            // =========================================================

            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14,
                    sigmaY: 14,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      13,
                      16,
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // -------------------------------------------------
                          // PLACE NAME
                          // -------------------------------------------------

                          Text(
                            place.name,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF172033),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 9),

                          // -------------------------------------------------
                          // LOCATION / CATEGORY / DISTANCE
                          // -------------------------------------------------

                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 15,
                                      color: Color(0xFF18A99A),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${place.city} • ${place.category}',
                                        textDirection: TextDirection.rtl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF667085),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (distanceKm != null) ...[
                                const SizedBox(width: 12),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.near_me_rounded,
                                      size: 15,
                                      color: Color(0xFF18A99A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDistance(distanceKm!),
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                        color: Color(0xFF18A99A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
