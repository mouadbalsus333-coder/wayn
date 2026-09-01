import 'package:flutter/material.dart';

import '../../core/navigation/wayn_actions.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/utils/short_number.dart';
import '../../features/community/models/community_post.dart';
import '../../features/community/services/community_service.dart';
import '../../features/community/widgets/community_post_card.dart';
import '../../models/user_profile.dart';
import '../../services/repositories/repository_factory.dart';
import '../../services/social_service.dart';
import '../../services/user_service.dart';

/// صفحة حساب مستخدم عام.
///
/// تعرض البيانات الحقيقية من `GET /users/{id}` ومنشورات المستخدم من
/// المجتمع، مع زر متابعة يتحدث فعليًا عبر Backend.
class PublicProfilePage extends StatefulWidget {
  final String userId;
  final String? initialName;

  const PublicProfilePage({
    super.key,
    required this.userId,
    this.initialName,
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final UserService _userService = UserService();
  final SocialService _socialService = SocialService();
  late final CommunityService _communityService;

  UserProfile? _profile;
  List<CommunityPost> _posts = [];

  bool _loading = true;
  bool _followBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(
      createCommunityRepository(),
    );
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _userService.getUserProfile(widget.userId),
        _communityService.getPosts(
          userId: widget.userId,
          page: 1,
          limit: 100,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as UserProfile?;
        _posts = results[1] as List<CommunityPost>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الحساب';
      });
    }
  }

  void _showMessage(String message) {
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

  Future<void> _toggleFollow() async {
    final profile = _profile;

    if (profile == null || profile.isOwner || _followBusy) return;

    setState(() => _followBusy = true);

    try {
      if (profile.isFollowing) {
        final result = await _socialService.unfollow(widget.userId);
        if (!mounted) return;
        setState(() {
          _profile = profile.copyWith(
            isFollowing: false,
            followersCount: result.followersCount,
          );
        });
        _showMessage('تم إلغاء المتابعة');
      } else {
        final result = await _socialService.follow(widget.userId);
        if (!mounted) return;
        setState(() {
          _profile = profile.copyWith(
            isFollowing: true,
            followersCount: result.followersCount,
          );
        });
        _showMessage('تمت متابعة المستخدم');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر تنفيذ المتابعة');
    } finally {
      if (mounted) {
        setState(() => _followBusy = false);
      }
    }
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
                    : _error != null && _profile == null
                        ? _errorState(colors)
                        : RefreshIndicator(
                            color: colors.brand,
                            onRefresh: _refresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                30,
                              ),
                              children: [
                                _profileHeader(colors),
                                const SizedBox(height: 20),
                                _statsRow(colors),
                                const SizedBox(height: 12),
                                if (_posts.isEmpty)
                                  _emptyPosts(colors)
                                else
                                  ..._posts.map(
                                    (post) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: CommunityPostCard(
                                        post: post,
                                        onPlaceTap: (placeId) =>
                                            openPlaceFromId(
                                          context,
                                          placeId,
                                        ),
                                      ),
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

  Widget _errorState(WaynColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
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
            onPressed: () {
              setState(() => _loading = true);
              _refresh();
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
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
                'الملف الشخصي',
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

  Widget _profileHeader(WaynColors colors) {
    final profile = _profile!;

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : profile.username;

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
                    '@${profile.username}',
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!profile.isOwner)
              _followButton(colors, profile),
          ],
        ),
        if (profile.bio != null && profile.bio!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              profile.bio!,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _followButton(WaynColors colors, UserProfile profile) {
    return GestureDetector(
      onTap: _followBusy ? null : _toggleFollow,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: profile.isFollowing
              ? colors.surfaceAlt
              : colors.brand,
          borderRadius: BorderRadius.circular(12),
          border: profile.isFollowing
              ? Border.all(color: colors.brand.withValues(alpha: 0.4))
              : null,
        ),
        child: Center(
          child: _followBusy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: profile.isFollowing
                        ? colors.brand
                        : colors.onBrand,
                  ),
                )
              : Text(
                  profile.isFollowing ? 'متابَع' : 'متابعة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: profile.isFollowing
                        ? colors.brand
                        : colors.onBrand,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _statsRow(WaynColors colors) {
    final profile = _profile!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statCell(colors, profile.followersCount, 'المتابِعون'),
          _divider(colors),
          _statCell(colors, profile.followingCount, 'المتابَعون'),
          _divider(colors),
          _statCell(colors, profile.ratingsCount, 'التقييمات'),
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

  Widget _emptyPosts(WaynColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 56,
            color: colors.brand.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد تقييمات بعد',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'لم ينشر هذا المستخدم أي منشورات بعد',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
