/// إشعار مستخدم من Backend (`GET /notifications`).
class UserNotification {
  final String id;
  final String type;
  final String text;
  final String? actorName;
  final String? actorAvatar;
  final bool isRead;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.type,
    required this.text,
    this.actorName,
    this.actorAvatar,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotification.fromMap(Map<String, dynamic> m) {
    return UserNotification(
      id: m['id']?.toString() ?? '',
      type: m['type']?.toString() ?? 'GENERIC',
      text: m['text']?.toString() ?? '',
      actorName: m['actor_name']?.toString(),
      actorAvatar: m['actor_avatar']?.toString(),
      isRead: m['is_read'] == true,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
