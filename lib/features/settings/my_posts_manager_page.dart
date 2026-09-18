import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_network_image.dart';
import '../../services/repositories/repository_factory.dart';
import '../community/models/community_post.dart';
import '../community/repositories/community_repository.dart';

/// يفتح صفحة إدارة منشورات المستخدم (المحذوفة والمخفية) من الإعدادات.
void openMyPostsManager(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const MyPostsManagerPage(),
    ),
  );
}

/// إدارة منشورات المستخدم: المنشورات المحذوفة والمنشورات المخفية.
///
/// لكل منشور: معاينة، تاريخ الحذف/الإخفاء، استرجاع/إعادة إظهار،
/// وحذف نهائي مع تأكيد (العملية غير قابلة للتراجع).
class MyPostsManagerPage extends StatefulWidget {
  const MyPostsManagerPage({super.key});

  @override
  State<MyPostsManagerPage> createState() => _MyPostsManagerPageState();
}

class _MyPostsManagerPageState extends State<MyPostsManagerPage> {
  final CommunityRepository _repository = createCommunityRepository();

  List<CommunityPost> _posts = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load('DELETED');
  }

  // ============================================================
  // LOADING
  // ============================================================

  Future<void> _load(String state) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await _repository.getMyPostsByState(state: state);

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المنشورات';
      });
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  Future<void> _restore(CommunityPost post) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _repository.restorePost(post.id);

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      setState(() {
        _posts.removeWhere((item) => item.id == post.id);
        _busy = false;
      });

      _message('تم استرجاع المنشور بنجاح');
    } catch (_) {
      if (!mounted) return;

      setState(() => _busy = false);

      _message('تعذر استرجاع المنشور');
    }
  }

  Future<void> _permanentlyDelete(CommunityPost post) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = context.waynColors;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: Icon(
              Iconsax.danger,
              color: colors.danger,
              size: 30,
            ),
            title: const Text(
              'حذف نهائي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'سيتم حذف هذا المنشور نهائيًا ولا يمكن التراجع عن هذه العملية أبدًا. هل أنت متأكد؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                child: Text(
                  'حذف نهائي',
                  style: TextStyle(
                    color: colors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await _repository.permanentlyDeletePost(post.id);

      if (!mounted) return;

      HapticFeedback.heavyImpact();

      setState(() {
        _posts.removeWhere((item) => item.id == post.id);
        _busy = false;
      });

      _message('تم حذف المنشور نهائيًا');
    } catch (_) {
      if (!mounted) return;

      setState(() => _busy = false);

      _message('تعذر حذف المنشور نهائيًا');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                _header(colors),
                _tabs(colors),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF18A99A),
                          ),
                        )
                      : _error != null && _posts.isEmpty
                          ? _errorView(colors)
                          : _posts.isEmpty
                              ? _emptyView(colors)
                              : RefreshIndicator(
                                  color: colors.brand,
                                  onRefresh: () async {
                                    final index =
                                        DefaultTabController.of(context)
                                            .index;

                                    await _load(
                                      index == 0 ? 'DELETED' : 'HIDDEN',
                                    );
                                  },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      30,
                                    ),
                                    itemCount: _posts.length,
                                    itemBuilder: (context, index) =>
                                        _postCard(
                                      colors,
                                      _posts[index],
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

  Widget _header(WaynColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
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
                'منشوراتي',
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

  Widget _tabs(WaynColors colors) {
    return TabBar(
      onTap: (index) {
        _load(index == 0 ? 'DELETED' : 'HIDDEN');
      },
      labelColor: colors.brand,
      unselectedLabelColor: colors.textSecondary,
      indicatorColor: colors.brand,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      tabs: const [
        Tab(text: 'المنشورات المحذوفة'),
        Tab(text: 'المنشورات المخفية'),
      ],
    );
  }

  Widget _errorView(WaynColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.wifi_square,
            size: 52,
            color: colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? 'حدث خطأ',
            style: TextStyle(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final index = DefaultTabController.of(context).index;

              _load(index == 0 ? 'DELETED' : 'HIDDEN');
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(WaynColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.note_remove,
            size: 54,
            color: colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد منشورات هنا',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(WaynColors colors, CommunityPost post) {
    final isDeletedTab =
        post.visibilityState == 'DELETED' || post.deletedAt != null;

    final date = isDeletedTab ? post.deletedAt : post.hiddenAt;

    final dateLabel = date == null
        ? null
        : date.toLocal().toString().split('.').first;

    final details = <String>[
      if (post.placeName != null && post.placeName!.isNotEmpty)
        post.placeName!,
      if (post.rating != null) 'التقييم: ${post.rating}',
      if (dateLabel != null) dateLabel,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: post.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: WaynNetworkImage(
                          imageUrl: post.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Iconsax.note,
                        color: colors.textMuted,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.text?.isNotEmpty == true
                          ? post.text!
                          : 'منشور بصورة',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _restore(post),
                  icon: Icon(
                    Iconsax.refresh,
                    size: 17,
                    color: colors.brand,
                  ),
                  label: Text(
                    isDeletedTab ? 'استرجاع' : 'إعادة الإظهار',
                    style: TextStyle(
                      color: colors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.brand.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _permanentlyDelete(post),
                  icon: Icon(
                    Iconsax.trash,
                    size: 17,
                    color: colors.danger,
                  ),
                  label: Text(
                    'حذف نهائي',
                    style: TextStyle(
                      color: colors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.danger.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
