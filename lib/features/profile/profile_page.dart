import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/wayn_actions.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/utils/short_number.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../features/community/models/community_post.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/widgets/comments_sheet.dart';
import '../../features/community/widgets/community_post_card.dart';
import '../../features/notifications/notifications_page.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/repository_factory.dart';
import '../../services/user_service.dart';

/// صفحة "حسابي".
///
/// الترتيب: صورة + اسم + ID ← خط فاصل ← بطاقة النقاط والسمعة ← الوصف
/// ← إحصائيات الحساب ← [التقييمات | الخزانة] ← المحتوى.
class ProfilePage extends StatefulWidget {
  final User? user;

  const ProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _SectionTab { ratings, treasury }

class _ProfilePageState extends State<ProfilePage> {
  User? _user;

  final _auth = AuthService();
  final _userService = UserService();
  late final CommunityService _communityService;

  List<CommunityPost> _myPosts = [];
  int _points = 0;

  _SectionTab _activeSection = _SectionTab.ratings;

  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _communityService = CommunityService(
      createCommunityRepository(),
    );
    if (_user != null) {
      _refresh();
    } else {
      setState(() => _initialLoading = false);
    }
  }

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    openNotifications(context);
  }

  void _navigateToLogin() {
    // يفتح شاشة تسجيل الدخول وبعد النجاح يعيد بناء الشيل بالكامل
    // ليصبح التطبيق في حالة المستخدم المسجّل وليس الزائر.
    openLoginAndRebuild(context);
  }

  // ============================================================
  // Data loading (real backend calls)
  // ============================================================
  // Data loading (real backend calls)
  // ============================================================

  Future<void> _refresh() async {
    if (_refreshing) return;

    _refreshing = true;

    if (mounted) {
      setState(() {
        _loadFailed = false;
      });
    }

    await Future.wait([
      _loadUser(),
      _loadPoints(),
      _loadMyPosts(),
    ]);

    if (!mounted) return;

    setState(() {
      _initialLoading = false;
      _refreshing = false;
    });
  }

  Future<void> _loadUser() async {
    try {
      final user = await _auth.getCurrentUser();

      if (user != null) {
        _user = user;
      }
    } catch (_) {
      _loadFailed = true;
    }
  }

  Future<void> _loadPoints() async {
    try {
      _points = await _userService.getMyPoints();
    } catch (_) {
      _loadFailed = true;
    }
  }

  Future<void> _loadMyPosts() async {
    final user = _user;
    if (user == null) return;

    try {
      final posts = await _communityService.getPosts(
        userId: user.id,
        page: 1,
        limit: 100,
      );

      _myPosts = posts;
    } catch (_) {
      _loadFailed = true;
    }
  }

  // ============================================================
  // Post actions (ratings section)
  // ============================================================

  Future<void> _toggleLike(CommunityPost post) async {
    if (_user == null) {
      _showLoginPrompt();
      return;
    }

    final index = _myPosts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;

    final previous = _myPosts[index];

    setState(() {
      _myPosts[index] = previous.copyWith(
        isLiked: !previous.isLiked,
        likesCount: previous.isLiked
            ? (previous.likesCount > 0 ? previous.likesCount - 1 : 0)
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
            index < _myPosts.length &&
            _myPosts[index].id == previous.id) {
          _myPosts[index] = previous;
        }
      });
    }
  }

  Future<void> _toggleSave(CommunityPost post) async {
    if (_user == null) {
      _showLoginPrompt();
      return;
    }

    final index = _myPosts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;

    final previous = _myPosts[index];

    setState(() {
      _myPosts[index] = previous.copyWith(
        isSaved: !previous.isSaved,
        savesCount: previous.isSaved
            ? (previous.savesCount > 0 ? previous.savesCount - 1 : 0)
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
            index < _myPosts.length &&
            _myPosts[index].id == previous.id) {
          _myPosts[index] = previous;
        }
      });
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
                  _navigateToLogin();
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

  void _showComments(CommunityPost post, int index) {
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
            _myPosts[index] = _myPosts[index].copyWith(
              commentsCount: newCount,
            );
          });
        },
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

@override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
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
              Expanded(
                child: _initialLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF18A99A),
                        ),
                      )
                    : _user == null
                        ? _buildGuestProfile(colors)
                        : RefreshIndicator(
                            color: colors.brand,
                            onRefresh: _refresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                35,
                              ),
                              children: [
                                _buildAccountHeader(colors),
                                const SizedBox(height: 14),
                                _buildDescriptionCard(colors),
                                const SizedBox(height: 14),
                                _buildStatsRow(colors),
                                const SizedBox(height: 10),
                                _buildPointsReputationCompact(colors),
                                const SizedBox(height: 22),
                                _buildSectionToggle(colors),
                                const SizedBox(height: 14),
                                if (_activeSection == _SectionTab.ratings)
                                  _buildRatingsContent(colors)
                                else
                                  _buildTreasuryContent(colors),
                                if (_loadFailed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _buildRefreshFailed(colors),
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestProfile(WaynColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'مرحباً بك كزائر',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'سجّل دخولك للوصول إلى حسابك وإدارة ملفك الشخصي',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _navigateToLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'قم بتسجيل الدخول',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Account header
  // ============================================================

  Widget _buildAccountHeader(WaynColors colors) {
    final user = _user!;

    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'مستخدم WAYN';

    final username = user.username?.trim() ?? '';

    final avatarLetter = displayName.isEmpty
        ? 'و'
        : displayName.substring(0, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.surfaceAlt,
              child: Text(
                avatarLetter,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: colors.brand,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildCopyableId(colors),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(
          height: 1,
          color: colors.divider,
        ),
      ],
    );
  }

  Widget _buildCopyableId(WaynColors colors) {
    final id = _user!.id;
    final displayId = id.length > 10 ? id.substring(0, 10) : id;
    final truncated = id.length > 10 ? '$displayId...' : displayId;

    return Row(
      children: [
        Text(
          'ID: $truncated',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _copyToClipboard(id, 'تم نسخ المعرف'),
          child: Icon(
            Icons.copy_rounded,
            size: 14,
            color: colors.brand,
          ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  // ============================================================
  // Points + reputation (compact, side-by-side under stats)
  // ============================================================

  Widget _buildPointsReputationCompact(WaynColors colors) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, size: 18, color: colors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'النقاط',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatCount(_points),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 18, color: colors.accentPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'السمعة',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatCount(_user!.reputationScore),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Description
  // ============================================================

  Widget _buildDescriptionCard(WaynColors colors) {
    final bio = _user!.bio?.trim().isNotEmpty == true
        ? _user!.bio!.trim()
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الوصف',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (bio != null)
            Text(
              bio,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colors.textPrimary,
              ),
            )
          else
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا يوجد وصف بعد. يمكنك إضافته من قائمة الإعدادات.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Stats row (followers / following / ratings)
  // ============================================================

  Widget _buildStatsRow(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statCell(colors, _user!.followersCount, 'المتابِعون'),
          _divider(colors),
          _statCell(colors, _user!.followingCount, 'المتابَعون'),
          _divider(colors),
          _statCell(colors, _myPosts.length, 'التقييمات'),
        ],
      ),
    );
  }

  Widget _statCell(WaynColors colors, int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(WaynColors colors) {
    return Container(
      width: 1,
      height: 34,
      color: colors.divider,
    );
  }

  // ============================================================
  // Section toggle: [التقييمات | الخزانة]
  // ============================================================

  Widget _buildSectionToggle(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _toggleButton(
            colors,
            icon: Icons.rate_review_outlined,
            label: 'التقييمات',
            active: _activeSection == _SectionTab.ratings,
            onTap: () =>
                setState(() => _activeSection = _SectionTab.ratings),
          ),
          const SizedBox(width: 6),
          _toggleButton(
            colors,
            icon: Icons.inventory_2_outlined,
            label: 'الخزانة',
            active: _activeSection == _SectionTab.treasury,
            onTap: () =>
                setState(() => _activeSection = _SectionTab.treasury),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(
    WaynColors colors, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? colors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: active
                ? null
                : Border.all(
                    color: colors.divider,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? colors.onBrand : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? colors.onBrand : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Ratings content (my posts)
  // ============================================================

  Widget _buildRatingsContent(WaynColors colors) {
    if (_myPosts.isEmpty) {
      return _emptySection(
        colors,
        icon: Icons.rate_review_outlined,
        title: 'لا توجد تقييمات بعد',
        subtitle: 'منشورات المجتمع التي تشير إلى أماكن ستظهر هنا.',
      );
    }

    return Column(
      children: [
        for (int index = 0; index < _myPosts.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCard(
              post: _myPosts[index],
              onLike: () => _toggleLike(_myPosts[index]),
              onSave: () => _toggleSave(_myPosts[index]),
              onComments: () => _showComments(_myPosts[index], index),
              onAuthorTap: (authorId) => openUserProfile(
                context,
                userId: authorId,
                isOwner: _myPosts[index].isOwner,
              ),
              onPlaceTap: (placeId) => openPlaceFromId(
                context,
                placeId,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // Treasury content
  // ============================================================

  Widget _buildTreasuryContent(WaynColors colors) {
    return _emptySection(
      colors,
      icon: Icons.inventory_2_outlined,
      title: 'خزانتك فارغة',
      subtitle:
          'العناصر التي تشتريها من المتجر ستظهر هنا بعد توفّر نظام المشتريات.',
    );
  }

  Widget _emptySection(
    WaynColors colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 52,
            color: colors.brand.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshFailed(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: colors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعذر تحديث بعض البيانات، اسحب للأسفل لإعادة المحاولة.',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
