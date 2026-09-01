/// الملف الشخصي العام لمستخدم آخر (من `GET /users/{id}`).
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarId;
  final String? bio;

  final int points;
  final int followersCount;
  final int followingCount;
  final int ratingsCount;

  final bool isFollowing;
  final bool isOwner;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarId,
    this.bio,
    this.points = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.ratingsCount = 0,
    this.isFollowing = false,
    this.isOwner = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) {
    int i(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    bool d(dynamic v) =>
        v == true || (v is String && v.toLowerCase() == 'true');

    return UserProfile(
      id: m['id']?.toString() ?? '',
      username: m['username']?.toString() ?? '',
      displayName: m['full_name']?.toString() ?? '',
      avatarId: m['avatar_id']?.toString(),
      bio: m['bio']?.toString(),
      points: i(m['points']),
      followersCount: i(m['followers_count']),
      followingCount: i(m['following_count']),
      ratingsCount: i(m['ratings_count']),
      isFollowing: d(m['is_following']),
      isOwner: d(m['is_owner']),
    );
  }

  UserProfile copyWith({
    bool? isFollowing,
    int? followersCount,
  }) {
    return UserProfile(
      id: id,
      username: username,
      displayName: displayName,
      avatarId: avatarId,
      bio: bio,
      points: points,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      ratingsCount: ratingsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwner: isOwner,
    );
  }
}

/// نتيجة عملية متابعة/إلغاء متابعة من Backend.
class FollowResult {
  final String userId;
  final bool isFollowing;
  final int followersCount;

  const FollowResult({
    required this.userId,
    required this.isFollowing,
    required this.followersCount,
  });

  factory FollowResult.fromMap(Map<String, dynamic> m) {
    return FollowResult(
      userId: m['user_id']?.toString() ?? '',
      isFollowing: m['is_following'] == true,
      followersCount:
          (m['followers_count'] as num?)?.toInt() ?? 0,
    );
  }
}
