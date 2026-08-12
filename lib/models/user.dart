class User {
  final String id;
  final String email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int pointsBalance;
  final int reputationScore;
  final String? trustLevel;
  final int followersCount;
  final int followingCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const User({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.pointsBalance = 0,
    this.reputationScore = 0,
    this.trustLevel,
    this.followersCount = 0,
    this.followingCount = 0,
    required this.isActive,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString(),
      displayName: data['display_name']?.toString(),
      avatarUrl: data['avatar_url']?.toString(),
      bio: data['bio']?.toString(),
      pointsBalance: _intValue(data['points_balance']),
      reputationScore: _intValue(data['reputation_score']),
      trustLevel: data['trust_level']?.toString(),
      followersCount: _intValue(data['followers_count']),
      followingCount: _intValue(data['following_count']),
      isActive: _boolValue(data['is_active']),
      createdAt: _dateTimeValue(data['created_at']) ?? DateTime.now(),
      lastActiveAt: _dateTimeValue(data['last_active_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'points_balance': pointsBalance,
      'reputation_score': reputationScore,
      'trust_level': trustLevel,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_active_at': lastActiveAt?.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return false;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(value.toString());
}
