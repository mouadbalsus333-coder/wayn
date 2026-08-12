export '../../models/category.dart';
export 'repositories/category_load_result.dart';

import 'repositories/category_load_result.dart';
import 'repositories/category_repository.dart';
import 'repositories/repository_factory.dart';

class CategoryService {
  final CategoryRepository _categoryRepository;

  CategoryService({CategoryRepository? categoryRepository})
    : _categoryRepository = categoryRepository ?? createCategoryRepository();

  Future<CategoryLoadResult> getCategories() async {
    return _categoryRepository.getCategories();
  }
}
