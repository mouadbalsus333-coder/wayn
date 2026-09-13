/// إشعار مستخدم من Backend (`GET /notifications`).
class UserNotification {
  final String id;
  final String type;
  final String text;
  final String? actorName;
  final String? actorAvatar;
  final bool isRead;
  final DateTime createdAt;
  // --- Backward-compatible additions ---
  // مأخوذة من الرد الجديد للـ Backend. قد تكون غائبة في الردود
  // القديمة، لذلك كلها nullable مع قيم افتراضية آمنة.
  final String source;
  final Map<String, dynamic>? data;
  final DateTime? readAt;

  const UserNotification({
    required this.id,
    required this.type,
    required this.text,
    this.actorName,
    this.actorAvatar,
    required this.isRead,
    required this.createdAt,
    this.source = 'social',
    this.data,
    this.readAt,
  });

  /// هل الإشعار قادم من الـ Admin؟
  bool get isAdmin => source == 'admin';

  factory UserNotification.fromMap(Map<String, dynamic> m) {
    final rawData = m['data'];
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
      source: m['source']?.toString() ?? 'social',
      data: rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : null),
      readAt: m['read_at'] != null
          ? DateTime.tryParse(m['read_at'].toString())
          : null,
    );
  }
}
