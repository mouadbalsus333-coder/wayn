import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/user.dart';
import '../user_session_storage.dart';
import 'auth_repository.dart';

class FastApiAuthRepository implements AuthRepository {
  final DartHttpApiClient _api;
  final UserSessionStorage _userSessionStorage;

  FastApiAuthRepository(
    this._api, {
    UserSessionStorage? userSessionStorage,
  }) : _userSessionStorage =
            userSessionStorage ?? UserSessionStorage();

  // ============================================================
  // Register
  // ============================================================

  @override
  Future<RegistrationResult?> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? phone,
    String? avatarId,
  }) async {
    final response = await _api.post(
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'username': username,
        if (phone != null && phone.trim().isNotEmpty)
          'phone': phone.trim(),
        if (avatarId != null && avatarId.trim().isNotEmpty)
          'avatar_id': avatarId.trim(),
      },
    );

    if (response == null) {
      return null;
    }

    if (response is! Map) {
      throw ApiClientException(
        'Invalid registration response',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final userData = data['user'];

    if (userData is! Map) {
      throw ApiClientException(
        'Registration response does not contain a valid user',
      );
    }

    final user = User.fromMap(
      Map<String, dynamic>.from(userData),
    );

    return RegistrationResult(
      user: user,
      verificationRequired:
          data['verification_required'] == true,
      message: data['message']?.toString() ?? '',
    );
  }

  // ============================================================
  // Login
  // ============================================================

  @override
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/api/v1/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    return _handleAuthResponse(response);
  }

  // ============================================================
  // Current user
  // ============================================================

  @override
  Future<User?> getCurrentUser() async {
    try {
      final response = await _api.get(
        '/api/v1/auth/me',
      );

      if (response == null) {
        return null;
      }

      if (response is! Map) {
        throw ApiClientException(
          'Invalid response received from /api/v1/auth/me',
        );
      }

      final user = User.fromMap(
        Map<String, dynamic>.from(response),
      );

      await _userSessionStorage.saveUser(user);

      return user;
    } on ApiClientException catch (error) {
      // A 401 means the server explicitly rejected the
      // authentication token. This is different from a
      // network failure and should end the local session.
      if (error.statusCode == 401) {
        await _clearLocalSession();
        return null;
      }

      // Any other API error is not treated as logout.
      // Try the last locally cached authenticated user.
      final cachedUser =
          await _userSessionStorage.getCachedUser();

      if (cachedUser != null) {
        return cachedUser;
      }

      rethrow;
    } catch (_) {
      // Network errors such as no internet, timeout, DNS failure,
      // or connection refused must not log the user out.
      final cachedUser =
          await _userSessionStorage.getCachedUser();

      if (cachedUser != null) {
        return cachedUser;
      }

      rethrow;
    }
  }

  // ============================================================
  // Logout
  // ============================================================

  @override
  Future<void> logout() async {
    await _clearLocalSession();
  }

  // ============================================================
  // Update profile
  // ============================================================

  @override
  Future<User?> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? avatarId,
    String? bio,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (fullName != null) {
        body['full_name'] = fullName;
      }

      if (username != null) {
        body['username'] = username;
      }

      if (phone != null) {
        body['phone'] = phone;
      }

      if (avatarId != null) {
        body['avatar_id'] = avatarId;
      }

      if (bio != null) {
        body['bio'] = bio;
      }

      final response = await _api.put(
        '/api/v1/auth/me',
        body: body,
      );

      if (response == null) {
        return null;
      }

      if (response is! Map) {
        throw ApiClientException(
          'Invalid response received from /api/v1/auth/me',
        );
      }

      final user = User.fromMap(
        Map<String, dynamic>.from(response),
      );

      await _userSessionStorage.saveUser(user);

      return user;
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _clearLocalSession();
        return null;
      }

      rethrow;
    }
  }

  // ============================================================
  // Change password
  // ============================================================

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.put(
        '/api/v1/auth/me/password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _clearLocalSession();
      }

      rethrow;
    }
  }

  // ============================================================
  // Email verification
  // ============================================================

  @override
  Future<VerificationResult?> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _api.post(
      '/api/v1/auth/verify-email',
      body: {
        'email': email,
        'code': code,
      },
    );

    if (response == null) {
      return null;
    }

    if (response is! Map) {
      throw ApiClientException(
        'Invalid email verification response',
      );
    }

    final data = Map<String, dynamic>.from(response);

    final accessToken = data['access_token']?.toString();

    if (accessToken == null || accessToken.trim().isEmpty) {
      throw ApiClientException(
        'Email verification response does not contain an access token',
      );
    }

    final userData = data['user'];

    if (userData is! Map) {
      throw ApiClientException(
        'Email verification response does not contain a valid user',
      );
    }

    final user = User.fromMap(
      Map<String, dynamic>.from(userData),
    );

    await _api.setAuthToken(accessToken);
    await _userSessionStorage.saveUser(user);

    return VerificationResult(
      user: user,
      accessToken: accessToken,
      tokenType: data['token_type']?.toString() ?? 'bearer',
    );
  }

  // ============================================================
  // Resend verification code
  // ============================================================

  @override
  Future<void> resendVerificationCode({
    required String email,
  }) async {
    await _api.post(
      '/api/v1/auth/resend-verification',
      body: {
        'email': email,
      },
    );
  }

  // ============================================================
  // Forgot password
  // ============================================================

  @override
  Future<void> forgotPassword({
    required String email,
  }) async {
    await _api.post(
      '/api/v1/auth/forgot-password',
      body: {
        'email': email,
      },
    );
  }

  // ============================================================
  // Reset password
  // ============================================================

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/v1/auth/reset-password',
      body: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      },
    );
  }

  // ============================================================
  // Authentication response
  // ============================================================

  Future<User?> _handleAuthResponse(
    dynamic response,
  ) async {
    try {
      print('WAYN AUTH: received response');
      print(
        'WAYN AUTH: response type = '
        '${response.runtimeType}',
      );

      if (response == null) {
        print('WAYN AUTH ERROR: response is null');
        return null;
      }

      if (response is! Map) {
        print(
          'WAYN AUTH ERROR: response is not a Map: '
          '${response.runtimeType}',
        );

        throw ApiClientException(
          'Invalid authentication response',
        );
      }

      final data = Map<String, dynamic>.from(response);

      print(
        'WAYN AUTH: response keys = '
        '${data.keys.toList()}',
      );

      // ----------------------------------------------------------
      // Access token
      // ----------------------------------------------------------

      final accessToken = data['access_token']?.toString();

      if (accessToken == null || accessToken.trim().isEmpty) {
        print(
          'WAYN AUTH ERROR: access_token is missing',
        );

        throw ApiClientException(
          'Authentication response does not contain an access token',
        );
      }

      // ----------------------------------------------------------
      // User
      // ----------------------------------------------------------

      final userData = data['user'];

      if (userData is! Map) {
        throw ApiClientException(
          'Authentication response does not contain a valid user',
        );
      }

      final userMap = Map<String, dynamic>.from(userData);

      // ----------------------------------------------------------
      // Save token
      // ----------------------------------------------------------

      await _api.setAuthToken(accessToken);

      // ----------------------------------------------------------
      // Convert API user
      // ----------------------------------------------------------

      final user = User.fromMap(userMap);

      // ----------------------------------------------------------
      // Save local authenticated user
      // ----------------------------------------------------------

      await _userSessionStorage.saveUser(user);

      return user;
    } catch (error, stackTrace) {
      print('WAYN AUTH FAILED: $error');
      print('WAYN AUTH STACKTRACE: $stackTrace');

      rethrow;
    }
  }

  // ============================================================
  // Local session
  // ============================================================

  Future<void> _clearLocalSession() async {
    await _api.clearAuthToken();
    await _userSessionStorage.clearUser();
  }
}