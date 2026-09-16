import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:like_button/like_button.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/navigation/wayn_actions.dart';
import '../../../core/theme/wayn_colors.dart';
import '../../../core/utils/short_number.dart';
import '../../../core/widgets/wayn_network_image.dart';
import '../../../services/auth_service.dart';
import '../../../services/social_service.dart';
import '../models/community_post.dart';

// ============================================================
// SHARED ACCENTS
// ============================================================

const Color _kAmber = Color(0xFFF5A524);
const Color _kLikeColor = Color(0xFFE0555C);
const Color _kSuccessColor = Color(0xFF18A99A);

// ============================================================
// COMMUNITY POST CARD
// ============================================================

class CommunityPostCard extends StatefulWidget {
  final CommunityPost post;

  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComments;
  final VoidCallback? onDelete;

  final ValueChanged<String>? onAuthorTap;

  final ValueChanged<String>? onPlaceTap;

  final String? postDescriptionText;

  final VoidCallback? onHide;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onSave,
    this.onComments,
    this.onDelete,
    this.onAuthorTap,
    this.onPlaceTap,
    this.postDescriptionText,
    this.onHide,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  final SocialService _socialService = SocialService();

  late bool _isFollowing;

  bool _followBusy = false;
  bool _followSuccess = false;

  CommunityPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _isFollowing = post.isFollowingAuthor;
  }

  @override
  void didUpdateWidget(
    covariant CommunityPostCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.userId != widget.post.userId) {
      _isFollowing = widget.post.isFollowingAuthor;
      _followBusy = false;
      _followSuccess = false;
      return;
    }

    if (oldWidget.post.isFollowingAuthor !=
        widget.post.isFollowingAuthor) {
      _isFollowing = widget.post.isFollowingAuthor;
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          elevation: 6,
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          backgroundColor: _kSuccessColor,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(
                Iconsax.login_1,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'سجّل دخولك لتتمكن من متابعة الأعضاء',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .hideCurrentSnackBar();

                  openLoginAndRebuild(context);
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
        ),
      );
  }

  // ============================================================
  // OPTIONS MENU
  // ============================================================

  Widget _buildOptionsMenu(WaynColors colors) {
    return _AnimatedMoreButton(
      colors: colors,
      onSelected: (value) {
        switch (value) {
          case 'delete':
            _showDeleteConfirmation(colors);
            break;

          case 'report':
            _showReportDialog(colors);
            break;

          case 'hide':
            _showHideConfirmation(colors).then((confirmed) {
              if (!mounted || !confirmed) return;
              _hidePost();
            });
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        if (post.isOwner) {
          if (widget.onDelete != null) {
            items.add(
              PopupMenuItem<String>(
                value: 'delete',
                child: _buildMenuItem(
                  'حذف المنشور',
                  Iconsax.trash,
                  Colors.redAccent,
                ),
              ),
            );
          }
        } else {
          items.add(
            PopupMenuItem<String>(
              value: 'report',
              child: _buildMenuItem(
                'طعن على المنشور',
                Iconsax.flag,
                Colors.redAccent,
              ),
            ),
          );

          items.add(
            PopupMenuItem<String>(
              value: 'hide',
              child: _buildMenuItem(
                'إخفاء المنشور',
                Iconsax.eye_slash,
                colors.textSecondary,
              ),
            ),
          );
        }

        return items;
      },
    );
  }

  Widget _buildMenuItem(
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          icon,
          color: color,
          size: 19,
        ),
      ],
    );
  }

  // ============================================================
  // HIDE
  // ============================================================

  void _hidePost() {
    widget.onHide?.call();

    if (mounted) {
      _showMessage('تم إخفاء المنشور عنك');
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow() async {
    if (_followBusy) return;

    HapticFeedback.selectionClick();

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

    setState(() {
      _followBusy = true;
      _followSuccess = false;
    });

    try {
      if (_isFollowing) {
        await _socialService.unfollow(post.userId);

        if (!mounted) return;

        HapticFeedback.lightImpact();

        setState(() {
          _isFollowing = false;
          _followBusy = false;
          _followSuccess = false;
        });

        _showMessage('تم إلغاء المتابعة');
      } else {
        await _socialService.follow(post.userId);

        if (!mounted) return;

        HapticFeedback.mediumImpact();

        setState(() {
          _isFollowing = true;
          _followSuccess = true;
        });

        _showMessage('تمت متابعة المستخدم');

        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) return;

        setState(() {
          _followBusy = false;
          _followSuccess = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _followBusy = false;
        _followSuccess = false;
      });

      HapticFeedback.heavyImpact();

      _showMessage('تعذر تنفيذ المتابعة');
    }
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<bool> _handleLike(bool isLiked) async {
    HapticFeedback.lightImpact();

    try {
      widget.onLike?.call();

      return !isLiked;
    } catch (_) {
      HapticFeedback.heavyImpact();
      return isLiked;
    }
  }

  // ============================================================
  // IMAGE VIEWER
  // ============================================================

  void _openFullImage(
    BuildContext context,
    String imageUrl,
  ) {
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
                  child: WaynNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    loadingBuilder: (
                      context,
                      child,
                      progress,
                    ) {
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
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Iconsax.gallery_slash,
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
                child: _ImageCloseButton(
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final authorName =
        post.authorName?.trim().isNotEmpty == true
            ? post.authorName!.trim()
            : 'مستخدم وين';

    final placeName =
        post.placeName?.trim().isNotEmpty == true
            ? post.placeName!.trim()
            : 'مكان مرتبط';

    final placeCity =
        post.placeCity?.trim().isNotEmpty == true
            ? post.placeCity!.trim()
            : null;

    final avatarLetter = authorName.substring(0, 1);

    final fullImageUrl = BackendConfig.resolveMediaUrl(
      post.imageUrl,
    );

    final cardContent = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRatingAndPlaceSection(
              colors,
              placeName,
            ),

            const SizedBox(height: 12),

            Divider(
              height: 1,
              color: colors.divider.withValues(alpha: 0.7),
            ),

            const SizedBox(height: 12),

            // =====================================================
            // USER HEADER
            // =====================================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarButton(
                  letter: avatarLetter,
                  colors: colors,
                  onTap: widget.onAuthorTap == null
                      ? null
                      : () => widget.onAuthorTap!(
                            post.userId,
                          ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: InkWell(
                    onTap: widget.onAuthorTap == null
                        ? null
                        : () => widget.onAuthorTap!(
                            post.userId,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: colors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text(
                                _formatPostTime(
                                  post.createdAt,
                                ),
                                textDirection:
                                    TextDirection.rtl,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (placeCity != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 9.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    placeCity,
                                    textDirection:
                                        TextDirection.rtl,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 9.5,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                _AuthorPointsChip(
                  points: post.authorPoints,
                  colors: colors,
                ),

                const SizedBox(width: 6),

                if (!post.isOwner)
                  _FollowButton(
                    isFollowing: _isFollowing,
                    busy: _followBusy,
                    success: _followSuccess,
                    onPressed: _toggleFollow,
                    colors: colors,
                  ),
              ],
            ),

            // =====================================================
            // TEXT
            // =====================================================

            if (post.text != null &&
                post.text!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExpandablePostText(
                text: post.text!,
              ),
            ],

            // =====================================================
            // IMAGE
            // =====================================================

            if (fullImageUrl != null &&
                fullImageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: colors.surfaceAlt,
                  child: InkWell(
                    onTap: () => _openFullImage(
                      context,
                      fullImageUrl,
                    ),
                    child: WaynNetworkImage(
                      imageUrl: fullImageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      loadingBuilder: (
                        context,
                        child,
                        progress,
                      ) {
                        if (progress == null) {
                          return child;
                        }

                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.brand,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: Icon(
                              Iconsax.gallery_slash,
                              color: colors.textMuted,
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
              color: colors.divider.withValues(alpha: 0.7),
            ),

            const SizedBox(height: 5),

            // =====================================================
            // ACTIONS
            // =====================================================

            Row(
              children: [
                Expanded(
                  child: _LikeActionButton(
                    isLiked: post.isLiked,
                    likeCount: post.likesCount,
                    colors: colors,
                    onTap: _handleLike,
                  ),
                ),
                Expanded(
                  child: _AnimatedActionButton(
                    icon: Iconsax.message_2,
                    activeIcon: Iconsax.message_2,
                    label: formatCount(
                      post.commentsCount,
                    ),
                    active: false,
                    activeColor: colors.brand,
                    colors: colors,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onComments?.call();
                    },
                  ),
                ),
                Expanded(
                  child: _AnimatedActionButton(
                    icon: Iconsax.bookmark,
                    activeIcon: Iconsax.bookmark_2,
                    label: formatCount(
                      post.savesCount,
                    ),
                    active: post.isSaved,
                    activeColor: colors.brand,
                    colors: colors,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onSave?.call();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return cardContent
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.018,
          end: 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatPostTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();

    final hour = localTime.hour;
    final minute = localTime.minute;

    final period = hour < 12 ? 'صباحا' : 'مساء';

    final displayHour = hour > 12
        ? hour - 12
        : hour == 0
            ? 12
            : hour;

    if (minute == 0) {
      return '$displayHour $period';
    }

    final formattedMinute =
        minute.toString().padLeft(2, '0');

    return '$displayHour:$formattedMinute $period';
  }

  // ============================================================
  // HIDE CONFIRMATION
  // ============================================================

  Future<bool> _showHideConfirmation(
    WaynColors colors,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: Icon(
              Iconsax.eye_slash,
              color: colors.textSecondary,
              size: 28,
            ),
            title: const Text(
              'إخفاء المنشور',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'هل أنت متأكد أنك تريد إخفاء المنشور؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: Text(
                  'إخفاء',
                  style: TextStyle(
                    color: colors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<bool> _showDeleteConfirmation(
    WaynColors colors,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: const Icon(
              Iconsax.trash,
              color: Colors.redAccent,
              size: 28,
            ),
            title: const Text(
              'حذف المنشور',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'هل أنت متأكد أنك تريد الحذف؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      HapticFeedback.mediumImpact();
      widget.onDelete?.call();
    }

    return result ?? false;
  }

  // ============================================================
  // RATING + PLACE + MORE
  // ============================================================

  Widget _buildRatingAndPlaceSection(
    WaynColors colors,
    String placeName,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (post.rating != null)
          _CompactRatingBadge(
            rating: post.rating!,
          ),

        const SizedBox(width: 10),

        Expanded(
          child: _PlaceButton(
            placeName: placeName,
            colors: colors,
            onTap: widget.onPlaceTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();

                    widget.onPlaceTap!(
                      post.placeId,
                    );
                  },
          ),
        ),

        const SizedBox(width: 6),

        _buildOptionsMenu(colors),
      ],
    );
  }

  // ============================================================
  // REPORT
  // ============================================================

  void _showReportDialog(WaynColors colors) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: const Icon(
              Iconsax.flag,
              color: Colors.redAccent,
              size: 28,
            ),
            title: const Text(
              'طعن على المنشور',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'هل تريد إرسال طعن على هذا المنشور؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();

                  HapticFeedback.mediumImpact();

                  _showMessage(
                    'تم إرسال البلاغ عن المنشور',
                  );
                },
                child: const Text(
                  'إبلاغ',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// THREE DOTS MENU
// ============================================================

class _AnimatedMoreButton extends StatefulWidget {
  final WaynColors colors;
  final PopupMenuItemBuilder<String> itemBuilder;
  final ValueChanged<String> onSelected;

  const _AnimatedMoreButton({
    required this.colors,
    required this.itemBuilder,
    required this.onSelected,
  });

  @override
  State<_AnimatedMoreButton> createState() =>
      _AnimatedMoreButtonState();
}

class _AnimatedMoreButtonState
    extends State<_AnimatedMoreButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'المزيد',
      onSelected: widget.onSelected,
      itemBuilder: widget.itemBuilder,
      constraints: const BoxConstraints(
        minWidth: 185,
      ),
      padding: EdgeInsets.zero,
      menuPadding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      onOpened: () => _setPressed(true),
      onCanceled: () => _setPressed(false),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _pressed
                      ? widget.colors.surfaceAlt
                      : widget.colors.surfaceAlt.withValues(
                          alpha: 0.55,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: widget.colors.textMuted,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PLACE BUTTON
// ============================================================

class _PlaceButton extends StatefulWidget {
  final String placeName;
  final WaynColors colors;
  final VoidCallback? onTap;

  const _PlaceButton({
    required this.placeName,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_PlaceButton> createState() => _PlaceButtonState();
}

class _PlaceButtonState extends State<_PlaceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);

        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.colors.accentPurple.withValues(
              alpha: _pressed ? 0.13 : 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.location,
                size: 15,
                color: widget.colors.accentPurple,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  widget.placeName,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: widget.colors.accentPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AVATAR
// ============================================================

class _AvatarButton extends StatefulWidget {
  final String letter;
  final WaynColors colors;
  final VoidCallback? onTap;

  const _AvatarButton({
    required this.letter,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);

        if (widget.onTap != null) {
          HapticFeedback.selectionClick();
          widget.onTap!();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: widget.colors.brand.withValues(
            alpha: 0.10,
          ),
          child: Text(
            widget.letter,
            style: TextStyle(
              color: widget.colors.brand,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// IMAGE CLOSE BUTTON
// ============================================================

class _ImageCloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ImageCloseButton({
    required this.onTap,
  });

  @override
  State<_ImageCloseButton> createState() =>
      _ImageCloseButtonState();
}

class _ImageCloseButtonState
    extends State<_ImageCloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(
              Iconsax.close_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUTHOR POINTS
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.medal_star,
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
// FOLLOW BUTTON
// ============================================================

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool busy;
  final bool success;
  final VoidCallback onPressed;
  final WaynColors colors;

  const _FollowButton({
    required this.isFollowing,
    required this.busy,
    required this.success,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = success
        ? colors.brand
        : isFollowing
            ? colors.surfaceAlt
            : colors.brand;

    final foregroundColor = isFollowing && !success
        ? colors.brand
        : colors.onBrand;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onPressed,
      child: AnimatedScale(
        scale: busy ? 0.95 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: 31,
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: isFollowing && !success
                ? Border.all(
                    color: colors.brand.withValues(
                      alpha: 0.30,
                    ),
                  )
                : null,
            boxShadow: success
                ? [
                    BoxShadow(
                      color: colors.brand.withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 260,
              ),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (
                child,
                animation,
              ) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
              child: success
                  ? Row(
                      key: const ValueKey(
                        'follow-success',
                      ),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.tick_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'تمت المتابعة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : busy
                      ? SizedBox(
                          key: const ValueKey(
                            'follow-loading',
                          ),
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foregroundColor,
                          ),
                        )
                      : Row(
                          key: ValueKey(
                            isFollowing
                                ? 'following'
                                : 'follow',
                          ),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing
                                  ? Iconsax.tick_circle
                                  : Iconsax.user_add,
                              color: foregroundColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFollowing
                                  ? 'متابَع'
                                  : 'متابعة',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RATING STAR
// ============================================================

class _CompactRatingBadge extends StatefulWidget {
  final double rating;

  const _CompactRatingBadge({
    required this.rating,
  });

  @override
  State<_CompactRatingBadge> createState() =>
      _CompactRatingBadgeState();
}

class _CompactRatingBadgeState
    extends State<_CompactRatingBadge> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ratingValue =
        widget.rating.clamp(0.0, 5.0).toDouble();

    final ratingText =
        ratingValue.toStringAsFixed(
      ratingValue.truncateToDouble() == ratingValue
          ? 0
          : 1,
    );

    return Semantics(
      label: 'التقييم $ratingText من 5',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer soft glow.
                Icon(
                  Icons.star_rounded,
                  size: 48,
                  color: _kAmber.withValues(
                    alpha: 0.12,
                  ),
                ),

                // Main star.
                Icon(
                  Icons.star_rounded,
                  size: 44,
                  color: _kAmber,
                ),

                // Slight inner highlight.
                Icon(
                  Icons.star_rounded,
                  size: 39,
                  color: _kAmber.withValues(
                    alpha: 0.94,
                  ),
                ),

                // Number is physically centered INSIDE the star.
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, 0.5),
                    child: Text(
                      ratingText,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Color(0x70000000),
                            blurRadius: 2.5,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EXPANDABLE POST TEXT
// ============================================================

class _ExpandablePostText extends StatefulWidget {
  final String text;

  const _ExpandablePostText({
    required this.text,
  });

  @override
  State<_ExpandablePostText> createState() =>
      _ExpandablePostTextState();
}

class _ExpandablePostTextState
    extends State<_ExpandablePostText> {
  static const int _collapsedMaxLines = 4;

  bool _expanded = false;

  @override
  void didUpdateWidget(
    covariant _ExpandablePostText oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  bool _overflows(
    double maxWidth,
    TextStyle style,
  ) {
    if (_expanded) return false;

    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: style,
      ),
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
      fontSize: 14.5,
      height: 1.6,
    );

    final linkStyle = TextStyle(
      color: colors.brand,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(
          constraints.maxWidth,
          textStyle,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Text(
                widget.text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: _expanded
                    ? null
                    : _collapsedMaxLines,
                overflow: _expanded
                    ? null
                    : TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (overflows)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();

                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedDefaultTextStyle(
                      duration:
                          const Duration(milliseconds: 180),
                      style: linkStyle,
                      child: Text(
                        _expanded
                            ? 'عرض أقل'
                            : 'قراءة المزيد',
                        textDirection: TextDirection.rtl,
                      ),
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
// LIKE ACTION
// ============================================================

class _LikeActionButton extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final WaynColors colors;
  final Future<bool?> Function(bool isLiked) onTap;

  const _LikeActionButton({
    required this.isLiked,
    required this.likeCount,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LikeButton(
      size: 21,
      isLiked: isLiked,
      likeCount: likeCount,
      onTap: onTap,
      animationDuration:
          const Duration(milliseconds: 720),
      likeCountAnimationDuration:
          const Duration(milliseconds: 360),
      mainAxisAlignment: MainAxisAlignment.center,
      likeCountPadding:
          const EdgeInsetsDirectional.only(
        start: 6,
      ),
      circleColor: const CircleColor(
        start: Color(0xFFFFCDD2),
        end: Color(0xFFE0555C),
      ),
      bubblesColor: const BubblesColor(
        dotPrimaryColor: Color(0xFFFF8A8A),
        dotSecondaryColor: Color(0xFFE0555C),
        dotThirdColor: Color(0xFFFFB3B3),
        dotLastColor: Color(0xFFFFCDD2),
      ),
      likeBuilder: (liked) {
        return _ActionIconShell(
          active: liked,
          activeColor: _kLikeColor,
          colors: colors,
          child: Icon(
            liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 20,
            color: liked
                ? _kLikeColor
                : colors.textSecondary,
          ),
        );
      },
      countBuilder: (
        count,
        liked,
        text,
      ) {
        return Text(
          formatCount(count ?? 0),
          style: TextStyle(
            color: liked
                ? _kLikeColor
                : colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
      },
      countDecoration: (
        Widget count,
        int? likeCount,
      ) {
        return count;
      },
    );
  }
}

// ============================================================
// UNIFIED ACTION BUTTON
// ============================================================

class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final Color? activeColor;
  final WaynColors colors;
  final VoidCallback? onTap;

  const _AnimatedActionButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.colors,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  @override
  State<_AnimatedActionButton> createState() =>
      _AnimatedActionButtonState();
}

class _AnimatedActionButtonState
    extends State<_AnimatedActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? (widget.activeColor ?? widget.colors.brand)
        : widget.colors.textSecondary;

    final displayIcon =
        widget.active && widget.activeIcon != null
            ? widget.activeIcon!
            : widget.icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);

        HapticFeedback.selectionClick();

        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: widget.active
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionIconShell(
                active: widget.active,
                activeColor: color,
                colors: widget.colors,
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (
                    child,
                    animation,
                  ) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    displayIcon,
                    key: ValueKey(displayIcon),
                    size: 19,
                    color: color,
                  ),
                ),
              ),

              const SizedBox(width: 5),

              AnimatedDefaultTextStyle(
                duration: const Duration(
                  milliseconds: 180,
                ),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(
                  widget.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// UNIFIED ACTION ICON SHELL
// ============================================================

class _ActionIconShell extends StatelessWidget {
  final bool active;
  final Color activeColor;
  final WaynColors colors;
  final Widget child;

  const _ActionIconShell({
    required this.active,
    required this.activeColor,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.10)
            : colors.surfaceAlt.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}