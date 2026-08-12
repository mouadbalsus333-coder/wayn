import '../../core/network/api_client.dart';
import '../../models/category.dart';
import 'category_load_result.dart';
import 'category_repository.dart';

class FastApiCategoryRepository implements CategoryRepository {
  final ApiClient _apiClient;

  FastApiCategoryRepository(this._apiClient);

  @override
  Future<CategoryLoadResult> getCategories() async {
    try {
      final response = await _apiClient.get('/api/v1/categories');

      if (response == null || response is! List) {
        return const CategoryLoadResult.empty();
      }

      final categories = response
          .map(
            (item) => Category.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (categories.isEmpty) {
        return const CategoryLoadResult.empty();
      }

      return CategoryLoadResult.loaded(categories);
    } on ApiClientException {
      return const CategoryLoadResult.error();
    } catch (_) {
      return const CategoryLoadResult.error();
    }
  }
}