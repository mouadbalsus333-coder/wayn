import 'package:flutter/material.dart';

import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../core/network/api_client.dart';
import '../../core/navigation/wayn_actions.dart';
import '../../core/theme/wayn_colors.dart';
import '../../features/notifications/notifications_page.dart';
import '../../services/repositories/repository_factory.dart';
import 'models/community_post.dart';
import 'services/community_service.dart';
import 'widgets/community_post_card.dart';
import '../../services/favorite_service.dart';
import '../home/models/place.dart';
import '../home/widgets/place_card.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  late final CommunityService _communityService;
  final FavoriteService _favoriteService = FavoriteService();
  final List<CommunityPost> _savedPosts = [];
  final List<Place> _savedPlaces = [];

  bool _isLoading = true;
  bool _isPlacesLoading = true;
  String? _errorMessage;
  String? _placesErrorMessage;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(createCommunityRepository());
    _loadSavedPosts();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await _communityService.getSavedPosts(page: 1, limit: 50);

      if (!mounted) return;

      setState(() {
        _savedPosts
          ..clear()
          ..addAll(posts);
        _isLoading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل المحفوظات حاليًا';
      });
    }
  }

  Future<void> _unsavePost(CommunityPost post) async {
    try {
      await _communityService.unsavePost(post.id);

      if (!mounted) return;

      setState(() {
        _savedPosts.removeWhere((item) => item.id == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إزالة المنشور من المحفوظات',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إلغاء الحفظ', textDirection: TextDirection.rtl),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2, // Places + Posts
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                WaynHeader(
                  onMenuPressed: _onMenuPressed,
                  onNotificationsPressed: _onNotificationsPressed,
                ),
                TabBar(
                  labelColor: colors.brand,
                  unselectedLabelColor: colors.textMuted,
                  indicatorColor: colors.brand,
                  tabs: const [
                    Tab(text: 'الأماكن'),
                    Tab(text: 'المنشورات'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_buildPlacesBody(), _buildPostsBody()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    openNotifications(context);
  }

  // ===========================================================
  // Saved Places (Places tab)
  // ===========================================================

  Future<void> _loadSavedPlaces() async {
    setState(() {
      _isPlacesLoading = true;
      _placesErrorMessage = null;
    });

    try {
      final places = await _favoriteService.list();

      if (!mounted) return;

      setState(() {
        _savedPlaces
          ..clear()
          ..addAll(places);
        _isPlacesLoading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlacesLoading = false;
        _placesErrorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlacesLoading = false;
        _placesErrorMessage = 'تعذر تحميل المحفوظات حاليًا';
      });
    }
  }

  Future<void> _unsavePlace(Place place) async {
    try {
      await _favoriteService.remove(place.id);

      if (!mounted) return;

      setState(() {
        _savedPlaces.removeWhere((item) => item.id == place.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إزالة المكان من المحفوظات',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إلغاء الحفظ', textDirection: TextDirection.rtl),
        ),
      );
    }
  }

  Widget _buildPlacesBody() {
    final colors = context.waynColors;

    if (_isPlacesLoading) {
      return Center(child: CircularProgressIndicator(color: colors.brand));
    }

    if (_placesErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 54,
              color: colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _placesErrorMessage!,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadSavedPlaces,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_savedPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: colors.brand.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد أماكن محفوظة',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف أماكن إلى المحفوظات لرؤيتها هنا',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.brand,
      onRefresh: _loadSavedPlaces,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _savedPlaces.length,
        itemBuilder: (context, index) {
          final place = _savedPlaces[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlaceCard(
              place: place,
              isFavorite: true,
              onFavoritePressed: () => _unsavePlace(place),
              onPressed: () => openPlaceFromId(context, place.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsBody() {
    final colors = context.waynColors;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.brand));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 54,
              color: colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadSavedPosts,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: colors.brand.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد منشورات محفوظة',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف منشورات إلى المحفوظات لرؤيتها هنا',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.brand,
      onRefresh: _loadSavedPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _savedPosts.length,
        itemBuilder: (context, index) {
          final post = _savedPosts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCard(
              post: post,
              onLike: () {},
              onSave: () => _unsavePost(post),
              onComments: () {},
              onAuthorTap: (authorId) => openUserProfile(
                context,
                userId: authorId,
                isOwner: post.isOwner,
              ),
              onPlaceTap: (placeId) => openPlaceFromId(context, placeId),
            ),
          );
        },
      ),
    );
  }
}
