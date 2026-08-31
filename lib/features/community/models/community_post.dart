class CommunityPost {
  final String id;
  final String userId;
  final String placeId;

  final String? text;
  final String? imageUrl;
  final double? rating;

  final String? authorName;
  final String? authorUsername;
  final String? authorAvatar;
  final String? placeName;

  final bool isVisible;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int likesCount;
  final int savesCount;
  final int commentsCount;

  final bool isLiked;
  final bool isSaved;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.placeId,
    this.text,
    this.imageUrl,
    this.rating,
    this.authorName,
    this.authorUsername,
    this.authorAvatar,
    this.placeName,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.savesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory CommunityPost.fromJson(
    Map<String, dynamic> json,
  ) {
    final state = json['state'] is Map
        ? Map<String, dynamic>.from(
            json['state'] as Map,
          )
        : <String, dynamic>{};

    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return CommunityPost(
      id: _stringValue(json['id']),
      userId: _stringValue(json['user_id']),
      placeId: _stringValue(json['place_id']),
      text: _nullableString(json['text']),
      imageUrl: _nullableString(json['image_url']),
      rating: _nullableDouble(json['rating']),
      authorName: _nullableString(
        json['author_name'] ?? author['full_name'] ?? json['user_name'],
      ),
      authorUsername: _nullableString(
        json['author_username'] ?? author['username'] ?? json['username'],
      ),
      authorAvatar: _nullableString(
        json['author_avatar'] ?? author['avatar_id'] ?? json['avatar_id'],
      ),
      placeName: _nullableString(
        json['place_name'] ?? json['place']?['name'],
      ),
      isVisible: _boolValue(
        json['is_visible'],
        defaultValue: true,
      ),
      createdAt: _dateTimeValue(
        json['created_at'],
      ),
      updatedAt: _dateTimeValue(
        json['updated_at'],
      ),
      likesCount: _intValue(
        state['likes_count'] ??
            json['likes_count'],
      ),
      savesCount: _intValue(
        state['saves_count'] ??
            json['saves_count'],
      ),
      commentsCount: _intValue(
        state['comments_count'] ??
            json['comments_count'],
      ),
      isLiked: _boolValue(
        state['is_liked'] ??
            json['is_liked'],
      ),
      isSaved: _boolValue(
        state['is_saved'] ??
            json['is_saved'],
      ),
    );
  }

  CommunityPost copyWith({
    String? text,
    String? imageUrl,
    double? rating,
    String? authorName,
    String? authorUsername,
    String? authorAvatar,
    String? placeName,
    bool? isVisible,
    DateTime? updatedAt,
    int? likesCount,
    int? savesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return CommunityPost(
      id: id,
      userId: userId,
      placeId: placeId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      placeName: placeName ?? this.placeName,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      savesCount: savesCount ?? this.savesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  static String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final valueString = value.toString().trim();

    return valueString.isEmpty
        ? null
        : valueString;
  }

  static double? _nullableDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static bool _boolValue(
    dynamic value, {
    bool defaultValue = false,
  }) {
    if (value == null) {
      return defaultValue;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return defaultValue;
  }

  static int _intValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static DateTime _dateTimeValue(
    dynamic value,
  ) {
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