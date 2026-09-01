import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../features/community/services/community_service.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/repository_factory.dart';
import '../../services/user_service.dart';
import 'ratings_page.dart';
import 'treasury_page.dart';

/// صفحة "حسابي".
///
/// تعرض معلومات الحساب الحقيقية مع دعم السحب للأسفل لتحديث البيانات
/// من Backend. تتضمن: الـ ID، صف الإحصائيات (المتابعون/المتابَعون/
/// التقييمات)، الوصف، بطاقتا النقاط والسمعة، وقسمي "التقييمات"
/// و"الخزانة".
class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User _user;

  final _auth = AuthService();
  final _userService = UserService();
  late final CommunityService _communityService;

  int _points = 0;
  int _ratingsCount = 0;

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
    _refresh();
  }

  // ============================================================
  // Data loading (real backend calls)
  // ============================================================

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    debugPrint('Profile notifications pressed');
  }

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
      _loadRatingsCount(),
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

  Future<void> _loadRatingsCount() async {
    try {
      final posts = await _communityService.getPosts(
        userId: _user.id,
        page: 1,
        limit: 100,
      );

      _ratingsCount = posts.length;
    } catch (_) {
      _loadFailed = true;
    }
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
                            const SizedBox(height: 20),
                            _buildStatsRow(colors),
                            const SizedBox(height: 16),
                            _buildDescriptionCard(colors),
                            const SizedBox(height: 16),
                            _buildPointsReputationRow(colors),
                            const SizedBox(height: 24),
                            _buildSectionsCard(colors),
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

  // ============================================================
  // Account header (avatar + name + @username + ID + divider)
  // ============================================================

  Widget _buildAccountHeader(WaynColors colors) {
    final displayName = _user.displayName?.trim().isNotEmpty == true
        ? _user.displayName!.trim()
        : 'مستخدم WAYN';

    final username = _user.username?.trim() ?? '';

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
    final id = _user.id;
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
  // Stats row: المتابعون / المتابَعون / التقييمات
  // ============================================================

  Widget _buildStatsRow(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statCell(
            colors,
            value: _followersCount,
            label: 'المتابِعون',
          ),
          _statDivider(colors),
          _statCell(
            colors,
            value: _followingCount,
            label: 'المتابَعون',
          ),
          _statDivider(colors),
          _statCell(
            colors,
            value: _ratingsCount,
            label: 'التقييمات',
          ),
        ],
      ),
    );
  }

  Widget _statCell(
    WaynColors colors, {
    required int value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(WaynColors colors) {
    return Container(
      width: 1,
      height: 38,
      color: colors.divider,
    );
  }

  // ============================================================
  // وصف الحساب
  // ============================================================

  Widget _buildDescriptionCard(WaynColors colors) {
    final bio = _user.bio?.trim().isNotEmpty == true
        ? _user.bio!.trim()
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
  // النقاط والسمعة (بطاقتان مضغوطتان)
  // ============================================================

  Widget _buildPointsReputationRow(WaynColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _compactValueCard(
            colors,
            title: 'النقاط',
            value: _points,
            icon: Icons.stars_rounded,
            iconColor: colors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _compactValueCard(
            colors,
            title: 'السمعة',
            value: _reputationScore,
            icon: Icons.workspace_premium_rounded,
            iconColor: colors.accentPurple,
          ),
        ),
      ],
    );
  }

  Widget _compactValueCard(
    WaynColors colors, {
    required String title,
    required int value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // قسمي التقييمات والخزانة
  // ============================================================

  Widget _buildSectionsCard(WaynColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _sectionTile(
            colors,
            icon: Icons.rate_review_outlined,
            title: 'التقييمات',
            subtitle: 'منشوراتك المرتبطة بالأماكن ($_ratingsCount)',
            onTap: _openRatings,
          ),
          Divider(
            height: 1,
            indent: 72,
            endIndent: 15,
            color: colors.divider,
          ),
          _sectionTile(
            colors,
            icon: Icons.inventory_2_outlined,
            title: 'الخزانة',
            subtitle: 'العناصر التي تشتريها من المتجر',
            onTap: _openTreasury,
          ),
        ],
      ),
    );
  }

  Widget _sectionTile(
    WaynColors colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: colors.brand,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: colors.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: colors.textMuted,
      ),
    );
  }

  void _openRatings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsPage(
          userId: _user.id,
        ),
      ),
    );
  }

  void _openTreasury() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TreasuryPage(),
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

  // ============================================================
  // Values
  // ============================================================

  /// المتابِعون: مأخوذة من بيانات المستخدم إن وفّرها Backend.
  int get _followersCount =>
      _user.followersCount;

  /// المتابَعون: مأخوذة من بيانات المستخدم إن وفّرها Backend.
  int get _followingCount =>
      _user.followingCount;

  /// السمعة: مأخوذة من بيانات المستخدم إن وفّرها Backend.
  int get _reputationScore =>
      _user.reputationScore;
}
