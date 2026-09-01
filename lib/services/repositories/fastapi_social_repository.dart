import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/user_notification.dart';
import '../../models/user_profile.dart';
import 'social_repository.dart';

class FastApiSocialRepository implements SocialRepository {
  final DartHttpApiClient _api;

  FastApiSocialRepository(this._api);

  @override
  Future<FollowResult> followUser(String userId) async {
    final response = await _api.post(
      '/api/v1/users/$userId/follow',
    );

    return FollowResult.fromMap(
      Map<String, dynamic>.from(
        (response is Map) ? response : <String, dynamic>{},
      ),
    );
  }

  @override
  Future<FollowResult> unfollowUser(String userId) async {
    final response = await _api.delete(
      '/api/v1/users/$userId/follow',
    );

    return FollowResult.fromMap(
      Map<String, dynamic>.from(
        (response is Map) ? response : <String, dynamic>{},
      ),
    );
  }

  @override
  Future<List<UserNotification>> getNotifications({
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _api.get(
      '/api/v1/notifications',
      queryParams: {
        'offset': offset,
        'limit': limit,
      },
    );

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (e) => UserNotification.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _api.get(
        '/api/v1/notifications/unread-count',
      );

      if (response is! Map) {
        return 0;
      }

      return (response['count'] as num?)?.toInt() ?? 0;
    } on ApiClientException {
      return 0;
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _api.post(
      '/api/v1/notifications/$notificationId/read',
    );
  }
}
