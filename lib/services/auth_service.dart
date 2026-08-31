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

  Future<RegistrationResult?> register({
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

  // ============================================================
  // Email verification
  // ============================================================

  Future<VerificationResult?> verifyEmail({
    required String email,
    required String code,
  }) async {
    return _authRepository.verifyEmail(
      email: email,
      code: code,
    );
  }

  Future<void> resendVerificationCode({
    required String email,
  }) async {
    await _authRepository.resendVerificationCode(
      email: email,
    );
  }

  // ============================================================
  // Password reset
  // ============================================================

  Future<void> forgotPassword({
    required String email,
  }) async {
    await _authRepository.forgotPassword(
      email: email,
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _authRepository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
}
