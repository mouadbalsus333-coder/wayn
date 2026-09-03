import 'package:flutter/material.dart';

import '../../home/models/place.dart';
import '../../community/models/community_post.dart';
import '../../../core/widgets/wayn_network_image.dart';

class MapPlacePreview extends StatelessWidget {
  static const Color waynTeal = Color(0xFF18A99A);
  static const Color waynTealLight = Color(0xFFE8F8F6);
  static const Color waynText = Color(0xFF172033);
  static const Color waynMuted = Color(0xFF697386);

  final Place place;
  final List<CommunityPost> posts;
  final bool isLoadingPosts;
  final bool showVisitorOpinions;

  final VoidCallback onClose;
  final ValueChanged<bool> onTabChanged;
  final VoidCallback onDirections;

  const MapPlacePreview({
    super.key,
    required this.place,
    required this.posts,
    required this.isLoadingPosts,
    required this.showVisitorOpinions,
    required this.onClose,
    required this.onTabChanged,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 410,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            22,
          ),
          border: Border.all(
            color: const Color(
              0xFFE7EBF0,
            ),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.15,
              ),
              blurRadius: 28,
              offset: const Offset(
                0,
                8,
              ),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlaceHeader(),
            _buildPlaceTabs(),
            Flexible(
              child: showVisitorOpinions
                  ? _buildVisitorOpinions()
                  : _buildGeneralInformation(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        10,
      ),
      child: Row(
        children: [
          _buildPlaceImage(),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color: waynText,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  '${place.category} • ${place.city}',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                    color: Color(
                      0xFF8993A3,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(
                        0xFFF5B942,
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      place.rating.toStringAsFixed(
                        1,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color: Color(
                          0xFF596273,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      '${place.reviewsCount} تقييم',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        color: waynMuted,
                      ),
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: place.isOpen
                          ? const Color(
                              0xFF22B573,
                            )
                          : const Color(
                              0xFFD95353,
                            ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      place.isOpen
                          ? 'مفتوح الآن'
                          : 'مغلق',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                        color: place.isOpen
                            ? const Color(
                                0xFF22B573,
                              )
                            : const Color(
                                0xFFD95353,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF2F4F7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 19,
                color: waynMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      height: 43,
      decoration: BoxDecoration(
        color: const Color(
          0xFFF3F5F8,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPlaceTab(
              title: 'آراء الزوار',
              icon: Icons.forum_outlined,
              selected:
                  showVisitorOpinions,
              onTap: () {
                onTabChanged(true);
              },
            ),
          ),
          Expanded(
            child: _buildPlaceTab(
              title: 'معلومات عامة',
              icon:
                  Icons.info_outline_rounded,
              selected:
                  !showVisitorOpinions,
              onTap: () {
                onTabChanged(false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTab({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        margin: const EdgeInsets.all(
          3,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.06,
                    ),
                    blurRadius: 7,
                    offset: const Offset(
                      0,
                      2,
                    ),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? waynTeal
                  : waynMuted,
            ),
            const SizedBox(
              width: 6,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
                color: selected
                    ? waynText
                    : waynMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorOpinions() {
    if (isLoadingPosts) {
      return const Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(
            vertical: 30,
          ),
          child:
              CircularProgressIndicator(
            strokeWidth: 2.5,
            color: waynTeal,
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          14,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: waynTealLight,
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: waynTeal,
                size: 27,
              ),
            ),
            const SizedBox(
              height: 11,
            ),
            const Text(
              'لا توجد آراء من الزوار بعد',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
                color: waynText,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            const Text(
              'كن أول من يشارك تجربته مع هذا المكان.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: waynMuted,
              ),
            ),
            const SizedBox(
              height: 13,
            ),
            _buildDirectionsButton(),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 142,
          child: ListView.separated(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              4,
            ),
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount: posts.length,
            separatorBuilder:
                (_, __) =>
                    const SizedBox(
              width: 9,
            ),
            itemBuilder: (_, index) {
              return _buildVisitorPost(
                posts[index],
              );
            },
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            5,
            12,
            12,
          ),
          child:
              _buildDirectionsButton(),
        ),
      ],
    );
  }

  Widget _buildVisitorPost(
    CommunityPost post,
  ) {
    final imageUrl =
        post.imageUrl?.trim() ?? '';

    return Container(
      width: 245,
      padding: const EdgeInsets.all(
        9,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color: const Color(
            0xFFE8ECF1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
              child: WaynNetworkImage(
                imageUrl: imageUrl,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) {
                  return _buildPostImageFallback();
                },
              ),
            )
          else
            _buildPostImageFallback(),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                if (post.rating != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Color(
                          0xFFF5B942,
                        ),
                      ),
                      const SizedBox(
                        width: 3,
                      ),
                      Text(
                        post.rating!
                            .toStringAsFixed(
                          1,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w800,
                          color: waynText,
                        ),
                      ),
                    ],
                  ),
                if (post.rating != null)
                  const SizedBox(
                    height: 4,
                  ),
                if (post.text != null &&
                    post.text!.trim().isNotEmpty)
                  Text(
                    post.text!.trim(),
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight:
                          FontWeight.w500,
                      color: Color(
                        0xFF596273,
                      ),
                    ),
                  )
                else
                  const Text(
                    'شارك الزائر صورة من تجربته.',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight:
                          FontWeight.w500,
                      color: waynMuted,
                    ),
                  ),
                const SizedBox(
                  height: 6,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .favorite_border_rounded,
                      size: 13,
                      color: waynMuted,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Text(
                      '${post.likesCount}',
                      style:
                          const TextStyle(
                        fontSize: 10,
                        color: waynMuted,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Icon(
                      Icons
                          .chat_bubble_outline_rounded,
                      size: 13,
                      color: waynMuted,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Text(
                      '${post.commentsCount}',
                      style:
                          const TextStyle(
                        fontSize: 10,
                        color: waynMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImageFallback() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: waynTealLight,
        borderRadius:
            BorderRadius.circular(
          11,
        ),
      ),
      child: const Icon(
        Icons.photo_outlined,
        color: waynTeal,
        size: 27,
      ),
    );
  }

  Widget _buildGeneralInformation() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12,
      ),
      child: Column(
        children: [
          if (place.description != null &&
              place.description!
                  .trim()
                  .isNotEmpty)
            _buildInfoSection(
              icon:
                  Icons.description_outlined,
              title: 'عن المكان',
              child: Text(
                place.description!.trim(),
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: Color(
                    0xFF596273,
                  ),
                ),
              ),
            ),
          if (place.address != null &&
              place.address!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.location_on_outlined,
              title: 'العنوان',
              value:
                  place.address!.trim(),
            ),
          if (place.phone != null &&
              place.phone!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.phone_outlined,
              title: 'الهاتف',
              value:
                  place.phone!.trim(),
            ),
          if (place.website != null &&
              place.website!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.language_rounded,
              title: 'الموقع الإلكتروني',
              value:
                  place.website!.trim(),
            ),
          _buildInfoRow(
            icon:
                Icons.people_outline_rounded,
            title: 'زيارات',
            value:
                '${place.visitsCount}',
          ),
          const SizedBox(
            height: 4,
          ),
          _buildDirectionsButton(),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.all(
        11,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFE8ECF1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: waynTeal,
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                  color: waynText,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 7,
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 7,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color: const Color(
            0xFFE8ECF1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: waynTeal,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color: waynText,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.right,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w500,
                color: waynMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsButton() {
    return SizedBox(
      width: double.infinity,
      height: 43,
      child: ElevatedButton.icon(
        onPressed: onDirections,
        icon: const Icon(
          Icons.directions_rounded,
          size: 20,
        ),
        label: const Text(
          'الحصول على الاتجاهات',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor: waynTeal,
          foregroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceImage() {
    final imageUrl =
        place.imageUrl.trim();

    if (imageUrl.isEmpty) {
      return _buildImageFallback();
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: WaynNetworkImage(
        imageUrl: imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return _buildImageFallback();
        },
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: waynTealLight,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: const Icon(
        Icons.place_rounded,
        color: waynTeal,
        size: 28,
      ),
    );
  }
}
