import 'package:flutter/material.dart';

import '../../core/widgets/wayn_header.dart';
import '../../core/network/api_client.dart';
import '../../services/repositories/repository_factory.dart';
import 'community_page.dart';
import 'models/community_post.dart';
import 'services/community_service.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  late final CommunityService _communityService;
  final List<CommunityPost> _savedPosts = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService(createCommunityRepository());
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await _communityService.getSavedPosts(page: 1, limit: 50);

      if (!mounted) return;

      setState(() {
        _savedPosts
          ..clear()
          ..addAll(posts);
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
        _errorMessage = 'تعذر تحميل المحفوظات حاليًا';
      });
    }
  }

  Future<void> _unsavePost(CommunityPost post) async {
    try {
      await _communityService.unsavePost(post.id);

      if (!mounted) return;

      setState(() {
        _savedPosts.removeWhere((item) => item.id == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إزالة المنشور من المحفوظات',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر إلغاء الحفظ',
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
      child: DefaultTabController(
        length: 1, // Extensible to more tabs in future (e.g. Places, Products)
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                WaynHeader(
                  onMenuPressed: _onMenuOrNotificationsPressed,
                  onNotificationsPressed: _onMenuOrNotificationsPressed,
                ),
                const TabBar(
                  labelColor: Color(0xFF18A99A),
                  unselectedLabelColor: Color(0xFF8B94A3),
                  indicatorColor: Color(0xFF18A99A),
                  tabs: [
                    Tab(text: 'المنشورات'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPostsBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onMenuOrNotificationsPressed() {
    debugPrint('Saved posts menu/notifications pressed');
  }

  Widget _buildPostsBody() {
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
            Icon(Icons.bookmark_border_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadSavedPosts,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: const Color(0xFF18A99A).withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد منشورات محفوظة',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف منشورات إلى المحفوظات لرؤيتها هنا',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF18A99A),
      onRefresh: _loadSavedPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _savedPosts.length,
        itemBuilder: (context, index) {
          final post = _savedPosts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCardWidget(
              post: post,
              onLike: () {},
              onSave: () => _unsavePost(post),
              onComments: () {},
            ),
          );
        },
      ),
    );
  }
}
