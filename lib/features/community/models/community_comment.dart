class CommunityComment {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final String? authorName;
  final String? authorUsername;
  final String? authorAvatar;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    this.authorName,
    this.authorUsername,
    this.authorAvatar,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return CommunityComment(
      id: _stringValue(json['id']),
      postId: _stringValue(json['post_id']),
      userId: _stringValue(json['user_id']),
      text: _stringValue(json['text']),
      authorName: _nullableString(
        json['author_name'] ?? author['full_name'] ?? json['user_name'],
      ),
      authorUsername: _nullableString(
        json['author_username'] ?? author['username'] ?? json['username'],
      ),
      authorAvatar: _nullableString(
        json['author_avatar'] ?? author['avatar_id'] ?? json['avatar_id'],
      ),
      isVisible: _boolValue(json['is_visible']),
      createdAt: _dateTimeValue(json['created_at']),
      updatedAt: _dateTimeValue(json['updated_at']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }

  static DateTime _dateTimeValue(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}