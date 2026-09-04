import '../core/network/wayn_api.dart';
import '../models/store.dart';

class StoreService {
  Future<List<StoreCategory>> categories() async {
    final d = await waynApi.get(
      '/api/v1/store/categories',
      queryParams: {'active_only': true},
    );
    return (d as List)
        .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<StoreItem>> items({String? categoryId}) async {
    final d = await waynApi.get(
      '/api/v1/store/items',
      queryParams: {
        'active_only': true,
        if (categoryId case final id) 'category_id': id,
      },
    );
    return (d as List)
        .map((e) => StoreItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<StorePurchase> purchase(String itemId) async {
    final response = await waynApi.post(
      '/api/v1/store/items/$itemId/purchase',
      headers: {
        'Idempotency-Key': '${DateTime.now().microsecondsSinceEpoch}-$itemId',
      },
    );

    return StorePurchase.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<List<StoreOwnership>> ownership() async {
    final response = await waynApi.get('/api/v1/store/ownership');
    final values = response is List ? response : const [];

    return values
        .map(
          (value) =>
              StoreOwnership.fromMap(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
  }

  Future<List<StoreBanner>> banners() async {
    final d = await waynApi.get(
      '/api/v1/store/banners',
      queryParams: {'active_only': true},
    );
    return (d as List)
        .map((e) => StoreBanner.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
