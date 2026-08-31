import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../services/repositories/repository_factory.dart';
import 'models/community_post.dart';
import 'services/community_service.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final CommunityService _communityService;

  final List<CommunityPost> _posts = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _communityService = CommunityService(
      createCommunityRepository(),
    );

    _loadPosts();
  }

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
        _posts[index] = previous;
      });

      _showMessage('تعذر تحديث الإعجاب');
    }
  }

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
        _posts[index] = previous;
      });

      _showMessage('تعذر تحديث الحفظ');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  Future<void> _showCreatePostDialog() async {
    final textController = TextEditingController();

    String? selectedPlaceId;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'منشور جديد',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText:
                            'شارك تجربتك أو رأيك مع مجتمع وين...',
                        hintTextDirection:
                            TextDirection.rtl,
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        selectedPlaceId =
                            value.trim().isEmpty
                                ? null
                                : value.trim();
                      },
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'معرّف المكان',
                        hintText: 'Place ID',
                        filled: true,
                        fillColor:
                            const Color(0xFFF7F9FC),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final placeId =
                              selectedPlaceId?.trim();
                          final text =
                              textController.text.trim();

                          if (placeId == null ||
                              placeId.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'أدخل معرّف المكان',
                                ),
                              ),
                            );
                            return;
                          }

                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اكتب محتوى المنشور',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await _communityService
                                .createPost(
                              placeId: placeId,
                              text: text,
                            );

                            if (!context.mounted) return;

                            Navigator.pop(
                              context,
                              true,
                            );
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is ApiClientException
                                      ? e.message
                                      : 'تعذر إنشاء المنشور',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF18A99A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'نشر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    textController.dispose();

    if (result == true && mounted) {
      await _loadPosts(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'المجتمع',
            style: TextStyle(
              color: Color(0xFF172033),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => _loadPosts(refresh: true),
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreatePostDialog,
          backgroundColor: const Color(0xFF18A99A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'منشور',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

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
        onRefresh: () => _loadPosts(refresh: true),
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
                child: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF18A99A),
        onRefresh: () => _loadPosts(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            Icon(
              Icons.groups_rounded,
              size: 64,
              color: const Color(0xFF18A99A)
                  .withValues(alpha: 0.35),
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
      onRefresh: () => _loadPosts(refresh: true),
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
            padding: const EdgeInsets.only(bottom: 12),
            child: _CommunityPostCard(
              post: post,
              onLike: () => _toggleLike(post),
              onSave: () => _toggleSave(post),
              onComments: () {
                _showMessage(
                  'التعليقات سنربطها في الخطوة التالية',
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;

  const _CommunityPostCard({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18A99A)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF18A99A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مستخدم وين',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius:
                          BorderRadius.circular(12),
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
              ],
            ),
            if (post.text != null &&
                post.text!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                post.text!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
            if (post.imageUrl != null &&
                post.imageUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  post.imageUrl!,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return Container(
                      height: 210,
                      color: const Color(0xFFF1F3F6),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF8B94A3),
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              color: Color(0xFFEAECEF),
            ),
            const SizedBox(height: 8),
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
                    icon: Icons
                        .chat_bubble_outline_rounded,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: active
                  ? const Color(0xFF18A99A)
                  : const Color(0xFF667085),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF18A99A)
                    : const Color(0xFF667085),
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