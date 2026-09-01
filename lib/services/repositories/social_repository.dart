import '../../models/user_notification.dart';
import '../../models/user_profile.dart';

abstract class SocialRepository {
  /// تابع المستخدم [userId]. يعيد [FollowResult].
  Future<FollowResult> followUser(String userId);

  /// إلغاء متابعة المستخدم [userId]. يعيد [FollowResult].
  Future<FollowResult> unfollowUser(String userId);

  /// قائمة إشعارات المستخدم الحالي.
  Future<List<UserNotification>> getNotifications({
    int offset = 0,
    int limit = 50,
  });

  /// عدد الإشعارات غير المقروءة.
  Future<int> getUnreadCount();

  /// تعليم إشعار كمقروء.
  Future<void> markNotificationRead(String notificationId);
}
