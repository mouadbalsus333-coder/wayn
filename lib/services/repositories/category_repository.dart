import 'category_load_result.dart';

abstract class CategoryRepository {
  Future<CategoryLoadResult> getCategories();
}
