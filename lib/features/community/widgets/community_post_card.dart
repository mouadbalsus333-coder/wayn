import 'package:flutter/material.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/navigation/wayn_actions.dart';
import '../../../core/theme/wayn_colors.dart';
import '../../../core/utils/short_number.dart';
import '../../../services/auth_service.dart';
import '../../../services/social_service.dart';
import '../models/community_post.dart';

/// بطاقة منشور المجتمع الموحّدة.
///
/// تستخدم في مجتمع والصفحات التي تعرض منشورات (مثل تقييمات حسابي) لضمان
/// تجربة موحّدة:
/// - اسم الحساب بلون مميز، واسم المكان بلون مختلف.
/// - نجوم التقييم تحت اسم المستخدم من البيانات الفعلية.
/// - نقاط المستخدم + زر متابعة لمن ليس هو المنشئ.
/// - بدون عرض التاريخ/الوقت.
class CommunityPostCard extends StatefulWidget {
  final CommunityPost post;

  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComments;
  final VoidCallback? onDelete;

  /// يستقبل userId الخاص بصاحب المنشور.
  final ValueChanged<String>? onAuthorTap;

  /// يستقبل placeId المكان المرتبط.
  final ValueChanged<String>? onPlaceTap;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onSave,
    this.onComments,
    this.onDelete,
    this.onAuthorTap,
    this.onPlaceTap,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  final SocialService _socialService = SocialService();

  late bool _isFollowing;
  bool _followBusy = false;

  CommunityPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _isFollowing = post.isFollowingAuthor;
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

  /// يعرض رسالة لطيفة تطلب تسجيل الدخول ولا ينفّذ الطلب على الـ backend.
  void _promptLogin() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.login_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'سجّل دخولك لتتمكن من متابعة الأعضاء',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF18A99A),
          duration: const Duration(seconds: 4),
        ),
      );
    }

  // ============================================================
  // OPTIONS MENU (ثلاث نقاط — مثبت على اليسار، يظهر للكل)
  // ============================================================

  /// يبني زر الثلاث نقاط مع القائمة المنسدلة.
  ///
  /// - المالك: حذف المنشور.
  /// - غير المالك: الإبلاغ عن المنشور.
  ///
  /// الزر ثابت على اليسار ولا يتأثر بطول الاسم أو المكان.
  Widget _buildOptionsMenu(WaynColors colors) {
    final isOwnerWithDelete =
        post.isOwner && widget.onDelete != null;

    final List<PopupMenuEntry<String>> items = [];

    if (isOwnerWithDelete) {
      items.add(
        PopupMenuItem(
          value: 'delete',
          child: _buildMenuItem(
            'حذف المنشور',
            Icons.delete_outline_rounded,
            Colors.redAccent,
          ),
        ),
      );
    } else if (!post.isOwner) {
      items.add(
        PopupMenuItem(
          value: 'report',
          child: _buildMenuItem(
            'إبلاغ عن منشور',
            Icons.report_rounded,
            Colors.redAccent,
          ),
        ),
      );
    } else {
      // المنشور الخاص بالمالك لكن بدون onDelete — لا نعرض شيئًا.
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: colors.textMuted,
        size: 20,
      ),
      onSelected: (value) {
        if (value == 'delete') {
          widget.onDelete?.call();
        } else if (value == 'report') {
          _showMessage('تم الإبلاغ عن المنشور');
        }
      },
      itemBuilder: (context) => items,
      constraints: const BoxConstraints(minWidth: 150),
      padding: EdgeInsets.zero,
      menuPadding: EdgeInsets.zero,
    );
  }

  Widget _buildMenuItem(String label, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          color: color,
          size: 18,
        ),
      ],
    );
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;

    // الزائر لا يملك حسابًا: نطلب تسجيل الدخول دون إرسال أي طلب للـ backend.
    try {
      final user = await AuthService().getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        _promptLogin();
        return;
      }
    } catch (_) {
      if (!mounted) return;
      _promptLogin();
      return;
    }

    setState(() => _followBusy = true);

    try {
      if (_isFollowing) {
        await _socialService.unfollow(post.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = false;
        });
        _showMessage('تم إلغاء المتابعة');
      } else {
        await _socialService.follow(post.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
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

  // ============================================================
  // Image viewer
  // ============================================================

  void _openFullImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white70,
                        size: 56,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
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
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final authorName = post.authorName?.trim().isNotEmpty == true
        ? post.authorName!.trim()
        : 'مستخدم وين';

    final placeName = post.placeName?.trim().isNotEmpty == true
        ? post.placeName!.trim()
        : 'مكان مرتبط';

    final avatarLetter = authorName.substring(0, 1);

    final fullImageUrl = BackendConfig.resolveMediaUrl(
      post.imageUrl,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================================================
            // USER HEADER
            // =========================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: widget.onAuthorTap == null
                      ? null
                      : () => widget.onAuthorTap!(post.userId),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.surfaceAlt,
                    child: Text(
                      avatarLetter,
                      style: TextStyle(
                        color: colors.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                            // ----- name + follow / points -----
                      if (!post.isOwner)
                        Row(
                          children: [
                            _AuthorPointsChip(
                              points: post.authorPoints,
                              colors: colors,
                            ),
                            const SizedBox(width: 8),
                            _FollowButton(
                              isFollowing: _isFollowing,
                              busy: _followBusy,
                              onPressed: _toggleFollow,
                              colors: colors,
                            ),
                          ],
                        ),

                      // ----- "قام X بتقييم Y" -----
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          Text(
                            'قام ',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onAuthorTap == null
                                ? null
                                : () => widget.onAuthorTap!(post.userId),
                            borderRadius: BorderRadius.circular(6),
                            child: Text(
                              authorName,
                              style: TextStyle(
                                color: colors.brand,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            ' بتقييم ',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onPlaceTap == null
                                ? null
                                : () => widget.onPlaceTap!(post.placeId),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: colors.accentPurple,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    placeName,
                                    style: TextStyle(
                                      color: colors.accentPurple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ----- النجوم مباشرة تحت جملة التقييم -----
                      if (post.rating != null) ...[
                        const SizedBox(height: 6),
                        _StarsRow(
                          rating: post.rating!,
                          colors: colors,
                        ),
                      ],
                                                            ],
                  ),
                ),
                // ----- ثلاث نقاط على اليسار (مثبت، لا يتحرك) -----
                const SizedBox(width: 8),
                _buildOptionsMenu(colors),
              ],
            ),

            // =========================================================
            // TEXT
            // =========================================================
            if (post.text != null && post.text!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExpandablePostText(text: post.text!),
            ],

            // =========================================================
            // IMAGE
            // =========================================================
            if (fullImageUrl != null && fullImageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: colors.surfaceAlt,
                  child: InkWell(
                    onTap: () => _openFullImage(context, fullImageUrl),
                    child: Image.network(
                      fullImageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      cacheWidth: 800,
                      cacheHeight: 800,
                      gaplessPlayback: true,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF18A99A),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 180,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF8B94A3),
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: colors.divider,
            ),
            const SizedBox(height: 8),

            // =========================================================
            // ACTIONS
            // =========================================================
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: formatCount(post.likesCount),
                    active: post.isLiked,
                    colors: colors,
                    onTap: widget.onLike,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: formatCount(post.commentsCount),
                    colors: colors,
                    onTap: widget.onComments,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: post.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: formatCount(post.savesCount),
                    active: post.isSaved,
                    colors: colors,
                    onTap: widget.onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Author points chip
// ============================================================

class _AuthorPointsChip extends StatelessWidget {
  final int points;
  final WaynColors colors;

  const _AuthorPointsChip({
    required this.points,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            size: 14,
            color: colors.warning,
          ),
          const SizedBox(width: 3),
          Text(
            formatCount(points),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Follow button
// ============================================================

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool busy;
  final VoidCallback onPressed;
  final WaynColors colors;

  const _FollowButton({
    required this.isFollowing,
    required this.busy,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final following = isFollowing;

    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: following
              ? colors.surfaceAlt
              : colors.brand,
          borderRadius: BorderRadius.circular(10),
          border: following
              ? Border.all(color: colors.brand.withValues(alpha: 0.4))
              : null,
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: following
                        ? colors.brand
                        : colors.onBrand,
                  ),
                )
              : Text(
                  following ? 'متابَع' : 'متابعة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: following ? colors.brand : colors.onBrand,
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================
// Stars
// ============================================================

class _StarsRow extends StatelessWidget {
  final double rating;
  final WaynColors colors;

  const _StarsRow({
    required this.rating,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = rating.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(left: 1),
          child: Icon(
            index < rounded
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: 15,
            color: const Color(0xFFF5A623),
          ),
        );
      }),
    );
  }
}

// ============================================================
// Expandable post text
// ============================================================

class _ExpandablePostText extends StatefulWidget {
  final String text;

  const _ExpandablePostText({required this.text});

  @override
  State<_ExpandablePostText> createState() =>
      _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<_ExpandablePostText> {
  static const int _collapsedMaxLines = 4;
  static const String _moreLabel = 'قراءة المزيد';
  static const String _lessLabel = 'عرض أقل';

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ExpandablePostText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  bool _overflows(double maxWidth, TextStyle style) {
    if (_expanded) return false;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      maxLines: _collapsedMaxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 15,
      height: 1.6,
    );

    final linkStyle = TextStyle(
      color: colors.brand,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(constraints.maxWidth, textStyle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: _expanded ? null : _collapsedMaxLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: textStyle,
            ),
            if (overflows)
              GestureDetector(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _expanded ? _lessLabel : _moreLabel,
                      textDirection: TextDirection.rtl,
                      style: linkStyle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================
// Action button
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final WaynColors colors;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? colors.brand : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
