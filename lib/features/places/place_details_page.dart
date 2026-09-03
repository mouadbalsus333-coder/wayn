import 'package:flutter/material.dart';

import '../home/models/place.dart';
import '../../services/favorite_service.dart';
import '../../services/review_service.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_network_image.dart';

class PlaceDetailsPage extends StatefulWidget {
  final Place place;

  const PlaceDetailsPage({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  bool _isFavorite = false;
  final _favorites = FavoriteService();
  final _reviews = ReviewService();

  Place get place => widget.place;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    try {
      final value = await _favorites.check(place.id);
      if (mounted) setState(() => _isFavorite = value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // =====================================================
            // HERO IMAGE
            // =====================================================

            SliverToBoxAdapter(
              child: _buildHeroImage(context),
            ),

            // =====================================================
            // PLACE INFORMATION
            // =====================================================

            SliverToBoxAdapter(
              child: _buildPlaceInformation(),
            ),

            // =====================================================
            // ACTIONS
            // =====================================================

            SliverToBoxAdapter(
              child: _buildActions(),
            ),

            // =====================================================
            // DESCRIPTION
            // =====================================================

            SliverToBoxAdapter(
              child: _buildDescription(),
            ),

            // =====================================================
            // OPENING HOURS
            // =====================================================

            SliverToBoxAdapter(
              child: _buildOpeningHours(),
            ),

            // =====================================================
            // SERVICES
            // =====================================================

            SliverToBoxAdapter(
              child: _buildServices(),
            ),

            // =====================================================
            // REVIEWS
            // =====================================================

            SliverToBoxAdapter(
              child: _buildReviews(),
            ),

            // =====================================================
            // LOCATION
            // =====================================================

            SliverToBoxAdapter(
              child: _buildLocation(),
            ),

            // =====================================================
            // REPORT
            // =====================================================

            SliverToBoxAdapter(
              child: _buildReportButton(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 35),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // HERO IMAGE
  // ===============================================================

  Widget _buildHeroImage(BuildContext context) {
    final images = <String>[
      place.imageUrl,
      ...place.images,
    ];

    return SizedBox(
      height: 330,
      child: Stack(
        children: [
          Positioned.fill(
            child: WaynNetworkImage(
              imageUrl: place.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  color: const Color(0xFFE8EDF2),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 50,
                      color: Color(0xFF8B94A3),
                    ),
                  ),
                );
              },
            ),
          ),

          // -------------------------------------------------------
          // DARK GRADIENT
          // -------------------------------------------------------

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [
                    0.0,
                    0.45,
                    1.0,
                  ],
                ),
              ),
            ),
          ),

          // -------------------------------------------------------
          // BACK BUTTON
          // -------------------------------------------------------

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _buildCircleButton(
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),

          // -------------------------------------------------------
          // FAVORITE
          // -------------------------------------------------------

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _buildCircleButton(
              icon: _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: _isFavorite
                  ? const Color(0xFFE05252)
                  : const Color(0xFF263247),
              onPressed: _toggleFavorite,
            ),
          ),

          // -------------------------------------------------------
          // IMAGE COUNT
          // -------------------------------------------------------

          if (images.length > 1)
            Positioned(
              bottom: 18,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${images.length} صور',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // CIRCLE BUTTON
  // ===============================================================

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = const Color(0xFF263247),
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // PLACE INFORMATION
  // ===============================================================

  Widget _buildPlaceInformation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  place.name,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              _buildOpenStatus(),
            ],
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 17,
                color: Color(0xFF18A99A),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${place.city} • ${place.category}',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8494),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 20,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 5),
              Text(
                place.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF30394A),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '(${place.reviewsCount} تقييم)',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8993A3),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.remove_red_eye_outlined,
                size: 17,
                color: Color(0xFF8993A3),
              ),
              const SizedBox(width: 5),
              Text(
                '${place.visitsCount} زيارة',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8993A3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // OPEN STATUS
  // ===============================================================

  Widget _buildOpenStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: place.isOpen
            ? const Color(0xFFE6F8F1)
            : const Color(0xFFFCEAEA),
        borderRadius: BorderRadius.circular(11),
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
                  : const Color(0xFFE05252),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            place.isOpen ? 'مفتوح الآن' : 'مغلق',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: place.isOpen
                  ? const Color(0xFF168C71)
                  : const Color(0xFFC54141),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // ACTIONS
  // ===============================================================

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.directions_rounded,
              title: 'الاتجاهات',
              color: const Color(0xFF18A99A),
              onPressed: () {
                debugPrint(
                  'Directions pressed for ${place.name}',
                );
              },
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: _buildActionButton(
              icon: Icons.call_outlined,
              title: 'اتصال',
              color: const Color(0xFF2997FF),
              onPressed: place.phone == null
                  ? null
                  : () {
                      debugPrint(
                        'Call ${place.phone}',
                      );
                    },
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: _buildActionButton(
              icon: Icons.share_outlined,
              title: 'مشاركة',
              color: const Color(0xFF7B61D9),
              onPressed: () {
                debugPrint(
                  'Share ${place.name}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onPressed,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFE8EBF0),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: disabled
                    ? const Color(0xFFB7BDC7)
                    : color,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: disabled
                      ? const Color(0xFFB7BDC7)
                      : const Color(0xFF596273),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // DESCRIPTION
  // ===============================================================

  Widget _buildDescription() {
    final description = place.description;

    if (description == null ||
        description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      title: 'عن المكان',
      child: Text(
        description,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 14,
          height: 1.8,
          color: Color(0xFF697386),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ===============================================================
  // OPENING HOURS
  // ===============================================================

  Widget _buildOpeningHours() {
    final hasHours =
        place.openingTime != null &&
        place.closingTime != null;

    if (!hasHours) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      title: 'ساعات العمل',
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: Color(0xFF18A99A),
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Text(
                'اليوم',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3E4859),
                ),
              ),
            ),

            Text(
              '${place.openingTime} - ${place.closingTime}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // SERVICES
  // ===============================================================

  Widget _buildServices() {
    if (place.services.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      title: 'الخدمات والمرافق',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: place.services.map(
          (service) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFFE6E9EE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF18A99A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    service,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF596273),
                    ),
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ===============================================================
  // REVIEWS
  // ===============================================================

  Widget _buildReviews() {
    return _buildSection(
      title: 'آراء الزوار',
      trailing: TextButton(
        onPressed: _showReviews,
        child: const Text(
          'عرض الكل',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Color(0xFF18A99A),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE8EBF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DD),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    place.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3E4859),
                    ),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    size: 17,
                    color: Color(0xFFFFB300),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    place.reviewsCount == 0
                        ? 'لا توجد تقييمات بعد'
                        : '${place.reviewsCount} تقييم من الزوار',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E4859),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _buildStars(place.rating),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      children: List.generate(
        5,
        (index) {
          final filled = index < rating.round();

          return Padding(
            padding: const EdgeInsets.only(
              right: 2,
            ),
            child: Icon(
              filled
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 17,
              color: const Color(0xFFFFB300),
            ),
          );
        },
      ),
    );
  }

  // ===============================================================
  // LOCATION
  // ===============================================================

  Widget _buildLocation() {
    final hasCoordinates =
        place.latitude != null &&
        place.longitude != null;

    final hasAddress =
        place.address != null &&
        place.address!.trim().isNotEmpty;

    if (!hasCoordinates && !hasAddress) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      title: 'الموقع',
      child: Column(
        children: [
          if (hasAddress)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFFE8EBF0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F6),
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF18A99A),
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      place.address!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF596273),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hasCoordinates) ...[
            if (hasAddress)
              const SizedBox(height: 10),

            Material(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () {
                  debugPrint(
                    'Open map at '
                    '${place.latitude}, '
                    '${place.longitude}',
                  );
                },
                child: Container(
                  height: 58,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: Color(0xFF18A99A),
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'عرض الموقع على الخريطة',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF168F83),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: Color(0xFF168F83),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===============================================================
  // REPORT
  // ===============================================================

  Widget _buildReportButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        26,
        20,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            _showReportDialog();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE4E7EC),
              ),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 17,
                  color: Color(0xFF8B94A3),
                ),
                SizedBox(width: 7),
                Text(
                  'الإبلاغ عن معلومة غير صحيحة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A8494),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // SECTION
  // ===============================================================

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        28,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),

          const SizedBox(height: 11),

          child,
        ],
      ),
    );
  }

  // ===============================================================
  // FAVORITE
  // ===============================================================

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await _favorites.remove(place.id);
      } else {
        await _favorites.add(place.id);
      }
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث المفضلة: $error')),
        );
      }
    }
  }

  Future<void> _showReviews() async {
    try {
      final reviews = await _reviews.list(place.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('تقييمات الزوار',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: reviews.isEmpty
                      ? const Center(child: Text('لا توجد تقييمات بعد'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: reviews.length,
                          separatorBuilder: (_, _) => const Divider(height: 22),
                          itemBuilder: (_, i) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE8F8F6),
                              child: Text(reviews[i].rating.toStringAsFixed(0)),
                            ),
                            title: Text(reviews[i].comment ?? 'تقييم بدون تعليق'),
                            subtitle: Text('تقييم ${reviews[i].rating.toStringAsFixed(1)} من 5'),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _writeReview();
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('أضف تقييمك'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل التقييمات: $error')),
        );
      }
    }
  }

  Future<void> _writeReview() async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _PlaceReviewDialog(
        onCreate: (rating, text) =>
            _reviews.create(place.id, rating, text),
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقييمك')),
      );
    }
  }

  // ===============================================================
  // REPORT DIALOG
  // ===============================================================

  void _showReportDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        final reasons = [
          'المكان مغلق',
          'المعلومات غير صحيحة',
          'الموقع غير صحيح',
          'المكان مكرر',
          'المكان لم يعد موجودًا',
          'سبب آخر',
        ];

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DDE3),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'ما المشكلة في هذا المكان؟',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'ساعدنا في تحسين معلومات WAYN.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8993A3),
                    ),
                  ),

                  const SizedBox(height: 15),

                  ...reasons.map(
                    (reason) {
                      return ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: Color(0xFF9AA3B1),
                        ),
                        title: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4E596B),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          debugPrint(
                            'Report: $reason',
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// حوار تقييم المكان.
///
/// يمتلك الـ TextEditingController داخل الـ State ليفسر في الوقت
/// الصحيح بعد اكتمال خروج الحوار (تجنبًا لشاشة الخطأ الحمراء).
class _PlaceReviewDialog extends StatefulWidget {
  final Future<void> Function(double rating, String text) onCreate;

  const _PlaceReviewDialog({
    required this.onCreate,
  });

  @override
  State<_PlaceReviewDialog> createState() =>
      _PlaceReviewDialogState();
}

class _PlaceReviewDialogState extends State<_PlaceReviewDialog> {
  double _rating = 5;
  late final TextEditingController _commentController =
      TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await widget.onCreate(
        _rating,
        _commentController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('قيّم المكان'),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 8,
              label: _rating.toStringAsFixed(1),
              onChanged: (v) => setState(() => _rating = v),
            ),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب تجربتك...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}
