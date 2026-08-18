import '../models/user.dart';
import 'repositories/auth_repository.dart';
import 'repositories/repository_factory.dart';

class AuthService {
  final AuthRepository _authRepository;

  AuthService({
    AuthRepository? authRepository,
  }) : _authRepository =
            authRepository ?? createAuthRepository();

  // ============================================================
  // Register
  // ============================================================

  Future<User?> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? phone,
    String? avatarId,
  }) async {
    return _authRepository.register(
      email: email,
      password: password,
      fullName: fullName,
      username: username,
      phone: phone,
      avatarId: avatarId,
    );
  }

  // ============================================================
  // Login
  // ============================================================

  Future<User?> login({
    required String email,
    required String password,
  }) async {
    return _authRepository.login(
      email: email,
      password: password,
    );
  }

  // ============================================================
  // Current user
  // ============================================================

  Future<User?> getCurrentUser() async {
    return _authRepository.getCurrentUser();
  }

  // ============================================================
  // Logout
  // ============================================================

  Future<void> logout() async {
    await _authRepository.logout();
  }

  // ============================================================
  // Update profile
  // ============================================================

  Future<User?> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? avatarId,
    String? bio,
  }) async {
    return _authRepository.updateProfile(
      fullName: fullName,
      username: username,
      phone: phone,
      avatarId: avatarId,
      bio: bio,
    );
  }

  // ============================================================
  // Change password
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}