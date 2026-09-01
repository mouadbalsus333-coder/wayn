import 'package:flutter/material.dart';

import '../../core/theme/wayn_colors.dart';
import '../../models/user_notification.dart';
import '../../services/social_service.dart';

/// يفتح صفحة الإشعارات (زر الجرس في الهيدر).
void openNotifications(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const NotificationsPage(),
    ),
  );
}

/// صفحة إشعارات المستخدم الحالي من Backend.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SocialService _socialService = SocialService();

  List<UserNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _socialService.getNotifications(limit: 100);

      if (!mounted) return;

      setState(() {
        _notifications = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الإشعارات';
      });
    }
  }

  Future<void> _markRead(UserNotification notification) async {
    if (notification.isRead) return;

    try {
      await _socialService.markNotificationRead(notification.id);

      if (!mounted) return;

      final index = _notifications.indexWhere(
        (item) => item.id == notification.id,
      );

      if (index == -1) return;

      setState(() {
        _notifications[index] = UserNotification(
          id: notification.id,
          type: notification.type,
          text: notification.text,
          actorName: notification.actorName,
          actorAvatar: notification.actorAvatar,
          isRead: true,
          createdAt: notification.createdAt,
        );
      });
    } catch (_) {
      // تجاهل فشل تعليم الإشعار كمقروء.
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
                    : _error != null && _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 54,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: colors.brand,
                            onRefresh: _load,
                            child: _notifications.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 140),
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 64,
                                        color: colors.brand.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: Text(
                                          'لا توجد إشعارات بعد',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    itemCount: _notifications.length,
                                    itemBuilder: (context, index) {
                                      return _NotificationTile(
                                        notification:
                                            _notifications[index],
                                        colors: colors,
                                        onTap: () => _markRead(
                                          _notifications[index],
                                        ),
                                      );
                                    },
                                  ),
                          ),
              ),
            ],
          ),
        ),
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
                'الإشعارات',
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
}

class _NotificationTile extends StatelessWidget {
  final UserNotification notification;
  final WaynColors colors;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.colors,
    required this.onTap,
  });

  static String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) {
      return 'الآن';
    }

    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }

    if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: notification.isRead
                  ? null
                  : Border.all(
                      color: colors.brand.withValues(alpha: 0.5),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    notification.type == 'FOLLOW'
                        ? Icons.person_add_alt_1_rounded
                        : Icons.notifications_none_rounded,
                    color: colors.brand,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeLabel(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colors.brand,
                      shape: BoxShape.circle,
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
