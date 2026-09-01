import '../models/user_notification.dart';
import '../models/user_profile.dart';
import 'repositories/repository_factory.dart';
import 'repositories/social_repository.dart';

class SocialService {
  final SocialRepository _repository;

  SocialService({SocialRepository? repository})
      : _repository = repository ?? createSocialRepository();

  Future<FollowResult> follow(String userId) {
    return _repository.followUser(userId);
  }

  Future<FollowResult> unfollow(String userId) {
    return _repository.unfollowUser(userId);
  }

  Future<List<UserNotification>> getNotifications({
    int offset = 0,
    int limit = 50,
  }) {
    return _repository.getNotifications(
      offset: offset,
      limit: limit,
    );
  }

  Future<int> getUnreadCount() {
    return _repository.getUnreadCount();
  }

  Future<void> markNotificationRead(String notificationId) {
    return _repository.markNotificationRead(notificationId);
  }
}
