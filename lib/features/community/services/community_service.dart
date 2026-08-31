import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../repositories/community_repository.dart';

class CommunityService {
  final CommunityRepository _repository;

  CommunityService(this._repository);

  // ============================================================
  // Posts
  // ============================================================

  Future<List<CommunityPost>> getPosts({
    String? placeId,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.getPosts(
      placeId: placeId,
      page: page,
      limit: limit,
    );
  }

  Future<CommunityPost?> getPost(
    String postId,
  ) {
    return _repository.getPost(postId);
  }

  Future<CommunityPost> createPost({
    required String placeId,
    String? text,
    String? imageUrl,
    double? rating,
  }) async {
    final normalizedText = text?.trim();

    if ((normalizedText == null || normalizedText.isEmpty) &&
        (imageUrl == null || imageUrl.trim().isEmpty)) {
      throw ArgumentError(
        'Post must contain text or image',
      );
    }

    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError(
        'Rating must be between 1 and 5',
      );
    }

    return _repository.createPost(
      placeId: placeId,
      text: normalizedText,
      imageUrl: imageUrl?.trim(),
      rating: rating,
    );
  }

  Future<CommunityPost> updatePost({
    required String postId,
    String? text,
    String? imageUrl,
    double? rating,
  }) async {
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError(
        'Rating must be between 1 and 5',
      );
    }

    final normalizedText = text?.trim();
    final normalizedImageUrl = imageUrl?.trim();

    return _repository.updatePost(
      postId: postId,
      text: normalizedText,
      imageUrl: normalizedImageUrl,
      rating: rating,
    );
  }

  Future<void> deletePost(
    String postId,
  ) {
    return _repository.deletePost(postId);
  }

  // ============================================================
  // Likes
  // ============================================================

  Future<bool> likePost(
    String postId,
  ) {
    return _repository.likePost(postId);
  }

  Future<bool> unlikePost(
    String postId,
  ) {
    return _repository.unlikePost(postId);
  }

  // ============================================================
  // Saves
  // ============================================================

  Future<bool> savePost(
    String postId,
  ) {
    return _repository.savePost(postId);
  }

  Future<bool> unsavePost(
    String postId,
  ) {
    return _repository.unsavePost(postId);
  }

  Future<List<CommunityPost>> getSavedPosts({
    int page = 1,
    int limit = 20,
  }) {
    return _repository.getSavedPosts(
      page: page,
      limit: limit,
    );
  }

  Future<String> uploadImage({
    required List<int> fileBytes,
    required String fileName,
  }) {
    return _repository.uploadImage(
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  // ============================================================
  // Comments
  // ============================================================

  Future<List<CommunityComment>> getComments({
    required String postId,
    int offset = 0,
    int limit = 50,
  }) {
    return _repository.getComments(
      postId: postId,
      offset: offset,
      limit: limit,
    );
  }

  Future<CommunityComment> createComment({
    required String postId,
    required String text,
  }) async {
    final normalizedText = text.trim();

    if (normalizedText.isEmpty) {
      throw ArgumentError(
        'Comment cannot be empty',
      );
    }

    return _repository.createComment(
      postId: postId,
      text: normalizedText,
    );
  }

  Future<void> deleteComment(
    String commentId,
  ) {
    return _repository.deleteComment(commentId);
  }
}