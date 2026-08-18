import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/user.dart' as app_user;
import 'user_repository.dart';

class FastApiUserRepository implements UserRepository {
  final DartHttpApiClient _api;

  FastApiUserRepository(this._api);

  // ============================================================
  // Current user
  // ============================================================

  @override
  Future<app_user.User?> getCurrentUser() async {
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

      return app_user.User.fromMap(
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
  // User by ID
  // ============================================================

  @override
  Future<app_user.User?> getUserById(String id) async {
    final userId = id.trim();

    if (userId.isEmpty) {
      return null;
    }

    // The current FastAPI backend does not expose
    // a public GET /users/{id} endpoint yet.
    //
    // This method will be implemented when the corresponding
    // FastAPI endpoint is added.

    return null;
  }

  // ============================================================
  // Search users
  // ============================================================

  @override
  Future<List<app_user.User>> searchUsers(String query) async {
    final search = query.trim();

    if (search.isEmpty) {
      return [];
    }

    // The current FastAPI backend does not expose
    // a user-search endpoint yet.
    //
    // This will be implemented when the corresponding
    // FastAPI endpoint is added.

    return [];
  }

  // ============================================================
  // Create / update current user
  // ============================================================

  @override
  Future<app_user.User?> createOrUpdateUser(
    app_user.User user,
  ) async {
    try {
      final body = <String, dynamic>{
        'full_name': user.displayName,
        'username': user.username,
        'phone': null,
        'avatar_id': user.avatarUrl,
        'bio': user.bio,
      };

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

      return app_user.User.fromMap(
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
}