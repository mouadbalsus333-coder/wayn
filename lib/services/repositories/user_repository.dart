import '../../models/user.dart';

abstract class UserRepository {
  Future<User?> getCurrentUser();

  Future<User?> getUserById(String id);

  Future<List<User>> searchUsers(String query);

  Future<User?> createOrUpdateUser(User user);
}
