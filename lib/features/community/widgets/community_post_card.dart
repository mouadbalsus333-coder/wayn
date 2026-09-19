import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/navigation/wayn_actions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/wayn_colors.dart';
import '../../../core/utils/short_number.dart';
import '../../../core/widgets/wayn_network_image.dart';
import '../../../services/auth_service.dart';
import '../../../services/repositories/repository_factory.dart';
import '../../../services/social_service.dart';
import '../models/community_post.dart';
import '../services/community_service.dart';
import 'post_appeal_sheet.dart';
import 'post_report_sheet.dart';

// ============================================================
// SHARED ACCENTS
// ============================================================

const Color _kAmber = Color(0xFFF5A524);
const Color _kLikeColor = Color(0xFF18A99A);
const Color _kSaveColor = Color(0xFFF59E0B);
const Color _kCommentColor = Color(0xFF64748B);
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

  final Future<bool> Function(String comment)? onCommentSubmit;

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
    this.onCommentSubmit,
  });

  @override
  State<CommunityPostCard> createState() =>
      _CommunityPostCardState();
}

class _CommunityPostCardState
    extends State<CommunityPostCard> {
  final SocialService _socialService = SocialService();

  /// خدمة المجتمع المستخدمة لإرسال التعليق من الـ composer المدمج
  /// أسفل البطاقة عندما لا يمرّر الأب `onCommentSubmit`.
  final CommunityService _communityService =
      CommunityService(createCommunityRepository());

  late bool _isFollowing;
  late int _commentCount;

  bool _followBusy = false;
  bool _followSuccess = false;

  bool _isDeleting = false;
  bool _showCommentComposer = false;
  bool _showQuickActions = false;

  CommunityPost get post => widget.post;

  @override
  void initState() {
    super.initState();

    _isFollowing = post.isFollowingAuthor;
    _commentCount = post.commentsCount;
  }

  @override
  void didUpdateWidget(
    covariant CommunityPostCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.userId != widget.post.userId) {
      _isFollowing = widget.post.isFollowingAuthor;
      _commentCount = widget.post.commentsCount;
      _followBusy = false;
      _followSuccess = false;
      _isDeleting = false;
      _showCommentComposer = false;
      _showQuickActions = false;
      return;
    }

    if (oldWidget.post.isFollowingAuthor !=
        widget.post.isFollowingAuthor) {
      _isFollowing = widget.post.isFollowingAuthor;
    }

    if (oldWidget.post.commentsCount !=
        widget.post.commentsCount) {
      _commentCount = widget.post.commentsCount;
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================

  void _showMessage(
    String message, {
    Color? backgroundColor,
    IconData? icon,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
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
          content: Row(
            textDirection: TextDirection.rtl,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  message,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
  // QUICK ACTIONS
  // ============================================================

  void _toggleQuickActions() {
    HapticFeedback.selectionClick();

    setState(() {
      _showQuickActions = !_showQuickActions;
    });
  }

  void _closeQuickActions() {
    if (!_showQuickActions) {
      return;
    }

    setState(() {
      _showQuickActions = false;
    });
  }

  Widget _buildQuickActions(WaynColors colors) {
    if (!_showQuickActions) {
      return const SizedBox.shrink();
    }

    final actions = <_QuickActionData>[];

    if (post.isOwner) {
      if (widget.onDelete != null) {
        actions.add(
          _QuickActionData(
            value: 'delete',
            label: 'حذف',
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
        );
      }

      if (widget.onHide != null) {
        actions.add(
          _QuickActionData(
            value: 'hide',
            label: 'إخفاء',
            icon: Iconsax.eye_slash,
            color: colors.textSecondary,
          ),
        );
      }
    } else {
      if (post.rating != null) {
        actions.add(
          _QuickActionData(
            value: 'appeal',
            label: 'طعن',
            icon: Icons.gavel_rounded,
            color: const Color(0xFF7C3AED),
          ),
        );
      }

      actions.add(
        _QuickActionData(
          value: 'report',
          label: 'إبلاغ',
          icon: Icons.flag_outlined,
          color: Colors.redAccent,
        ),
      );

      if (widget.onHide != null) {
        actions.add(
          _QuickActionData(
            value: 'hide',
            label: 'إخفاء',
            icon: Iconsax.eye_slash,
            color: colors.textSecondary,
          ),
        );
      }
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 7,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              _QuickActionButton(
                key: ValueKey(
                  'quick-${actions[i].value}',
                ),
                action: actions[i],
                onTap: () {
                  _handleQuickAction(
                    actions[i].value,
                  );
                },
              ),
            ],
          ],
        )
            .animate(
              key: const ValueKey('quick-actions-animation'),
            )
            .fadeIn(
              duration: 180.ms,
              curve: Curves.easeOutCubic,
            )
            .slideY(
              begin: -0.35,
              end: 0,
              duration: 260.ms,
              curve: Curves.easeOutBack,
            )
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              duration: 260.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }

  void _handleQuickAction(String value) {
    _closeQuickActions();

    switch (value) {
      case 'delete':
        _handleDelete();
        break;

      case 'hide':
        _hidePost();
        break;

      case 'appeal':
        HapticFeedback.selectionClick();
        showPostAppealSheet(
          context,
          post.id,
        );
        break;

      case 'report':
        HapticFeedback.selectionClick();
        showPostReportSheet(
          context,
          post.id,
        );
        break;
    }
  }

  // ============================================================
  // OPTIONS BUTTON
  // ============================================================

  Widget _buildOptionsMenu(WaynColors colors) {
    return _OptionsButton(
      colors: colors,
      active: _showQuickActions,
      onTap: _toggleQuickActions,
    );
  }

  // ============================================================
  // HIDE
  // ============================================================

  void _hidePost() {
    if (_isDeleting) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isDeleting = true;
      _showCommentComposer = false;
      _showQuickActions = false;
    });

    widget.onHide?.call();

    _showMessage(
      post.isOwner
          ? 'تم إخفاء المنشور — يمكنك استرداده من الإعدادات'
          : 'تم إخفاء المنشور عنك',
      backgroundColor: _kSuccessColor,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  void _handleDelete() {
    if (_isDeleting || widget.onDelete == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isDeleting = true;
      _showCommentComposer = false;
      _showQuickActions = false;
    });

    widget.onDelete?.call();

    _showMessage(
      'تم حذف المنشور. يمكنك استرداده من الإعدادات',
      backgroundColor: _kSuccessColor,
      icon: Iconsax.trash,
    );
  }

  // ============================================================
  // SWIPE DELETE
  // ============================================================

  Future<bool> _confirmSwipeDelete(
    DismissDirection direction,
  ) async {
    if (_isDeleting || widget.onDelete == null) {
      return false;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isDeleting = true;
      _showCommentComposer = false;
      _showQuickActions = false;
    });

    return true;
  }

  void _handleSwipeDeleted() {
    if (widget.onDelete == null) {
      return;
    }

    HapticFeedback.heavyImpact();

    widget.onDelete?.call();

    _showMessage(
      'تم حذف المنشور. يمكنك استرداده من الإعدادات',
      backgroundColor: _kSuccessColor,
      icon: Iconsax.trash,
    );
  }

  Widget _buildSwipeBackground(WaynColors colors) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(
                    alpha: 0.24,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.trash,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'حذف',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableCard({
    required BuildContext context,
    required WaynColors colors,
    required Widget child,
  }) {
    if (widget.onDelete == null) {
      return child;
    }

    return Dismissible(
      key: ValueKey(
        'community-post-${post.id}',
      ),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.30,
      },
      movementDuration: const Duration(
        milliseconds: 330,
      ),
      resizeDuration: const Duration(
        milliseconds: 380,
      ),
      confirmDismiss: _confirmSwipeDelete,
      background: _buildSwipeBackground(colors),
      onDismissed: (_) {
        _handleSwipeDeleted();
      },
      child: child,
    );
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  Future<void> _toggleFollow() async {
    if (_followBusy) {
      return;
    }

    HapticFeedback.selectionClick();

    try {
      final user =
          await AuthService().getCurrentUser();

      if (!mounted) {
        return;
      }

      if (user == null) {
        _promptLogin();
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _promptLogin();
      return;
    }

    setState(() {
      _followBusy = true;
      _followSuccess = false;
    });

    try {
      if (_isFollowing) {
        await _socialService.unfollow(
          post.userId,
        );

        if (!mounted) {
          return;
        }

        HapticFeedback.lightImpact();

        setState(() {
          _isFollowing = false;
          _followBusy = false;
          _followSuccess = false;
        });

        _showMessage(
          'تم إلغاء المتابعة',
          backgroundColor:
              colorsForMessage(context),
          icon: Icons.person_remove_outlined,
        );
      } else {
        await _socialService.follow(
          post.userId,
        );

        if (!mounted) {
          return;
        }

        HapticFeedback.mediumImpact();

        setState(() {
          _isFollowing = true;
          _followSuccess = true;
        });

        _showMessage(
          'تمت متابعة المستخدم',
          backgroundColor: _kSuccessColor,
          icon: Icons.check_circle_outline_rounded,
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _followBusy = false;
          _followSuccess = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _followBusy = false;
        _followSuccess = false;
      });

      HapticFeedback.heavyImpact();

      _showMessage(
        'تعذر تنفيذ المتابعة',
        backgroundColor: Colors.redAccent,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  // ============================================================
  // COMMENT COMPOSER
  // ============================================================

  void _toggleCommentComposer() {
    HapticFeedback.selectionClick();

    setState(() {
      _showCommentComposer =
          !_showCommentComposer;
    });
  }

  void _openComments() {
    if (widget.onComments == null) {
      return;
    }

    HapticFeedback.selectionClick();
    widget.onComments!.call();
  }

  // ============================================================
  // SUBMIT COMMENT
  // ============================================================

  /// الإرسال الافتراضي للتعليق من الـ composer المدمج في البطاقة.
  ///
  /// يُستخدم فقط عندما لا يمرّر الأب `onCommentSubmit`.
  /// يعيد `true` فقط عندما ينجح الطلب فعليًا في الـ backend،
  /// وإلا يعيد `false` بعد تسجيل الخطأ الحقيقي في debug console.
  Future<bool> _submitComment(
    String comment,
  ) async {
    try {
      final created =
          await _communityService.createComment(
        postId: post.id,
        text: comment,
      );

      debugPrint(
        'COMMUNITY DEBUG: CREATE COMMENT OK '
        'postId=${post.id} '
        'commentId=${created.id}',
      );

      return true;
    } on ApiClientException catch (e) {
      debugPrint(
        'COMMUNITY DEBUG: CREATE COMMENT FAILED '
        'postId=${post.id} '
        'status=${e.statusCode} '
        'message=${e.message}',
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint(
        'COMMUNITY DEBUG: CREATE COMMENT EXCEPTION '
        'postId=${post.id} error=$e',
      );

      debugPrint(
        'COMMUNITY DEBUG: STACK TRACE\n$stackTrace',
      );

      return false;
    }
  }

  Widget _buildCommentComposer(
    WaynColors colors,
  ) {
    return _CommentComposer(
      colors: colors,
      visible: _showCommentComposer,
      onSubmit: widget.onCommentSubmit ??
          _submitComment,
      onSuccess: () {
        if (mounted) {
          setState(() {
            _commentCount++;
          });
        }

        _showMessage(
          'تم إرسال التعليق بنجاح',
          backgroundColor: _kSuccessColor,
          icon: Icons.check_circle_outline_rounded,
        );
      },
      onFailure: () {
        _showMessage(
          'تعذر إرسال التعليق',
          backgroundColor: Colors.redAccent,
          icon: Icons.error_outline_rounded,
        );
      },
    );
  }

  Widget _buildCommentsButton(
    WaynColors colors,
  ) {
    if (widget.onComments == null ||
        _commentCount <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 2,
        bottom: 2,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openComments,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(
              alpha: 0.52,
            ),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.mode_comment_outlined,
                size: 15,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'عرض التعليقات',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 180,
                ),
                child: Text(
                  '(${formatCount(_commentCount)})',
                  key: ValueKey(_commentCount),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10.5,
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

  // ============================================================
  // LIKE
  // ============================================================

  Future<bool> _handleLike(
    bool isLiked,
  ) async {
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
      barrierColor:
          Colors.black.withValues(alpha: 0.94),
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
                      if (progress == null) {
                        return child;
                      }

                      return const SizedBox(
                        width: 48,
                        height: 48,
                        child:
                            CircularProgressIndicator(
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
                  onTap: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
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

    final avatarLetter =
        authorName.isNotEmpty
            ? authorName.substring(0, 1)
            : 'و';

    final fullImageUrl =
        BackendConfig.resolveMediaUrl(
      post.imageUrl,
    );

    final card = _buildCard(
      context: context,
      colors: colors,
      authorName: authorName,
      placeName: placeName,
      placeCity: placeCity,
      avatarLetter: avatarLetter,
      fullImageUrl: fullImageUrl,
    );

    final swipeableCard = _buildSwipeableCard(
      context: context,
      colors: colors,
      child: card,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildQuickActions(colors),

        AnimatedSize(
          duration: const Duration(
            milliseconds: 430,
          ),
          reverseDuration:
              const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubicEmphasized,
          alignment: Alignment.topCenter,
          child: _isDeleting
              ? const SizedBox.shrink()
              : swipeableCard,
        ),

        _buildCommentsButton(colors),

        _buildCommentComposer(colors),
      ],
    )
        .animate()
        .fadeIn(
          duration: const Duration(
            milliseconds: 280,
          ),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.012,
          end: 0,
          duration: const Duration(
            milliseconds: 330,
          ),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildCard({
    required BuildContext context,
    required WaynColors colors,
    required String authorName,
    required String placeName,
    required String? placeCity,
    required String avatarLetter,
    required String? fullImageUrl,
  }) {
    return Transform.scale(
      scale: _isDeleting ? 0.965 : 1,
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        offset: _isDeleting
            ? const Offset(0.045, -0.012)
            : Offset.zero,
        duration: const Duration(
          milliseconds: 390,
        ),
        curve: Curves.easeInCubic,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(22),
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
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                _buildRatingAndPlaceSection(
                  colors,
                  placeName,
                ),

                const SizedBox(height: 10),

                Divider(
                  height: 1,
                  color: colors.divider
                      .withValues(alpha: 0.7),
                ),

                const SizedBox(height: 11),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    _AvatarButton(
                      letter: avatarLetter,
                      colors: colors,
                      onTap:
                          widget.onAuthorTap == null
                              ? null
                              : () {
                                  widget.onAuthorTap!(
                                    post.userId,
                                  );
                                },
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: InkWell(
                        onTap:
                            widget.onAuthorTap ==
                                    null
                                ? null
                                : () {
                                    widget
                                        .onAuthorTap!(
                                      post.userId,
                                    );
                                  },
                        borderRadius:
                            BorderRadius.circular(8),
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 2,
                          ),
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                authorName,
                                textDirection:
                                    TextDirection.rtl,
                                style: TextStyle(
                                  color:
                                      colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                textDirection:
                                    TextDirection.rtl,
                                children: [
                                  Text(
                                    _formatPostTime(
                                      post.createdAt,
                                    ),
                                    textDirection:
                                        TextDirection.rtl,
                                    style: TextStyle(
                                      color:
                                          colors.textMuted,
                                      fontSize: 9.5,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                  if (placeCity != null) ...[
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    Text(
                                      '•',
                                      style:
                                          TextStyle(
                                        color:
                                            colors.textMuted,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    Flexible(
                                      child: Text(
                                        placeCity,
                                        textDirection:
                                            TextDirection
                                                .rtl,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: TextStyle(
                                          color:
                                              colors.textMuted,
                                          fontSize: 9.5,
                                          fontWeight:
                                              FontWeight
                                                  .w500,
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
                        isFollowing:
                            _isFollowing,
                        busy: _followBusy,
                        success:
                            _followSuccess,
                        onPressed:
                            _toggleFollow,
                        colors: colors,
                      ),
                  ],
                ),

                if (post.text != null &&
                    post.text!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ExpandablePostText(
                    text: post.text!,
                  ),
                ],

                if (fullImageUrl != null &&
                    fullImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(18),
                    child: Material(
                      color: colors.surfaceAlt,
                      child: InkWell(
                        onTap: () {
                          _openFullImage(
                            context,
                            fullImageUrl,
                          );
                        },
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
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      colors.brand,
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
                                  Iconsax
                                      .gallery_slash,
                                  color:
                                      colors.textMuted,
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
                  color: colors.divider
                      .withValues(alpha: 0.7),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Expanded(
                      child:
                          _LikeActionButton(
                        isLiked: post.isLiked,
                        likeCount:
                            post.likesCount,
                        colors: colors,
                        onTap: _handleLike,
                      ),
                    ),

                    Expanded(
                      child:
                          _AnimatedActionButton(
                        icon: Icons
                            .mode_comment_outlined,
                        activeIcon: Icons
                            .mode_comment_rounded,
                        label: formatCount(
                          _commentCount,
                        ),
                        active:
                            _showCommentComposer,
                        activeColor:
                            _kCommentColor,
                        colors: colors,
                        onTap:
                            _toggleCommentComposer,
                      ),
                    ),

                    Expanded(
                      child:
                          _AnimatedActionButton(
                        icon: Icons
                            .bookmark_outline_rounded,
                        activeIcon:
                            Icons.bookmark_rounded,
                        label: formatCount(
                          post.savesCount,
                        ),
                        active: post.isSaved,
                        activeColor:
                            _kSaveColor,
                        colors: colors,
                        onTap: () {
                          HapticFeedback
                              .lightImpact();
                          widget.onSave?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatPostTime(
    DateTime dateTime,
  ) {
    final localTime = dateTime.toLocal();

    final hour = localTime.hour;
    final minute = localTime.minute;

    final period =
        hour < 12 ? 'صباحا' : 'مساء';

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
  // RATING + PLACE + MORE
  // ============================================================

  Widget _buildRatingAndPlaceSection(
    WaynColors colors,
    String placeName,
  ) {
    return SizedBox(
      height: 31,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          if (post.rating != null)
            _CompactRatingBadge(
              rating: post.rating!,
              colors: colors,
            ),

          if (post.rating != null)
            const SizedBox(width: 7),

          Expanded(
            child: _PlaceButton(
              placeName: placeName,
              colors: colors,
              onTap:
                  widget.onPlaceTap == null
                      ? null
                      : () {
                          HapticFeedback
                              .selectionClick();

                          widget.onPlaceTap!(
                            post.placeId,
                          );
                        },
            ),
          ),

          const SizedBox(width: 5),

          _buildOptionsMenu(colors),
        ],
      ),
    );
  }
}

// ============================================================
// MESSAGE COLOR
// ============================================================

Color colorsForMessage(
  BuildContext context,
) {
  final colors = context.waynColors;
  return colors.surface;
}

// ============================================================
// QUICK ACTION DATA
// ============================================================

class _QuickActionData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _QuickActionData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

// ============================================================
// QUICK ACTION BUTTON
// ============================================================

class _QuickActionButton extends StatefulWidget {
  final _QuickActionData action;
  final VoidCallback onTap;

  const _QuickActionButton({
    super.key,
    required this.action,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() =>
      _QuickActionButtonState();
}

class _QuickActionButtonState
    extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1,
        duration:
            const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: widget.action.color
                .withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: widget.action.color
                  .withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.action.color
                    .withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection:
                TextDirection.rtl,
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: widget.action.color
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.action.icon,
                  color: widget.action.color,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.action.label,
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  color: widget.action.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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
// THREE DOTS / OPTIONS BUTTON
// ============================================================

class _OptionsButton extends StatefulWidget {
  final WaynColors colors;
  final bool active;
  final VoidCallback onTap;

  const _OptionsButton({
    required this.colors,
    required this.active,
    required this.onTap,
  });

  @override
  State<_OptionsButton> createState() =>
      _OptionsButtonState();
}

class _OptionsButtonState
    extends State<_OptionsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 230),
    );
  }

  @override
  void didUpdateWidget(
    covariant _OptionsButton oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (
          context,
          child,
        ) {
          final value =
              Curves.easeOutBack.transform(
            _controller.value,
          );

          return Transform.scale(
            scale: 1 - (value * 0.07),
            child: Transform.rotate(
              angle: value * 0.16,
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: widget.active
                ? widget.colors.brand
                    .withValues(alpha: 0.11)
                : widget.colors.surfaceAlt
                    .withValues(alpha: 0.62),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 180),
            transitionBuilder: (
              child,
              animation,
            ) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              widget.active
                  ? Icons.close_rounded
                  : Icons.more_horiz_rounded,
              key: ValueKey(widget.active),
              color: widget.colors.textSecondary,
              size: 20,
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
  State<_PlaceButton> createState() =>
      _PlaceButtonState();
}

class _PlaceButtonState
    extends State<_PlaceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration:
            const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: widget.colors.brand
                .withValues(
              alpha: _pressed ? 0.13 : 0.07,
            ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.location,
                size: 14,
                color: widget.colors.brand,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  widget.placeName,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color:
                        widget.colors.brand,
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w700,
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
  State<_AvatarButton> createState() =>
      _AvatarButtonState();
}

class _AvatarButtonState
    extends State<_AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        if (widget.onTap != null) {
          HapticFeedback.selectionClick();
          widget.onTap!();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration:
            const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: CircleAvatar(
          radius: 18,
          backgroundColor:
              widget.colors.brand.withValues(
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

class _ImageCloseButton
    extends StatefulWidget {
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
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1,
        duration:
            const Duration(milliseconds: 120),
        child: Material(
          color: Colors.black.withValues(
            alpha: 0.55,
          ),
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

class _AuthorPointsChip
    extends StatelessWidget {
  final int points;
  final WaynColors colors;

  const _AuthorPointsChip({
    required this.points,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius:
            BorderRadius.circular(10),
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

class _FollowButton
    extends StatelessWidget {
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

    final foregroundColor =
        isFollowing && !success
            ? colors.brand
            : colors.onBrand;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onPressed,
      child: AnimatedScale(
        scale: busy ? 0.95 : 1,
        duration:
            const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: 31,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
                BorderRadius.circular(10),
            border:
                isFollowing && !success
                    ? Border.all(
                        color: colors.brand
                            .withValues(
                          alpha: 0.30,
                        ),
                      )
                    : null,
            boxShadow: success
                ? [
                    BoxShadow(
                      color: colors.brand
                          .withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset:
                          const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 260),
              switchInCurve:
                  Curves.easeOutBack,
              switchOutCurve:
                  Curves.easeIn,
              transitionBuilder: (
                child,
                animation,
              ) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: success
                  ? Row(
                      key: const ValueKey(
                        'follow-success',
                      ),
                      mainAxisSize:
                          MainAxisSize.min,
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
                            fontWeight:
                                FontWeight.w800,
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
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                foregroundColor,
                          ),
                        )
                      : Row(
                          key: ValueKey(
                            isFollowing
                                ? 'following'
                                : 'follow',
                          ),
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing
                                  ? Iconsax
                                      .tick_circle
                                  : Iconsax.user_add,
                              color:
                                  foregroundColor,
                              size: 14,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              isFollowing
                                  ? 'متابَع'
                                  : 'متابعة',
                              style: TextStyle(
                                color:
                                    foregroundColor,
                                fontSize: 10.5,
                                fontWeight:
                                    FontWeight.w800,
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
// COMPACT RATING
// ============================================================

class _CompactRatingBadge
    extends StatelessWidget {
  final double rating;
  final WaynColors colors;

  const _CompactRatingBadge({
    required this.rating,
    required this.colors,
  });

  double get _rating {
    return rating.clamp(0.0, 5.0).toDouble();
  }

  String get _ratingText {
    final value = _rating;

    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'التقييم $_ratingText من 5',
      child: Container(
        height: 30,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: _kAmber.withValues(
            alpha: 0.10,
          ),
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 17,
              color: _kAmber,
            ),
            const SizedBox(width: 4),
            Text(
              _ratingText,
              textDirection:
                  TextDirection.ltr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EXPANDABLE POST TEXT
// ============================================================

class _ExpandablePostText
    extends StatefulWidget {
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
    if (_expanded) {
      return false;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: style,
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      maxLines: _collapsedMaxLines,
      ellipsis: '…',
    )..layout(
        maxWidth: maxWidth,
      );

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
      builder: (
        context,
        constraints,
      ) {
        final overflows = _overflows(
          constraints.maxWidth,
          textStyle,
        );

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration:
                  const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Text(
                widget.text,
                textAlign: TextAlign.right,
                textDirection:
                    TextDirection.rtl,
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
                  HapticFeedback
                      .selectionClick();

                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                behavior:
                    HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Align(
                    alignment:
                        Alignment.centerRight,
                    child:
                        AnimatedDefaultTextStyle(
                      duration:
                          const Duration(
                        milliseconds: 180,
                      ),
                      style: linkStyle,
                      child: Text(
                        _expanded
                            ? 'عرض أقل'
                            : 'قراءة المزيد',
                        textDirection:
                            TextDirection.rtl,
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

class _LikeActionButton
    extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final WaynColors colors;
  final Future<bool?> Function(
    bool isLiked,
  ) onTap;

  const _LikeActionButton({
    required this.isLiked,
    required this.likeCount,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_LikeActionButton> createState() =>
      _LikeActionButtonState();
}

class _LikeActionButtonState
    extends State<_LikeActionButton>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;

  bool _pressed = false;
  bool _busy = false;

  late final AnimationController
      _likeController;

  @override
  void initState() {
    super.initState();

    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;

    _likeController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(
    covariant _LikeActionButton oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLiked !=
        widget.isLiked) {
      _isLiked = widget.isLiked;
    }

    if (oldWidget.likeCount !=
        widget.likeCount) {
      _likeCount = widget.likeCount;
    }
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _pressed = false;
    });

    HapticFeedback.lightImpact();

    final oldLiked = _isLiked;

    try {
      final result =
          await widget.onTap(oldLiked);

      if (!mounted) {
        return;
      }

      final newLiked =
          result ?? !oldLiked;

      setState(() {
        _isLiked = newLiked;

        if (newLiked && !oldLiked) {
          _likeCount++;
        } else if (!newLiked &&
            oldLiked) {
          _likeCount =
              _likeCount > 0
                  ? _likeCount - 1
                  : 0;
        }
      });

      if (newLiked && !oldLiked) {
        HapticFeedback.mediumImpact();

        _likeController
          ..reset()
          ..forward();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    final color = _isLiked
        ? _kLikeColor
        : colors.textSecondary;

    final icon = _isLiked
        ? Icons.thumb_up_rounded
        : Icons.thumb_up_outlined;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!_busy) {
          setState(() {
            _pressed = true;
          });
        }
      },
      onTapCancel: () {
        if (mounted) {
          setState(() {
            _pressed = false;
          });
        }
      },
      onTap: () {
        if (!_busy) {
          _handleTap();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1,
        duration:
            const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          margin:
              const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: _isLiked
                ? color.withValues(
                    alpha: 0.055,
                  )
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _likeController,
                builder: (
                  context,
                  child,
                ) {
                  final curved =
                      Curves.easeOutBack
                          .transform(
                    _likeController.value,
                  );

                  final scale = _isLiked
                      ? 1.0 +
                          (0.13 * curved)
                      : 1.0;

                  final rotation = _isLiked
                      ? -0.04 * curved
                      : 0.0;

                  return Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: _ActionIconShell(
                        active: _isLiked,
                        activeColor:
                            _kLikeColor,
                        colors: colors,
                        child:
                            AnimatedSwitcher(
                          duration:
                              const Duration(
                            milliseconds: 190,
                          ),
                          switchInCurve:
                              Curves.easeOutBack,
                          switchOutCurve:
                              Curves.easeIn,
                          transitionBuilder:
                              (
                            child,
                            animation,
                          ) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            icon,
                            key: ValueKey(icon),
                            size: 18,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),
                transitionBuilder: (
                  child,
                  animation,
                ) {
                  final curved =
                      CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );

                  return ClipRect(
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                        begin:
                            const Offset(
                          0,
                          0.25,
                        ),
                        end: Offset.zero,
                      ).animate(curved),
                      child: ScaleTransition(
                        scale:
                            Tween<double>(
                          begin: 0.90,
                          end: 1,
                        ).animate(curved),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Text(
                  formatCount(_likeCount),
                  key: ValueKey(_likeCount),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
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
// UNIFIED ACTION BUTTON
// ============================================================

class _AnimatedActionButton
    extends StatefulWidget {
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
    extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController
      _tapController;

  @override
  void initState() {
    super.initState();

    _tapController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _trigger() {
    _tapController
      ..reset()
      ..forward();

    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? (widget.activeColor ??
            widget.colors.brand)
        : widget.colors.textSecondary;

    final displayIcon =
        widget.active &&
                widget.activeIcon != null
            ? widget.activeIcon!
            : widget.icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        _trigger();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1,
        duration:
            const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin:
              const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: widget.active
                ? color.withValues(
                    alpha: 0.055,
                  )
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _tapController,
                builder: (
                  context,
                  child,
                ) {
                  final value =
                      Curves.easeOutBack
                          .transform(
                    _tapController.value,
                  );

                  return Transform.scale(
                    scale:
                        1.0 + (0.08 * value),
                    child:
                        _ActionIconShell(
                      active:
                          widget.active,
                      activeColor: color,
                      colors:
                          widget.colors,
                      child:
                          AnimatedSwitcher(
                        duration:
                            const Duration(
                          milliseconds: 190,
                        ),
                        switchInCurve:
                            Curves.easeOutBack,
                        switchOutCurve:
                            Curves.easeIn,
                        transitionBuilder:
                            (
                          child,
                          animation,
                        ) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Icon(
                          displayIcon,
                          key: ValueKey(
                            displayIcon,
                          ),
                          size: 18,
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),
                curve:
                    Curves.easeOutCubic,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
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

class _ActionIconShell
    extends StatelessWidget {
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
      duration:
          const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(
                alpha: 0.10,
              )
            : colors.surfaceAlt.withValues(
                alpha: 0.55,
              ),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

// ============================================================
// COMMENT COMPOSER
// ============================================================

class _CommentComposer
    extends StatefulWidget {
  final WaynColors colors;
  final bool visible;
  final Future<bool> Function(
    String comment,
  )? onSubmit;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const _CommentComposer({
    required this.colors,
    required this.visible,
    required this.onSubmit,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<_CommentComposer> createState() =>
      _CommentComposerState();
}

class _CommentComposerState
    extends State<_CommentComposer>
    with SingleTickerProviderStateMixin {
  late final TextEditingController
      _controller;

  late final FocusNode _focusNode;

  late final AnimationController
      _sendController;

  bool _sending = false;
  bool _pressed = false;
  bool _sendSuccess = false;

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController();

    _focusNode = FocusNode();

    _sendController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(
    covariant _CommentComposer oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.visible &&
        !oldWidget.visible) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _focusNode.requestFocus();
      });
    }

    if (!widget.visible &&
        oldWidget.visible) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sendController.dispose();
    super.dispose();
  }

  bool get _hasText =>
      _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_sending ||
        _sendSuccess ||
        !_hasText) {
      return;
    }

    final callback = widget.onSubmit;

    if (callback == null) {
      debugPrint(
        'COMMUNITY DEBUG: COMMENT SUBMIT HAS NO HANDLER',
      );

      widget.onFailure();
      return;
    }

    final comment =
        _controller.text.trim();

    FocusManager.instance.primaryFocus
        ?.unfocus();

    HapticFeedback.mediumImpact();

    setState(() {
      _sending = true;
      _pressed = false;
    });

    _sendController
      ..reset()
      ..forward();

    try {
      final success =
          await callback(comment);

      if (!mounted) {
        return;
      }

      if (success) {
        _controller.clear();

        setState(() {
          _sending = false;
          _sendSuccess = true;
        });

        HapticFeedback.mediumImpact();
        widget.onSuccess();

        await Future<void>.delayed(
          const Duration(milliseconds: 650),
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _sendSuccess = false;
        });
      } else {
        setState(() {
          _sending = false;
          _sendSuccess = false;
        });

        HapticFeedback.heavyImpact();
        widget.onFailure();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _sendSuccess = false;
      });

      HapticFeedback.heavyImpact();
      widget.onFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration:
          const Duration(milliseconds: 390),
      reverseDuration:
          const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubicEmphasized,
      alignment: Alignment.topCenter,
      child: widget.visible
          ? Padding(
              padding:
                  const EdgeInsets.only(
                top: 8,
                bottom: 4,
              ),
              child:
                  _buildVisibleComposer(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildVisibleComposer() {
    final colors = widget.colors;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ),
      duration:
          const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (
        context,
        value,
        child,
      ) {
        return Transform.translate(
          offset: Offset(
            0,
            (1 - value) * -10,
          ),
          child: Transform.scale(
            scale: 0.97 + (value * 0.03),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          8,
          8,
          8,
          8,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: colors.divider.withValues(
              alpha: 0.75,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(
                alpha: 0.08,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            _buildSendButton(colors),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceAlt
                      .withValues(alpha: 0.72),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_sending &&
                      !_sendSuccess,
                  maxLines: 4,
                  minLines: 1,
                  textDirection:
                      TextDirection.rtl,
                  textAlign: TextAlign.right,
                  textInputAction:
                      TextInputAction.newline,
                  style: TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                    height: 1.45,
                  ),
                  cursorColor:
                      colors.brand,
                  onChanged: (_) {
                    if (!mounted) {
                      return;
                    }

                    setState(() {});
                  },
                  decoration:
                      InputDecoration(
                    hintText:
                        'اكتب تعليقك...',
                    hintTextDirection:
                        TextDirection.rtl,
                    hintStyle: TextStyle(
                      color:
                          colors.textMuted,
                      fontSize: 12.5,
                      fontWeight:
                          FontWeight.w500,
                    ),
                    border:
                        InputBorder.none,
                    enabledBorder:
                        InputBorder.none,
                    focusedBorder:
                        InputBorder.none,
                    disabledBorder:
                        InputBorder.none,
                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(
    WaynColors colors,
  ) {
    final enabled =
        _hasText &&
        !_sending &&
        !_sendSuccess;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              if (!mounted) {
                return;
              }

              setState(() {
                _pressed = true;
              });
            }
          : null,
      onTapCancel: enabled
          ? () {
              if (!mounted) {
                return;
              }

              setState(() {
                _pressed = false;
              });
            }
          : null,
      onTap: enabled
          ? () {
              if (!mounted) {
                return;
              }

              setState(() {
                _pressed = false;
              });

              _submit();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1,
        duration:
            const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _pressed
              ? const Offset(0, 0.025)
              : Offset.zero,
          duration:
              const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: enabled
                ? colors.brand
                : colors.surfaceAlt,
            borderRadius:
                BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.brand
                          .withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 12,
                      offset:
                          const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 220),
            switchInCurve:
                Curves.easeOutBack,
            switchOutCurve:
                Curves.easeIn,
            transitionBuilder: (
              child,
              animation,
            ) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: _sendSuccess
                ? const Icon(
                    Iconsax.tick_circle,
                    key: ValueKey(
                      'send-success',
                    ),
                    color: Colors.white,
                    size: 20,
                  )
                : _sending
                    ? const SizedBox(
                        key: ValueKey(
                          'send-loading',
                        ),
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : TweenAnimationBuilder<double>(
                        key: const ValueKey(
                          'send-icon',
                        ),
                        tween: Tween<double>(
                          begin: 0,
                          end: _pressed ? -0.10 : 0,
                        ),
                        duration: const Duration(
                          milliseconds: 140,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (
                          context,
                          angle,
                          child,
                        ) {
                          return Transform.rotate(
                            angle: angle,
                            child: child,
                          );
                        },
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: enabled
                              ? colors.onBrand
                              : colors.textMuted,
                          size: 21,
                        ),
                      ),
          ),
        ),
      ),
    ),
  );
  }
}
