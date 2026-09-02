import 'package:flutter/material.dart';

import '../../core/navigation/wayn_actions.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_guest_banner.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../features/notifications/notifications_page.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/repository_factory.dart';
import 'create_post_page.dart';
import 'models/community_post.dart';
import 'services/community_service.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/community_post_card.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final CommunityService _communityService;

  static const int _pageSize = 20;

  final List<CommunityPost> _posts = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;

  // حالة الـ Pagination.
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  String? _errorMessage;

  bool get _isGuest => _currentUser == null;

  User? _currentUser;

  @override
  void initState() {
    super.initState();

    _communityService = CommunityService(
      createCommunityRepository(),
    );

    // Infinite scroll: حمّل الصفحة التالية عند اقتراب المستخدم من النهاية.
    _scrollController.addListener(_onScroll);

    _loadPosts();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    if (_scrollController.position.extentAfter < 480) {
      _loadPosts(loadMore: true);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final auth = AuthService();
      final user = await auth.getCurrentUser();
      if (mounted) {
        setState(() => _currentUser = user);
      }
    } catch (_) {
      // Ignore
    }
  }


  void _showLoginPrompt() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.login_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يرجى تسجيل الدخول للتفاعل مع المنشورات',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  openLoginAndRebuild(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF18A99A),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ===========================================================================
  // LOAD POSTS
  // ===========================================================================

  Future<void> _loadPosts({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    // منع الطلبات المتزامنة المكررة.
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final requestPage = loadMore ? _currentPage + 1 : 1;

    try {
      final posts = await _communityService.getPosts(
        page: requestPage,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (loadMore) {
          _posts.addAll(posts);
          _currentPage = requestPage;
          _isLoadingMore = false;
          // إذا أعادت الصفحة أقل من الحد الأقصى فلا توجد صفحات أخرى.
          _hasMore = posts.length >= _pageSize;
        } else {
          _posts
            ..clear()
            ..addAll(posts);
          _currentPage = 1;
          _hasMore = posts.length >= _pageSize;
          _isLoading = false;
        }
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        // عند فشل تحميل صفحة إضافية نحتفظ بالمنشورات القديمة.
        if (!loadMore) _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!loadMore) _errorMessage = 'تعذر تحميل المجتمع حاليًا';
      });
    }
  }

  // ===========================================================================
  // LIKE
  // ===========================================================================

  Future<void> _toggleLike(CommunityPost post) async {
    if (_isGuest) {
      _showLoginPrompt();
      return;
    }

    final index = _posts.indexWhere(
      (item) => item.id == post.id,
    );

    if (index == -1) return;

    final previous = _posts[index];

    setState(() {
      _posts[index] = previous.copyWith(
        isLiked: !previous.isLiked,
        likesCount: previous.isLiked
            ? (previous.likesCount > 0
                  ? previous.likesCount - 1
                  : 0)
            : previous.likesCount + 1,
      );
    });

    try {
      if (previous.isLiked) {
        await _communityService.unlikePost(previous.id);
      } else {
        await _communityService.likePost(previous.id);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (index >= 0 &&
            index < _posts.length &&
            _posts[index].id == previous.id) {
          _posts[index] = previous;
        }
      });

      _showMessage('تعذر تحديث الإعجاب');
    }
  }

  // ===========================================================================
  // SAVE
  // ===========================================================================

  Future<void> _toggleSave(CommunityPost post) async {
    if (_isGuest) {
      _showLoginPrompt();
      return;
    }

    final index = _posts.indexWhere(
      (item) => item.id == post.id,
    );

    if (index == -1) return;

    final previous = _posts[index];

    setState(() {
      _posts[index] = previous.copyWith(
        isSaved: !previous.isSaved,
        savesCount: previous.isSaved
            ? (previous.savesCount > 0
                  ? previous.savesCount - 1
                  : 0)
            : previous.savesCount + 1,
      );
    });

    try {
      if (previous.isSaved) {
        await _communityService.unsavePost(previous.id);
      } else {
        await _communityService.savePost(previous.id);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (index >= 0 &&
            index < _posts.length &&
            _posts[index].id == previous.id) {
          _posts[index] = previous;
        }
      });

      _showMessage('تعذر تحديث الحفظ');
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  // ===========================================================================
  // CREATE POST
  // ===========================================================================

  Future<void> _openCreatePostPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          communityService: _communityService,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadPosts(refresh: true);
    }
  }

  // ===========================================================================
  // COMMENTS
  // ===========================================================================

  void _showComments(
    CommunityPost post,
    int index,
  ) {
    if (_isGuest) {
      _showLoginPrompt();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        post: post,
        communityService: _communityService,
        onCommentsCountChanged: (newCount) {
          if (!mounted) return;

          setState(() {
            _posts[index] = _posts[index].copyWith(
              commentsCount: newCount,
            );
          });
        },
      ),
    );
  }

  // ===========================================================================
  // DELETE POST
  // ===========================================================================

  Future<void> _deletePost(CommunityPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المنشور'),
          content: const Text(
            'هل أنت تأكيد من رغبتك في حذف هذا المنشور؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _communityService.deletePost(post.id);

      if (!mounted) return;

      setState(() {
        _posts.removeWhere(
          (item) => item.id == post.id,
        );
      });

      _showMessage('تم حذف المنشور بنجاح');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e is ApiClientException
            ? e.message
            : 'تعذر حذف المنشور',
      );
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final showCreateButton = !_isGuest;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuPressed,
                onNotificationsPressed: _onNotificationsPressed,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
        bottomNavigationBar: _AddPostBar(
          visible: showCreateButton,
          onPressed: _openCreatePostPage,
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

  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody() {
    final colors = context.waynColors;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.brand,
        ),
      );
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return RefreshIndicator(
        color: colors.brand,
        onRefresh: () => _loadPosts(
          refresh: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: colors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _loadPosts(),
                child: const Text(
                  'إعادة المحاولة',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        color: colors.brand,
        onRefresh: () => _loadPosts(
          refresh: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_isGuest)
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12),
                child: WaynGuestBanner(
                  placement: WaynGuestBannerPlacement.inline,
                ),
              ),
            const SizedBox(height: 150),
            Icon(
              Icons.groups_rounded,
              size: 64,
              color: colors.brand.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'لا توجد منشورات حتى الآن',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'كن أول من يشارك تجربته مع مجتمع وين',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.brand,
      onRefresh: () => _loadPosts(
        refresh: true,
      ),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          20,
        ),
        // عنصر إضافي في النهاية: إشعار الزائر + مؤشر تحميل الصفحة التالية.
        itemCount:
            _posts.length + (_isGuest ? 1 : 0) + (_hasMore ? 1 : 0),
        itemBuilder: (context, rawIndex) {
          // إشعار تسجيل الدخول كأول عنصر في القائمة أسفل الهيدر مباشرة،
          // ويختفي عند السحب للأعلى أو زر X أو التمرير بعيدًا.
          if (_isGuest && rawIndex == 0) {
            return const WaynGuestBanner(
              placement: WaynGuestBannerPlacement.inline,
            );
          }

          final guestOffset = _isGuest ? 1 : 0;

          // مؤشر تحميل الصفحة التالية في نهاية القائمة.
          if (rawIndex == _posts.length + guestOffset) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: _isLoadingMore
                    ? SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: colors.brand,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          final postIndex = rawIndex - guestOffset;
          final post = _posts[postIndex];

          return Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
            ),
            child: CommunityPostCard(
              post: post,
              onLike: () => _toggleLike(post),
              onSave: () => _toggleSave(post),
              onComments: () => _showComments(
                post,
                postIndex,
              ),
              onDelete: () => _deletePost(post),
              onAuthorTap: (authorId) => openUserProfile(
                context,
                userId: authorId,
                isOwner: post.isOwner,
              ),
              onPlaceTap: (placeId) => openPlaceFromId(
                context,
                placeId,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// شريط إنشاء المنشور أسفل الشاشة
// ============================================================================

class _AddPostBar extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const _AddPostBar({
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final colors = context.waynColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF18A99A),
                      Color(0xFF087F78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.brand.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'إضافة منشور جديد',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
