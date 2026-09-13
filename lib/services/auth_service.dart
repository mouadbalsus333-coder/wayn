import 'dart:async' show unawaited;

import '../models/user.dart';
import 'notifications/fcm_controller.dart';
import 'repositories/auth_repository.dart';
import 'repositories/repository_factory.dart';

class AuthService {
  final AuthRepository _authRepository;
  final FcmController _fcmController;

  AuthService({
    AuthRepository? authRepository,
    FcmController? fcmController,
  })  : _authRepository = authRepository ?? createAuthRepository(),
        _fcmController = fcmController ?? FcmController();

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
    final user = await _authRepository.login(
      email: email,
      password: password,
    );

    // After a successful login, register this device for push delivery.
    // Fire-and-forget: must never break the auth flow.
    if (user != null) {
      unawaited(_fcmController.registerDeviceIfReady());
    }

    return user;
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
    // Deactivate this device so it no longer receives push after logout.
    // Fire-and-forget: logout must succeed even if the backend is unreachable.
    unawaited(_fcmController.deactivateDevice());
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
