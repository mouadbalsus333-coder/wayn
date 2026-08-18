class User {
  final String id;
  final String email;

  final String? username;
  final String? displayName;

  final String? avatarUrl;
  final String? avatarId;

  final String? bio;

  final String? phone;

  final double? latitude;
  final double? longitude;
  final String? locationSource;

  final bool isActive;
  final bool isVerified;

  final int pointsBalance;
  final int reputationScore;
  final String? trustLevel;

  final int followersCount;
  final int followingCount;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActiveAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.avatarId,
    this.bio,
    this.phone,
    this.latitude,
    this.longitude,
    this.locationSource,
    required this.isActive,
    this.isVerified = false,
    this.pointsBalance = 0,
    this.reputationScore = 0,
    this.trustLevel,
    this.followersCount = 0,
    this.followingCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
    this.lastLoginAt,
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',

      username: data['username']?.toString(),

      // FastAPI: full_name
      // Legacy Flutter data: display_name
      displayName:
          data['full_name']?.toString() ??
          data['display_name']?.toString(),

      // FastAPI: avatar_id
      avatarId: data['avatar_id']?.toString(),

      // Legacy Flutter field
      avatarUrl: data['avatar_url']?.toString(),

      bio: data['bio']?.toString(),

      phone: data['phone']?.toString(),

      latitude: _doubleValue(data['latitude']),
      longitude: _doubleValue(data['longitude']),

      locationSource:
          data['location_source']?.toString(),

      isActive: _boolValue(data['is_active']),

      isVerified: _boolValue(data['is_verified']),

      pointsBalance:
          _intValue(data['points_balance']),

      reputationScore:
          _intValue(data['reputation_score']),

      trustLevel:
          data['trust_level']?.toString(),

      followersCount:
          _intValue(data['followers_count']),

      followingCount:
          _intValue(data['following_count']),

      createdAt:
          _dateTimeValue(data['created_at']) ??
          DateTime.now(),

      updatedAt:
          _dateTimeValue(data['updated_at']),

      lastActiveAt:
          _dateTimeValue(data['last_active_at']),

      lastLoginAt:
          _dateTimeValue(data['last_login_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,

      'username': username,

      'display_name': displayName,
      'full_name': displayName,

      'avatar_url': avatarUrl,
      'avatar_id': avatarId,

      'bio': bio,
      'phone': phone,

      'latitude': latitude,
      'longitude': longitude,
      'location_source': locationSource,

      'is_active': isActive,
      'is_verified': isVerified,

      'points_balance': pointsBalance,
      'reputation_score': reputationScore,
      'trust_level': trustLevel,

      'followers_count': followersCount,
      'following_count': followingCount,

      'created_at': createdAt.toIso8601String(),

      'updated_at':
          updatedAt?.toIso8601String(),

      'last_active_at':
          lastActiveAt?.toIso8601String(),

      'last_login_at':
          lastLoginAt?.toIso8601String(),
    }..removeWhere(
        (key, value) => value == null,
      );
  }
}

int _intValue(dynamic value) {
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

double? _doubleValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

bool _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  if (value is num) {
    return value != 0;
  }

  return false;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}