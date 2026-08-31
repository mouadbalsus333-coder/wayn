import 'package:flutter/material.dart';

import '../../core/config/backend_config.dart';
import '../../core/network/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/repository_factory.dart';
import '../../core/widgets/wayn_header.dart';
import 'create_post_page.dart';
import 'models/community_post.dart';
import 'services/community_service.dart';
import 'widgets/comments_sheet.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final CommunityService _communityService;
  final _authService = AuthService();

  final List<CommunityPost> _posts = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    _communityService = CommunityService(
      createCommunityRepository(),
    );

    _loadCurrentUser();
    _loadPosts();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();

    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  // ===========================================================================
  // LOAD POSTS
  // ===========================================================================

  Future<void> _loadPosts({
    bool refresh = false,
  }) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final posts = await _communityService.getPosts(
        page: 1,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        _posts
          ..clear()
          ..addAll(posts);

        _isLoading = false;
        _isRefreshing = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'تعذر تحميل المجتمع حاليًا';
      });
    }
  }

  // ===========================================================================
  // LIKE
  // ===========================================================================

  Future<void> _toggleLike(CommunityPost post) async {
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        resizeToAvoidBottomInset: false,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreatePostPage,
          backgroundColor: const Color(0xFF18A99A),
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'منشور',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuOrNotificationsPressed,
                onNotificationsPressed: _onMenuOrNotificationsPressed,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuOrNotificationsPressed() {
    debugPrint('Community menu/notifications pressed');
  }

  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF18A99A),
        ),
      );
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF18A99A),
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
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFF667085),
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
        color: const Color(0xFF18A99A),
        onRefresh: () => _loadPosts(
          refresh: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            Icon(
              Icons.groups_rounded,
              size: 64,
              color: const Color(0xFF18A99A).withValues(
                alpha: 0.35,
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'لا توجد منشورات حتى الآن',
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'كن أول من يشارك تجربته مع مجتمع وين',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF18A99A),
      onRefresh: () => _loadPosts(
        refresh: true,
      ),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          14,
          14,
          14,
          100,
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];

          return Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
            ),
            child: CommunityPostCardWidget(
              post: post,
              currentUserId: _currentUserId,
              onLike: () => _toggleLike(post),
              onSave: () => _toggleSave(post),
              onComments: () => _showComments(
                post,
                index,
              ),
              onDelete: () => _deletePost(post),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMMUNITY POST CARD WIDGET
// ============================================================================

class CommunityPostCardWidget extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;
  final VoidCallback? onDelete;
  final String? currentUserId;

  const CommunityPostCardWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onComments,
    this.onDelete,
    this.currentUserId,
  });

  // ===========================================================================
  // FULL IMAGE VIEWER
  // ===========================================================================

  void _openFullImage(
    BuildContext context,
    String imageUrl,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: 0.94,
      ),
      builder: (dialogContext) {
        return Scaffold(
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
                      loadingBuilder: (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

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
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 56,
                        );
                      },
                    ),
                  ),
                ),

                // -----------------------------------------------------------------
                // CLOSE
                // -----------------------------------------------------------------

                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.black.withValues(
                      alpha: 0.55,
                    ),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
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

                // -----------------------------------------------------------------
                // HINT
                // -----------------------------------------------------------------

                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        'اسحب للتنقل • قرّب بإصبعين للتكبير',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final authorName =
        post.authorName?.trim().isNotEmpty == true
        ? post.authorName!.trim()
        : 'مستخدم وين';

    final avatarLetter = authorName.isNotEmpty
        ? authorName.substring(0, 1)
        : 'و';

    final isOwner =
        currentUserId != null &&
        post.userId == currentUserId;

    // =========================================================================
    // IMAGE URL
    // =========================================================================

    final fullImageUrl =
        BackendConfig.resolveMediaUrl(
      post.imageUrl,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
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
            // =================================================================
            // USER HEADER
            // =================================================================

            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      const Color(0xFF18A99A).withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      color: Color(0xFF18A99A),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(post.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF8B94A3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.rating != null)
                  Container(
                    margin: const EdgeInsets.only(
                      left: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
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
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isOwner && onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF8B94A3),
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'حذف المنشور',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // =================================================================
            // TEXT
            // =================================================================

            if (post.text != null &&
                post.text!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExpandablePostText(
                text: post.text!,
              ),
            ],

            // =================================================================
            // IMAGE
            //
            // IMPORTANT:
            // No fixed height is used here.
            // Image.network preserves the original image aspect ratio.
            // =================================================================

            if (fullImageUrl != null &&
                fullImageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: const Color(0xFFF1F3F6),
                  child: InkWell(
                    onTap: () {
                      _openFullImage(
                        context,
                        fullImageUrl,
                      );
                    },
                    child: Image.network(
                      fullImageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

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
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
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

            const Divider(
              height: 1,
              color: Color(0xFFEAECEF),
            ),

            const SizedBox(height: 8),

            // =================================================================
            // ACTIONS
            // =================================================================

            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: post.likesCount.toString(),
                    active: post.isLiked,
                    onTap: onLike,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: post.commentsCount.toString(),
                    onTap: onComments,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: post.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: post.savesCount.toString(),
                    active: post.isSaved,
                    onTap: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }
}

// ============================================================================
// EXPANDABLE POST TEXT
// ============================================================================

class _ExpandablePostText extends StatefulWidget {
  final String text;

  const _ExpandablePostText({required this.text});

  @override
  State<_ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<_ExpandablePostText> {
  static const int _collapsedMaxLines = 4;
  static const String _moreLabel = 'قراءة المزيد';
  static const String _lessLabel = 'عرض أقل';
  static const Color _waynColor = Color(0xFF18A99A);

  bool _expanded = false;

  static const TextStyle _textStyle = TextStyle(
    color: Color(0xFF172033),
    fontSize: 15,
    height: 1.6,
  );

  static const TextStyle _linkStyle = TextStyle(
    color: _waynColor,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  @override
  void didUpdateWidget(covariant _ExpandablePostText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  bool _overflows(double maxWidth) {
    if (_expanded) return false;

    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: _textStyle,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: _expanded ? null : _collapsedMaxLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: _textStyle,
            ),
            if (overflows)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _expanded ? _lessLabel : _moreLabel,
                      textDirection: TextDirection.rtl,
                      style: _linkStyle,
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

// ============================================================================
// ACTION BUTTON
// ============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF18A99A)
        : const Color(0xFF667085);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
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