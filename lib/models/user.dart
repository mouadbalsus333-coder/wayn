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

  /// Admin context returned by the backend (``/auth/me`` etc.) when the
  /// email of this user also belongs to an active/disabled AdminUser.
  /// ``null`` for regular users — see [UserAdminAccess].
  final UserAdminAccess? admin;

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
    this.admin,
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

      admin: _adminAccess(data['admin']),
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

      // Keep the admin context alive across session restores so the
      // "لوحة الإدارة" entry point survives app restarts too. The
      // backend remains the source of truth on every /auth/me call.
      'admin': admin == null
          ? null
          : {
              'role': admin!.role,
              'admin_status': admin!.adminStatus,
              'permissions': admin!.permissions,
            },
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

/// Admin-specific authorization context for a regular [User].
///
/// Mirrors the ``admin`` object the backend attaches to the user payload
/// (see ``UserAdminInfo`` in ``backend/app/schemas/user_auth.py``). It is
/// **only** UX input — the backend independently re-verifies role, active
/// status and the required permission on every admin request.
class UserAdminAccess {
  final String? role;
  final String? adminStatus;

  /// Resolved, de-duplicated list of permission names.
  final List<String> permissions;

  const UserAdminAccess({
    this.role,
    this.adminStatus,
    this.permissions = const [],
  });

  /// Whether the account is linked to an AdminUser at all.
  ///
  /// The backend attaches the ``admin`` object whenever the email
  /// matches an AdminUser — even when that admin has **no roles**
  /// (``role`` may be ``null`` while direct permissions are still
  /// present). Presence of the object / ``admin_status`` is therefore
  /// what makes an account an admin, not the role string.
  bool get isAdmin => role != null || adminStatus != null;

  /// An active (enabled) admin account — the only case where the
  /// "لوحة الإدارة" entry point should be shown.
  bool get isActiveAdmin => adminStatus == 'active';

  /// A disabled admin account must not see/use the admin panel.
  bool get isDisabledAdmin => adminStatus != null && adminStatus != 'active';

  bool get isSuperAdmin => role == 'super_admin';

  bool hasPermission(String name) {
    return permissions.contains(name);
  }

  bool hasAnyPermission(List<String> names) {
    for (final name in names) {
      if (permissions.contains(name)) return true;
    }
    return false;
  }
}

UserAdminAccess? _adminAccess(dynamic value) {
  if (value is! Map) {
    return null;
  }

  final map = Map<String, dynamic>.from(value);

  // The backend sends the admin object for ANY account linked to an
  // AdminUser, including admins without roles (role == null). We must
  // not drop the context in that case — otherwise the "لوحة الإدارة"
  // entry point silently disappears for permission-only admins.
  final role = map['role']?.toString();
  final status = map['admin_status']?.toString();

  if ((role == null || role.isEmpty) &&
      (status == null || status.isEmpty)) {
    return null;
  }

  final permissions = <String>[];

  final raw = map['permissions'];

  if (raw is List) {
    for (final item in List<dynamic>.from(raw)) {
      final permission = item?.toString();

      if (permission != null && permission.isNotEmpty) {
        permissions.add(permission);
      }
    }
  }

  return UserAdminAccess(
    role: role,
    adminStatus: status,
    permissions: permissions,
  );
}