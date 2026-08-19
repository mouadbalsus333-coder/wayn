
import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/user.dart';
import 'auth_repository.dart';

class FastApiAuthRepository implements AuthRepository {
  final DartHttpApiClient _api;

  FastApiAuthRepository(this._api);

  // ============================================================
  // Register
  // ============================================================

  @override
  Future<User?> register({
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

    return _handleAuthResponse(response);
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

      return User.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
        return null;
      }

      rethrow;
    }
  }

  // ============================================================
  // Logout
  // ============================================================

  @override
  Future<void> logout() async {
    await _api.clearAuthToken();
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

      return User.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
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
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ============================================================
  // Authentication response
  // ============================================================

  Future<User?> _handleAuthResponse(
    dynamic response,
  ) async {
    try {
      print('WAYN AUTH: received response');
      print('WAYN AUTH: response type = ${response.runtimeType}');

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

      print('WAYN AUTH: response keys = ${data.keys.toList()}');

      // ----------------------------------------------------------
      // Access token
      // ----------------------------------------------------------

      final accessToken = data['access_token']?.toString();

      if (accessToken == null || accessToken.trim().isEmpty) {
        print('WAYN AUTH ERROR: access_token is missing');

        throw ApiClientException(
          'Authentication response does not contain an access token',
        );
      }

      print('WAYN AUTH: access_token received');

      // ----------------------------------------------------------
      // User
      // ----------------------------------------------------------

      final userData = data['user'];

      print(
        'WAYN AUTH: user type = ${userData.runtimeType}',
      );

      if (userData is! Map) {
        print('WAYN AUTH ERROR: user is not a Map');

        throw ApiClientException(
          'Authentication response does not contain a valid user',
        );
      }

      final userMap = Map<String, dynamic>.from(userData);

      print(
        'WAYN AUTH: user keys = ${userMap.keys.toList()}',
      );

      print(
        'WAYN AUTH: user id = ${userMap['id']}',
      );

      print(
        'WAYN AUTH: user email = ${userMap['email']}',
      );

      // ----------------------------------------------------------
      // Save token
      // ----------------------------------------------------------

      print('WAYN AUTH: saving access token...');

      await _api.setAuthToken(accessToken);

      print('WAYN AUTH: access token saved');

      // ----------------------------------------------------------
      // Convert API user to Flutter User
      // ----------------------------------------------------------

      print('WAYN AUTH: converting user...');

      final user = User.fromMap(userMap);

      print(
        'WAYN AUTH: User.fromMap succeeded: ${user.id}',
      );

      return user;
    } catch (error, stackTrace) {
      print('WAYN AUTH FAILED: $error');
      print('WAYN AUTH STACKTRACE: $stackTrace');

      rethrow;
    }
  }
}
