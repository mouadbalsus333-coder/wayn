import '../../../core/network/api_client.dart';
import '../../../core/network/wayn_api.dart';
import 'admin_store_models.dart';

class AdminStoreService {
  Future<String> uploadImage({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final response = await waynAdminApi.uploadFile(
      '/api/v1/admin/store/media/image',
      fileBytes: fileBytes,
      fileName: fileName,
      fieldName: 'file',
    );

    if (response is! Map) {
      throw ApiClientException('Invalid response while uploading image');
    }

    final imageUrl = response['image_url']?.toString();
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw ApiClientException('Upload response missing image_url');
    }

    return imageUrl;
  }

  Future<List<AdminStoreCategory>> getCategories() async {
    final response = await waynAdminApi.get(
      '/api/v1/store/categories',
      queryParams: {'active_only': false},
    );

    return _list(response).map(AdminStoreCategory.fromMap).toList();
  }

  Future<List<AdminStoreItem>> getItems() async {
    final response = await waynAdminApi.get(
      '/api/v1/store/items',
      queryParams: {'active_only': false},
    );

    return _list(response).map(AdminStoreItem.fromMap).toList();
  }

  Future<AdminStoreCategory> createCategory(Map<String, dynamic> body) async {
    final response = await waynAdminApi.post(
      '/api/v1/admin/store/categories',
      body: body,
    );
    return AdminStoreCategory.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<AdminStoreCategory> updateCategory(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await waynAdminApi.put(
      '/api/v1/admin/store/categories/$id',
      body: body,
    );
    return AdminStoreCategory.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<AdminStoreItem> createItem(Map<String, dynamic> body) async {
    final response = await waynAdminApi.post(
      '/api/v1/admin/store/items',
      body: body,
    );
    return AdminStoreItem.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<AdminStoreItem> updateItem(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await waynAdminApi.put(
      '/api/v1/admin/store/items/$id',
      body: body,
    );
    return AdminStoreItem.fromMap(Map<String, dynamic>.from(response as Map));
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    final values = response is List
        ? response
        : response is Map && response['items'] is List
        ? response['items'] as List
        : null;

    if (values == null) {
      throw FormatException('Expected a list response');
    }

    return values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }
}
