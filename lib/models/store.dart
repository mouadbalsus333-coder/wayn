
class StoreCategory {
  final String id,nameAr,nameEn;
  final String? descriptionAr,descriptionEn,iconUrl,imageUrl;
  final bool isActive;
  const StoreCategory({required this.id,required this.nameAr,required this.nameEn,
    this.descriptionAr,this.descriptionEn,this.iconUrl,this.imageUrl,required this.isActive});
  factory StoreCategory.fromMap(Map<String,dynamic> m)=>StoreCategory(
    id:m['id'].toString(),nameAr:m['name_ar']?.toString()??'',nameEn:m['name_en']?.toString()??'',
    descriptionAr:m['description_ar']?.toString(),descriptionEn:m['description_en']?.toString(),
    iconUrl:m['icon_url']?.toString(),imageUrl:m['image_url']?.toString(),
    isActive:m['is_active'] == true);
}
class StoreItem {
  final String id,categoryId,nameAr,nameEn,itemType,currency;
  final String? descriptionAr,descriptionEn,imageUrl,assetId;
  final int price;
  final int? durationDays,stock;
  final bool isActive;
  const StoreItem({required this.id,required this.categoryId,required this.nameAr,required this.nameEn,
    required this.itemType,required this.currency,this.descriptionAr,this.descriptionEn,this.imageUrl,
    this.assetId,required this.price,this.durationDays,this.stock,required this.isActive});
  factory StoreItem.fromMap(Map<String,dynamic> m)=>StoreItem(
    id:m['id'].toString(),categoryId:m['category_id'].toString(),nameAr:m['name_ar']??'',
    nameEn:m['name_en']??'',itemType:m['item_type']?.toString()??'',currency:m['currency']?.toString()??'',
    descriptionAr:m['description_ar']?.toString(),descriptionEn:m['description_en']?.toString(),
    imageUrl:m['image_url']?.toString(),assetId:m['asset_id']?.toString(),price:_int(m['price']),
    durationDays:_nullableInt(m['duration_days']),stock:_nullableInt(m['stock']),isActive:m['is_active']==true);
}
class StoreBanner {
  final String id,imageUrl;
  final String? titleAr,titleEn,targetUrl;
  const StoreBanner({required this.id,required this.imageUrl,this.titleAr,this.titleEn,this.targetUrl});
  factory StoreBanner.fromMap(Map<String,dynamic> m)=>StoreBanner(
    id:m['id'].toString(),imageUrl:m['image_url']?.toString()??'',
    titleAr:m['title_ar']?.toString(),titleEn:m['title_en']?.toString(),targetUrl:m['target_url']?.toString());
}
int _int(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??'')??0;
int? _nullableInt(dynamic v)=>v==null?null:_int(v);
