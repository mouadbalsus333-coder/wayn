import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/category.dart';
import 'category_load_result.dart';
import 'category_repository.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<CategoryLoadResult> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final categories = (response as List)
          .map((item) => Category.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (categories.isNotEmpty) {
        return CategoryLoadResult.loaded(categories);
      }

      final fallbackCategories = await _loadCategoriesFromPlaces();
      return fallbackCategories.isNotEmpty
          ? CategoryLoadResult.loaded(fallbackCategories)
          : const CategoryLoadResult.empty();
    } on PostgrestException {
      final fallbackCategories = await _loadCategoriesFromPlaces();
      return fallbackCategories.isNotEmpty
          ? CategoryLoadResult.loaded(fallbackCategories)
          : const CategoryLoadResult.error();
    } catch (_) {
      final fallbackCategories = await _loadCategoriesFromPlaces();
      return fallbackCategories.isNotEmpty
          ? CategoryLoadResult.loaded(fallbackCategories)
          : const CategoryLoadResult.error();
    }
  }

  Future<List<Category>> _loadCategoriesFromPlaces() async {
    final response = await _supabase
        .from('places')
        .select('category_id,category')
        .eq('is_active', true)
        .not('category_id', 'is', 'null');

    final categories = <String, Category>{};

    for (final element in response as List) {
      final data = Map<String, dynamic>.from(element);
      final categoryId = data['category_id']?.toString();
      final categoryName = data['category']?.toString();

      if (categoryId == null || categoryId.isEmpty) {
        continue;
      }

      if (categoryName == null || categoryName.isEmpty) {
        continue;
      }

      categories.putIfAbsent(
        categoryId,
        () => Category(
          id: categoryId,
          nameAr: categoryName,
          nameEn: null,
          icon: null,
          sortOrder: categories.length,
        ),
      );
    }

    return categories.values.toList()
      ..sort((a, b) => a.nameAr.compareTo(b.nameAr));
  }
}
