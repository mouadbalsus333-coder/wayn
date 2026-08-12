import '../../models/category.dart';

enum CategoryLoadStatus {
  loading,
  loaded,
  empty,
  error,
  permissionDenied,
  failure,
}

class CategoryLoadResult {
  final CategoryLoadStatus status;
  final List<Category> categories;

  const CategoryLoadResult._({
    required this.status,
    this.categories = const [],
  });

  const CategoryLoadResult.loaded(List<Category> categories)
    : this._(status: CategoryLoadStatus.loaded, categories: categories);

  const CategoryLoadResult.empty() : this._(status: CategoryLoadStatus.empty);

  const CategoryLoadResult.error() : this._(status: CategoryLoadStatus.error);

  const CategoryLoadResult.permissionDenied()
    : this._(status: CategoryLoadStatus.permissionDenied);

  const CategoryLoadResult.failure()
    : this._(status: CategoryLoadStatus.failure);
}
