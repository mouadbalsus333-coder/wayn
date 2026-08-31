import '../../models/user.dart';

/// Result returned after creating a new account.
///
/// Registration does NOT authenticate the user immediately.
/// The backend may require email verification first.
class RegistrationResult {
  final User user;
  final bool verificationRequired;
  final String message;

  const RegistrationResult({
    required this.user,
    required this.verificationRequired,
    required this.message,
  });
}

/// Result returned after verifying an email address.
class VerificationResult {
  final User user;
  final String accessToken;
  final String tokenType;

  const VerificationResult({
    required this.user,
    required this.accessToken,
    required this.tokenType,
  });
}

abstract class AuthRepository {
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
  });

  // ============================================================
  // Login
  // ============================================================

  Future<User?> login({
    required String email,
    required String password,
  });

  // ============================================================
  // Current user
  // ============================================================

  Future<User?> getCurrentUser();

  // ============================================================
  // Logout
  // ============================================================

  Future<void> logout();

  // ============================================================
  // Update profile
  // ============================================================

  Future<User?> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? avatarId,
    String? bio,
  });

  // ============================================================
  // Change password while authenticated
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  // ============================================================
  // Email verification
  // ============================================================

  Future<VerificationResult?> verifyEmail({
    required String email,
    required String code,
  });

  Future<void> resendVerificationCode({
    required String email,
  });

  // ============================================================
  // Password reset
  // ============================================================

  Future<void> forgotPassword({
    required String email,
  });

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
