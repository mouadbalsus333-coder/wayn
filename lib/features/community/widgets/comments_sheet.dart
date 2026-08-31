import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../services/auth_service.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../services/community_service.dart';

class CommentsSheet extends StatefulWidget {
  final CommunityPost post;
  final CommunityService communityService;
  final Function(int newCount)? onCommentsCountChanged;

  const CommentsSheet({
    super.key,
    required this.post,
    required this.communityService,
    this.onCommentsCountChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  final List<CommunityComment> _comments = [];
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final comments = await widget.communityService.getComments(
        postId: widget.post.id,
      );

      if (!mounted) return;

      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
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
        _errorMessage = 'تعذر تحميل التعليقات حاليًا';
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final newComment = await widget.communityService.createComment(
        postId: widget.post.id,
        text: text,
      );

      if (!mounted) return;

      _commentController.clear();

      setState(() {
        _comments.add(newComment);
        _isSending = false;
      });

      widget.onCommentsCountChanged?.call(_comments.length);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiClientException ? e.message : 'تعذر إرسال التعليق',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف التعليق'),
          content: const Text('هل أنت أخصائي بتأكيد حذف هذا التعليق؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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
      await widget.communityService.deleteComment(comment.id);

      if (!mounted) return;

      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });

      widget.onCommentsCountChanged?.call(_comments.length);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiClientException ? e.message : 'تعذر حذف التعليق',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Drag indicator & Header
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF18A99A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'التعليقات (${_comments.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEAECEF)),

              // Comments List
              Expanded(
                child: _buildCommentsList(),
              ),

              const Divider(height: 1, color: Color(0xFFEAECEF)),

              // Comment Input
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        textDirection: TextDirection.rtl,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'اكتب تعليقًا...',
                          hintTextDirection: TextDirection.rtl,
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _submitComment,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF18A99A),
                        foregroundColor: Colors.white,
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF18A99A),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadComments,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد تعليقات بعد. كن أول من يعلّق!',
          style: TextStyle(
            color: Color(0xFF8B94A3),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _comments.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final authorName = comment.authorName ?? 'مستخدم وين';
        final isOwner = _currentUserId != null && comment.userId == _currentUserId;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF18A99A).withValues(alpha: 0.12),
              child: Text(
                authorName.isNotEmpty ? authorName.substring(0, 1) : 'و',
                style: const TextStyle(
                  color: Color(0xFF18A99A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF172033),
                          ),
                        ),
                        Text(
                          _formatDate(comment.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B94A3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF172033),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                onPressed: () => _deleteComment(comment),
              ),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
