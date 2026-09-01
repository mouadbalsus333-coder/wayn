import '../../models/user.dart';
import '../../models/user_profile.dart';

abstract class UserRepository {
  Future<User?> getCurrentUser();

  Future<User?> getUserById(String id);

  Future<List<User>> searchUsers(String query);

  Future<User?> createOrUpdateUser(User user);

  /// Returns the authenticated user's points balance.
  Future<int> getMyPoints();

  /// Public profile of another user.
  Future<UserProfile?> getUserProfile(String id);
}
