import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/wayn_actions.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/utils/short_number.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../core/widgets/wayn_network_image.dart';
import '../../features/community/models/community_post.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/widgets/comments_sheet.dart';
import '../../features/community/widgets/community_post_card.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../../models/store.dart';
import '../../models/user.dart';
import '../../models/wallet.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/repository_factory.dart';
import '../../services/store_service.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';

/// صفحة "حسابي".
///
/// الترتيب:
/// صورة + اسم + username + ID + النقاط والمحفظة
/// ← الوصف
/// ← خط فاصل
/// ← إحصائيات الحساب
/// ← [التقييمات | الخزانة]
/// ← المحتوى.
class ProfilePage extends StatefulWidget {
  final User? user;

  const ProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _SectionTab {
  ratings,
  treasury,
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;

  final _auth = AuthService();
  final _userService = UserService();
  final _walletService = WalletService();

  late final CommunityService _communityService;

  final _storeService = StoreService();

  List<CommunityPost> _myPosts = [];
  List<StoreOwnership> _ownerships = [];

  int _points = 0;
  Wallet? _wallet;

  _SectionTab _activeSection = _SectionTab.ratings;

  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadFailed = false;

  bool _wardrobeLoading = false;
  bool _wardrobeLoaded = false;

  bool _walletLoading = true;
  bool _pointsLoading = true;

  String? _wardrobeError;

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
      setState(() {
        _initialLoading = false;
      });
    }
  }

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    openNotifications(context);
  }

  void _navigateToLogin() {
    openLoginAndRebuild(context);
  }

  // ============================================================
  // Data loading
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
      _loadWallet(),
      _loadMyPosts(),
    ]);

    if (_activeSection == _SectionTab.treasury) {
      await _loadOwnership();
    }

    if (!mounted) return;

    setState(() {
      _initialLoading = false;
      _refreshing = false;
    });
  }

  Future<void> _loadOwnership() async {
    if (_wardrobeLoading) return;

    setState(() {
      _wardrobeLoading = true;
      _wardrobeError = null;
    });

    try {
      final ownerships = await _storeService.ownership();

      if (!mounted) return;

      setState(() {
        _ownerships = ownerships;
        _wardrobeLoaded = true;
        _wardrobeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _wardrobeLoading = false;
        _wardrobeError = 'تعذر تحميل الخزانة.';
      });
    }
  }

  Future<void> _openTreasury() async {
    setState(() {
      _activeSection = _SectionTab.treasury;
    });

    await _loadOwnership();
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
      final points = await _userService.getMyPoints();

      if (!mounted) return;

      setState(() {
        _points = points;
        _pointsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pointsLoading = false;
      });

      _loadFailed = true;
    }
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await _walletService.getWallet();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _walletLoading = false;
      });
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
  // Post actions
  // ============================================================

  Future<void> _toggleLike(CommunityPost post) async {
    if (_user == null) {
      _showLoginPrompt();
      return;
    }

    final index = _myPosts.indexWhere(
      (item) => item.id == post.id,
    );

    if (index == -1) return;

    final previous = _myPosts[index];

    setState(() {
      _myPosts[index] = previous.copyWith(
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
        await _communityService.unlikePost(
          previous.id,
        );
      } else {
        await _communityService.likePost(
          previous.id,
        );
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

    final index = _myPosts.indexWhere(
      (item) => item.id == post.id,
    );

    if (index == -1) return;

    final previous = _myPosts[index];

    setState(() {
      _myPosts[index] = previous.copyWith(
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
        await _communityService.unsavePost(
          previous.id,
        );
      } else {
        await _communityService.savePost(
          previous.id,
        );
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
              const Icon(
                Icons.login_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يرجى تسجيل الدخول للتفاعل مع المنشورات',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .hideCurrentSnackBar();

                  _navigateToLogin();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF18A99A),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _showComments(
    CommunityPost post,
    int index,
  ) {
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
                onNotificationsPressed:
                    _onNotificationsPressed,
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
                              physics:
                                  const AlwaysScrollableScrollPhysics(
                                parent:
                                    BouncingScrollPhysics(),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                35,
                              ),
                              children: [
                                _buildAccountHeader(
                                  colors,
                                ),
                                const SizedBox(height: 14),
                                _buildDescriptionCard(
                                  colors,
                                ),
                                const SizedBox(height: 12),
                                _buildProfileDivider(
                                  colors,
                                ),
                                const SizedBox(height: 14),

                                // تم حذف بطاقة النقاط
                                // وزر "الحصول على النقاط".

                                _buildStatsRow(colors),
                                const SizedBox(height: 22),
                                _buildSectionToggle(
                                  colors,
                                ),
                                const SizedBox(height: 14),
                                if (_activeSection ==
                                    _SectionTab.ratings)
                                  _buildRatingsContent(
                                    colors,
                                  )
                                else
                                  _buildTreasuryContent(
                                    colors,
                                  ),
                                if (_loadFailed)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      top: 16,
                                    ),
                                    child:
                                        _buildRefreshFailed(
                                      colors,
                                    ),
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

  // ============================================================
  // Guest
  // ============================================================

  Widget _buildGuestProfile(
    WaynColors colors,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.brand.withValues(
                  alpha: 0.12,
                ),
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
                    borderRadius:
                        BorderRadius.circular(16),
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

  Widget _buildAccountHeader(
    WaynColors colors,
  ) {
    final user = _user!;

    final displayName =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'مستخدم WAYN';

    final username =
        user.username?.trim() ?? '';

    final avatarLetter = displayName.isEmpty
        ? 'و'
        : displayName.substring(0, 1);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
          child: Padding(
            padding:
                const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                _buildCopyableId(colors),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildAccountBalances(colors),
      ],
    );
  }

  Widget _buildAccountBalances(
    WaynColors colors,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPointsButton(colors),
        const SizedBox(height: 6),
        _buildWalletButton(colors),
      ],
    );
  }

  Widget _buildPointsButton(
    WaynColors colors,
  ) {
    return _buildHeaderActionButton(
      colors,
      icon: Icons.stars_rounded,
      iconColor: Colors.orange,
      iconBackground:
          Colors.orange.withValues(alpha: .12),
      value: _pointsLoading
          ? null
          : '$_points',
      loading: _pointsLoading,
      onTap: () {
        // النقاط معروضة من الرصيد الحقيقي للمستخدم.
      },
    );
  }

  Widget _buildWalletButton(
    WaynColors colors,
  ) {
    final coins =
        _wallet?.coinsBalance ?? 0;

    return _buildHeaderActionButton(
      colors,
      icon:
          Icons.account_balance_wallet_rounded,
      iconColor: colors.brand,
      iconBackground:
          colors.brand.withValues(alpha: .12),
      value: _walletLoading
          ? null
          : '$coins',
      loading: _walletLoading,
      onTap: _openWallet,
    );
  }

  /// زر أصغر قليلاً من التصميم السابق،
  /// مع الحفاظ على نفس الشكل والوظيفة.
  Widget _buildHeaderActionButton(
    WaynColors colors, {
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required VoidCallback onTap,
    String? value,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),
        child: Container(
          height: 42,
          constraints:
              const BoxConstraints(
            minWidth: 42,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: colors.divider,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 9,
                offset: const Offset(0, 3),
                color:
                    Colors.black.withValues(
                  alpha: .04,
                ),
              ),
            ],
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 5),
              if (loading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              else if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const WalletPage(),
      ),
    );
  }

  Widget _buildCopyableId(
    WaynColors colors,
  ) {
    final id = _user!.id;

    final displayId =
        id.length > 10
            ? id.substring(0, 10)
            : id;

    final truncated =
        id.length > 10
            ? '$displayId...'
            : displayId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ID: $truncated',
          textDirection:
              TextDirection.ltr,
          style: TextStyle(
            fontSize: 10,
            color: colors.textSecondary,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _copyToClipboard(
            id,
            'تم نسخ المعرف',
          ),
          child: Icon(
            Icons.copy_rounded,
            size: 14,
            color: colors.brand,
          ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(
    String value,
    String message,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
        ),
      );
    }
  }

  // ============================================================
  // Description
  // ============================================================

  Widget _buildDescriptionCard(
    WaynColors colors,
  ) {
    final bio =
        _user!.bio?.trim().isNotEmpty == true
            ? _user!.bio!.trim()
            : null;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'الوصف',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        if (bio != null)
          Text(
            bio,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.textPrimary,
            ),
          )
        else
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 17,
                color: colors.textMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'لا يوجد وصف بعد. يمكنك إضافته من قائمة الإعدادات.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProfileDivider(
    WaynColors colors,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: colors.divider,
      ),
    );
  }

  // ============================================================
  // Stats row
  // ============================================================

  Widget _buildStatsRow(
    WaynColors colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statCell(
            colors,
            _user!.followersCount,
            'المتابِعون',
          ),
          _divider(colors),
          _statCell(
            colors,
            _user!.followingCount,
            'المتابَعون',
          ),
          _divider(colors),
          _statCell(
            colors,
            _myPosts.length,
            'التقييمات',
          ),
        ],
      ),
    );
  }

  Widget _statCell(
    WaynColors colors,
    int value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color:
                  colors.textPrimary,
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

  Widget _divider(
    WaynColors colors,
  ) {
    return Container(
      width: 1,
      height: 34,
      color: colors.divider,
    );
  }

  // ============================================================
  // Section toggle
  // ============================================================

  Widget _buildSectionToggle(
    WaynColors colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _toggleButton(
            colors,
            icon:
                Icons.rate_review_outlined,
            label: 'التقييمات',
            active:
                _activeSection ==
                    _SectionTab.ratings,
            onTap: () => setState(
              () => _activeSection =
                  _SectionTab.ratings,
            ),
          ),
          const SizedBox(width: 6),
          _toggleButton(
            colors,
            icon:
                Icons.inventory_2_outlined,
            label: 'الخزانة',
            active:
                _activeSection ==
                    _SectionTab.treasury,
            onTap: _openTreasury,
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
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active
                ? colors.brand
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(15),
            border: active
                ? null
                : Border.all(
                    color: colors.divider,
                  ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? colors.onBrand
                    : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w800,
                  color: active
                      ? colors.onBrand
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Ratings content
  // ============================================================

  Widget _buildRatingsContent(
    WaynColors colors,
  ) {
    if (_myPosts.isEmpty) {
      return _emptySection(
        colors,
        icon:
            Icons.rate_review_outlined,
        title: 'لا توجد تقييمات بعد',
        subtitle:
            'منشورات المجتمع التي تشير إلى أماكن ستظهر هنا.',
      );
    }

    return Column(
      children: [
        for (
          int index = 0;
          index < _myPosts.length;
          index++
        )
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child: CommunityPostCard(
              post: _myPosts[index],
              onLike: () =>
                  _toggleLike(
                _myPosts[index],
              ),
              onSave: () =>
                  _toggleSave(
                _myPosts[index],
              ),
              onComments: () =>
                  _showComments(
                _myPosts[index],
                index,
              ),
              onAuthorTap: (authorId) =>
                  openUserProfile(
                context,
                userId: authorId,
                isOwner:
                    _myPosts[index].isOwner,
              ),
              onPlaceTap: (placeId) =>
                  openPlaceFromId(
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

  Widget _buildTreasuryContent(
    WaynColors colors,
  ) {
    if (_wardrobeLoading &&
        !_wardrobeLoaded) {
      return const Padding(
        padding: EdgeInsets.all(35),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_wardrobeError != null &&
        !_wardrobeLoaded) {
      return _wardrobeErrorSection(
        colors,
      );
    }

    if (_ownerships.isEmpty) {
      return _emptySection(
        colors,
        icon:
            Icons.inventory_2_outlined,
        title: 'خزانتك فارغة',
        subtitle:
            'ابدأ بشراء أول عنصر من متجر WAYN.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount:
          _ownerships.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .72,
      ),
      itemBuilder:
          (context, index) =>
              _ownershipCard(
        colors,
        _ownerships[index],
      ),
    );
  }

  Widget _ownershipCard(
    WaynColors colors,
    StoreOwnership ownership,
  ) {
    final item = ownership.item;

    final expired =
        ownership.expiresAt != null &&
        ownership.expiresAt!.isBefore(
          DateTime.now(),
        );

    final image = item.imageUrl == null
        ? Container(
            color: colors.surfaceAlt,
            alignment:
                Alignment.center,
            child: Icon(
              Icons.storefront_rounded,
              size: 40,
              color: colors.brand,
            ),
          )
        : WaynNetworkImage(
            imageUrl: item.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder:
                (_, _, _) => Container(
              color:
                  colors.surfaceAlt,
              alignment:
                  Alignment.center,
              child: Icon(
                Icons.storefront_rounded,
                color: colors.brand,
              ),
            ),
          );

    return Opacity(
      opacity: expired ? .58 : 1,
      child: Container(
        padding:
            const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(13),
                child: SizedBox(
                  width: double.infinity,
                  child: image,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.nameAr,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    FontWeight.w800,
                color:
                    colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الكمية: ${ownership.quantity}',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _expiryLabel(
                ownership.expiresAt,
              ),
              style: TextStyle(
                fontSize: 11,
                color: expired
                    ? colors.danger
                    : colors.textSecondary,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(
    DateTime? expiresAt,
  ) {
    if (expiresAt == null) {
      return 'دائم';
    }

    if (expiresAt.isBefore(
      DateTime.now(),
    )) {
      return 'منتهي';
    }

    final days = expiresAt
        .difference(DateTime.now())
        .inDays;

    if (days < 1) {
      return 'ينتهي اليوم';
    }

    if (days <= 30) {
      return 'ينتهي خلال $days يوم';
    }

    return 'ينتهي في ${expiresAt.year}-'
        '${expiresAt.month.toString().padLeft(2, '0')}-'
        '${expiresAt.day.toString().padLeft(2, '0')}';
  }

  Widget _wardrobeErrorSection(
    WaynColors colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _wardrobeError!,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _loadOwnership,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'إعادة المحاولة',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(
    WaynColors colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 52,
            color: colors.brand.withValues(
              alpha: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color:
                  colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshFailed(
    WaynColors colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(16),
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
                color:
                    colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}