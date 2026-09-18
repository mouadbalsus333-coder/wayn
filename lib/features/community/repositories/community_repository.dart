import '../../../core/network/api_client.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';

class CommunityRepository {
  final ApiClient _apiClient;

  CommunityRepository(this._apiClient);

  // ============================================================
  // Posts
  // ============================================================

  Future<List<CommunityPost>> getPosts({
    String? placeId,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'offset': (page - 1) * limit,
      'limit': limit,
    };

    if (placeId != null && placeId.trim().isNotEmpty) {
      queryParams['place_id'] = placeId;
    }

    if (userId != null && userId.trim().isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    final response = await _apiClient.get(
      '/api/v1/community/posts',
      queryParams: queryParams,
    );

    return _postsFromResponse(response);
  }

  Future<CommunityPost?> getPost(
    String postId,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/community/posts/$postId',
      );

      if (response == null || response is! Map) {
        return null;
      }

      return CommunityPost.fromJson(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<CommunityPost> createPost({
    required String placeId,
    String? text,
    String? imageUrl,
    double? rating,
  }) async {
    final body = <String, dynamic>{
      'place_id': placeId,
    };

    if (text != null && text.trim().isNotEmpty) {
      body['text'] = text.trim();
    }

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      body['image_url'] = imageUrl.trim();
    }

    if (rating != null) {
      body['rating'] = rating;
    }

    final response = await _apiClient.post(
      '/api/v1/community/posts',
      body: body,
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while creating community post',
      );
    }

    return CommunityPost.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CommunityPost> updatePost({
    required String postId,
    String? text,
    String? imageUrl,
    double? rating,
  }) async {
    final body = <String, dynamic>{};

    if (text != null) {
      body['text'] = text.trim();
    }

    if (imageUrl != null) {
      body['image_url'] = imageUrl.trim();
    }

    if (rating != null) {
      body['rating'] = rating;
    }

    final response = await _apiClient.patch(
      '/api/v1/community/posts/$postId',
      body: body,
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while updating community post',
      );
    }

    return CommunityPost.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deletePost(
    String postId,
  ) async {
    await _apiClient.delete(
      '/api/v1/community/posts/$postId',
    );
  }

  // ============================================================
  // Likes
  // ============================================================

  Future<bool> likePost(
    String postId,
  ) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/community/posts/$postId/like',
      );

      if (response is Map) {
        return true;
      }

      return true;
    } on ApiClientException catch (e) {
      if (e.statusCode == 409) {
        return false;
      }

      rethrow;
    }
  }

  Future<bool> unlikePost(
    String postId,
  ) async {
    try {
      final response = await _apiClient.delete(
        '/api/v1/community/posts/$postId/like',
      );

      if (response is Map) {
        return true;
      }

      return true;
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        return false;
      }

      rethrow;
    }
  }

  // ============================================================
  // Saves
  // ============================================================

  Future<bool> savePost(
    String postId,
  ) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/community/posts/$postId/save',
      );

      if (response is Map) {
        return true;
      }

      return true;
    } on ApiClientException catch (e) {
      if (e.statusCode == 409) {
        return false;
      }

      rethrow;
    }
  }

  Future<bool> unsavePost(
    String postId,
  ) async {
    try {
      final response = await _apiClient.delete(
        '/api/v1/community/posts/$postId/save',
      );

      if (response is Map) {
        return true;
      }

      return true;
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        return false;
      }

      rethrow;
    }
  }

  // ============================================================
  // Comments
  // ============================================================

  Future<List<CommunityComment>> getComments({
    required String postId,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/community/posts/$postId/comments',
      queryParams: {
        'offset': offset,
        'limit': limit,
      },
    );

    return _commentsFromResponse(response);
  }

  Future<CommunityComment> createComment({
    required String postId,
    required String text,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/community/posts/$postId/comments',
      body: {
        'text': text.trim(),
      },
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while creating community comment',
      );
    }

    return CommunityComment.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deleteComment(
    String commentId,
  ) async {
    await _apiClient.delete(
      '/api/v1/community/comments/$commentId',
    );
  }

  // ============================================================
  // Response parsing
  // ============================================================

  List<CommunityPost> _postsFromResponse(
    dynamic response,
  ) {
    if (response == null) {
      return [];
    }

    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        return items
            .whereType<Map>()
            .map(
              (item) => CommunityPost.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }

      if (response['id'] != null) {
        return [
          CommunityPost.fromJson(
            Map<String, dynamic>.from(response),
          ),
        ];
      }

      return [];
    }

    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => CommunityPost.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  List<CommunityComment> _commentsFromResponse(
    dynamic response,
  ) {
    if (response == null) {
      return [];
    }

    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        return items
            .whereType<Map>()
            .map(
              (item) => CommunityComment.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }

      if (response['id'] != null) {
        return [
          CommunityComment.fromJson(
            Map<String, dynamic>.from(response),
          ),
        ];
      }

      return [];
    }

    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => CommunityComment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  // ============================================================
  // Post lifecycle (hide / restore / permanent delete)
  // ============================================================

  /// Soft-hides an owned post (moves to "المنشورات المخفية").
  Future<CommunityPost> hidePost(
    String postId,
  ) async {
    final response = await _apiClient.patch(
      '/api/v1/community/posts/$postId/hide',
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while hiding community post',
      );
    }

    return CommunityPost.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  /// Restores an owned post from the deleted/hidden state.
  Future<CommunityPost> restorePost(
    String postId,
  ) async {
    final response = await _apiClient.patch(
      '/api/v1/community/posts/$postId/restore',
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while restoring community post',
      );
    }

    return CommunityPost.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  /// Permanently deletes an owned post (irreversible).
  Future<void> permanentlyDeletePost(
    String postId,
  ) async {
    await _apiClient.delete(
      '/api/v1/community/posts/$postId/permanent',
    );
  }

  /// Lists the current user's own posts filtered by lifecycle state
  /// (VISIBLE / HIDDEN / DELETED).
  Future<List<CommunityPost>> getMyPostsByState({
    required String state,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/community/posts/mine',
      queryParams: <String, dynamic>{
        'state': state,
        'offset': (page - 1) * limit,
        'limit': limit,
      },
    );

    return _postsFromResponse(response);
  }

  // ============================================================
  // Appeals (الطعن في التقييم)
  // ============================================================

  /// Files an appeal against the rating of a post owned by another user.
  Future<void> submitAppeal(
    String postId, {
    required String type,
    required String reason,
  }) async {
    await _apiClient.post(
      '/api/v1/community/posts/$postId/appeals',
      body: <String, dynamic>{
        'type': type,
        'reason': reason,
      },
    );
  }

  /// Returns the current user's own appeal for a post, or null.
  Future<Map<String, dynamic>?> getMyAppeal(
    String postId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/community/posts/$postId/appeals/me',
    );

    if (response == null || response is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // Reports (الإبلاغ عن منشور)
  // ============================================================

    /// Reports a post owned by another user.
  Future<void> submitReport(
    String postId, {
    required String category,
    required String description,
  }) async {
    await _apiClient.post(
      '/api/v1/community/posts/$postId/reports',
      body: <String, dynamic>{
        'category': category,
        'description': description,
      },
    );
  }

  // ============================================================
  // Upload Image & Saved Posts
  // ============================================================

  Future<String> uploadImage({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final response = await _apiClient.uploadFile(
      '/api/v1/community/media/image',
      fileBytes: fileBytes,
      fileName: fileName,
      fieldName: 'file',
    );

    if (response == null || response is! Map) {
      throw ApiClientException(
        'Invalid response while uploading image',
      );
    }

    final data = Map<String, dynamic>.from(response);
    final imageUrl = data['image_url']?.toString();

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw ApiClientException(
        'Upload response missing image_url',
      );
    }

    return imageUrl;
  }

  Future<List<CommunityPost>> getSavedPosts({
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'offset': (page - 1) * limit,
      'limit': limit,
    };

    final response = await _apiClient.get(
      '/api/v1/community/posts/saved',
      queryParams: queryParams,
    );

    return _postsFromResponse(response);
  }
}
