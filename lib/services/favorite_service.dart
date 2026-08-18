
import '../core/network/wayn_api.dart';
import '../features/home/models/place.dart';
class FavoriteService {
  Future<bool> check(String id) async {
    final d=await waynApi.get('/api/v1/favorites/$id/check');
    if(d is bool)return d;
    if(d is Map)return d['is_favorite']==true || d['favorite']==true;
    return false;
  }
  Future<void> add(String id) async { await waynApi.post('/api/v1/favorites/$id'); }
  Future<void> remove(String id) async { await waynApi.delete('/api/v1/favorites/$id'); }
  Future<List<Place>> list() async {
    final d=await waynApi.get('/api/v1/favorites');
    return (d as List).map((e)=>Place.fromMap(Map<String,dynamic>.from(e))).toList();
  }
}
