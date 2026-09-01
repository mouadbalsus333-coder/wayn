import 'package:flutter/material.dart';

import '../../core/config/backend_config.dart';
import '../../core/theme/wayn_colors.dart';
import '../../features/community/models/community_post.dart';
import '../../features/community/services/community_service.dart';
import '../../features/home/models/place.dart';
import '../../features/places/place_details_page.dart';
import '../../services/place_service.dart';
import '../../services/repositories/repository_factory.dart';

/// صفحة "التقييمات": منشورات المستخدم المرتبطة بالأماكن.
///
/// تُحمّل من نفس مصدر Community، مع دعم السحب للأسفل لتحديث
/// التقييمات فقط، ودعم الترقيم (pagination) عند التمرير.
class RatingsPage extends StatefulWidget {
  final String userId;

  const RatingsPage({
    super.key,
    required this.userId,
  });

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  static const int _pageSize = 20;

  late final CommunityService _communityService;
  final PlaceService _placeService = PlaceService();
  final ScrollController _scrollController = ScrollController();

  List<CommunityPost> _posts = [];
  int _page = 1;
  bool _hasMore = true;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(
      createCommunityRepository(),
    );
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await _communityService.getPosts(
        userId: widget.userId,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _page = 1;
        _hasMore = posts.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التقييمات';
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final posts = await _communityService.getPosts(
        userId: widget.userId,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _page = 1;
        _hasMore = posts.length == _pageSize;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحديث التقييمات';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    _loadingMore = true;

    try {
      final posts = await _communityService.getPosts(
        userId: widget.userId,
        page: _page + 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _posts = [..._posts, ...posts];
        _page += 1;
        _hasMore = posts.length == _pageSize;
      });
    } catch (_) {
      // تجاهل خطأ الترقيم ودع المستخدم يعيد التمرير.
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _openPlace(String placeId) async {
    Place? place;

    try {
      place = await _placeService.getPlaceById(placeId);
    } catch (_) {
      // يبقى place = null عند الفشل.
    }

    if (!mounted) return;

    if (place == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر فتح المكان المرتبط',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      return;
    }

    final resolvedPlace = place;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailsPage(place: resolvedPlace),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(colors),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF18A99A),
                        ),
                      )
                    : _error != null && _posts.isEmpty
                        ? _errorState(colors)
                        : _posts.isEmpty
                            ? _emptyState(colors)
                            : RefreshIndicator(
                                color: colors.brand,
                                onRefresh: _refresh,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  itemCount: _posts.length +
                                      (_loadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= _posts.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(18),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF18A99A),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _RatingCard(
                                        post: _posts[index],
                                        colors: colors,
                                        onPlacePressed: _openPlace,
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(WaynColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: colors.textPrimary,
                size: 23,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'التقييمات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }

  Widget _emptyState(WaynColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: colors.brand.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد تقييمات بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'منشورات المجتمع التي تشير إلى أماكن ستظهر هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(WaynColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: colors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'حدث خطأ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadInitial,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

/// بطاقة تقييم (منشور مربوط بمكان).
///
/// - اسم الحساب بلون هوية WAYN.
/// - المكان بلون مميز مختلف.
class _RatingCard extends StatelessWidget {
  final CommunityPost post;
  final WaynColors colors;
  final ValueChanged<String> onPlacePressed;

  const _RatingCard({
    required this.post,
    required this.colors,
    required this.onPlacePressed,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = post.authorName?.trim().isNotEmpty == true
        ? post.authorName!.trim()
        : 'مستخدم WAYN';

    final avatarLetter = authorName.substring(0, 1);

    final fullImageUrl = BackendConfig.resolveMediaUrl(
      post.imageUrl,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =========================================================
          // الحساب + المكان
          // =========================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  avatarLetter,
                  style: TextStyle(
                    color: colors.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.brand,
                      ),
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: post.placeId.isEmpty
                          ? null
                          : () => onPlacePressed(post.placeId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 15,
                              color: colors.accentPurple,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                post.placeName?.trim().isNotEmpty == true
                                    ? post.placeName!.trim()
                                    : 'مكان مرتبط',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accentPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(post.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFF5A623),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        post.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (post.text != null && post.text!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.text!,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],

          if (fullImageUrl != null && fullImageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                fullImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return Container(
                    height: 170,
                    color: colors.surfaceAlt,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF18A99A),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 140,
                    color: colors.surfaceAlt,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: colors.textMuted,
                      size: 38,
                    ),
                  );
                },
              ),
            ),
          ],

          if (post.likesCount > 0 ||
              post.commentsCount > 0 ||
              post.savesCount > 0) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colors.divider,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _countChip(
                  Icons.favorite_border_rounded,
                  post.likesCount,
                ),
                const SizedBox(width: 14),
                _countChip(
                  Icons.chat_bubble_outline_rounded,
                  post.commentsCount,
                ),
                const SizedBox(width: 14),
                _countChip(
                  Icons.bookmark_border_rounded,
                  post.savesCount,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _countChip(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }
}
