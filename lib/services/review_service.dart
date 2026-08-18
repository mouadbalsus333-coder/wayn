
import '../core/network/wayn_api.dart';
class ReviewData {
  final String id,userId,placeId; final double rating; final String? comment; final List<String> images;
  ReviewData({required this.id,required this.userId,required this.placeId,required this.rating,this.comment,this.images=const[]});
  factory ReviewData.fromMap(Map<String,dynamic> m)=>ReviewData(id:m['id'].toString(),userId:m['user_id'].toString(),
    placeId:m['place_id'].toString(),rating:(m['rating'] as num?)?.toDouble()??0,comment:m['comment']?.toString(),
    images:(m['images'] as List? ?? const[]).map((e)=>e.toString()).toList());
}
class ReviewService {
  Future<List<ReviewData>> list(String placeId) async {
    final d=await waynApi.get('/api/v1/places/$placeId/reviews');
    return (d as List).map((e)=>ReviewData.fromMap(Map<String,dynamic>.from(e))).toList();
  }
  Future<ReviewData> create(String id,double rating,String comment) async =>
    ReviewData.fromMap(Map<String,dynamic>.from(await waynApi.post('/api/v1/places/$id/reviews',body:{'rating':rating,'comment':comment,'images':[]})));
}
