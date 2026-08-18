
import '../core/network/wayn_api.dart';
import '../models/store.dart';
class StoreService {
  Future<List<StoreCategory>> categories() async {
    final d=await waynApi.get('/api/v1/store/categories',queryParams:{'active_only':true});
    return (d as List).map((e)=>StoreCategory.fromMap(Map<String,dynamic>.from(e))).toList();
  }
  Future<List<StoreItem>> items({String? categoryId}) async {
    final d=await waynApi.get('/api/v1/store/items',queryParams:{'active_only': true, if (categoryId case final id?) 'category_id': id});
    return (d as List).map((e)=>StoreItem.fromMap(Map<String,dynamic>.from(e))).toList();
  }
  Future<List<StoreBanner>> banners() async {
    final d=await waynApi.get('/api/v1/store/banners',queryParams:{'active_only':true});
    return (d as List).map((e)=>StoreBanner.fromMap(Map<String,dynamic>.from(e))).toList();
  }
}
