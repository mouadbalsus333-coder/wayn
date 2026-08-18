import '../../models/user.dart';

abstract class AuthRepository {
  Future<User?> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? phone,
    String? avatarId,
  });

  Future<User?> login({
    required String email,
    required String password,
  });

  Future<User?> getCurrentUser();

  Future<void> logout();

  Future<User?> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? avatarId,
    String? bio,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}