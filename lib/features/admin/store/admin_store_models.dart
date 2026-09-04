class AdminStoreCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? iconUrl;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  const AdminStoreCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.iconUrl,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminStoreCategory.fromMap(Map<String, dynamic> map) {
    return AdminStoreCategory(
      id: map['id']?.toString() ?? '',
      nameAr: map['name_ar']?.toString() ?? '',
      nameEn: map['name_en']?.toString() ?? '',
      descriptionAr: map['description_ar']?.toString(),
      descriptionEn: map['description_en']?.toString(),
      iconUrl: map['icon_url']?.toString(),
      imageUrl: map['image_url']?.toString(),
      sortOrder: _int(map['sort_order']),
      isActive: map['is_active'] == true,
    );
  }
}

class AdminStoreItem {
  final String id;
  final String categoryId;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String itemType;
  final String currency;
  final int price;
  final String? imageUrl;
  final String? assetId;
  final int? availableFrom;
  final int? availableUntil;
  final int? ownershipDurationDays;
  final int? stock;
  final int sortOrder;
  final bool isActive;

  const AdminStoreItem({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.itemType,
    required this.currency,
    required this.price,
    this.imageUrl,
    this.assetId,
    this.availableFrom,
    this.availableUntil,
    this.ownershipDurationDays,
    this.stock,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminStoreItem.fromMap(Map<String, dynamic> map) {
    return AdminStoreItem(
      id: map['id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      nameAr: map['name_ar']?.toString() ?? '',
      nameEn: map['name_en']?.toString() ?? '',
      descriptionAr: map['description_ar']?.toString(),
      descriptionEn: map['description_en']?.toString(),
      itemType: map['item_type']?.toString() ?? 'OTHER',
      currency: map['currency']?.toString() ?? 'COINS',
      price: _int(map['price']),
      imageUrl: map['image_url']?.toString(),
      assetId: map['asset_id']?.toString(),
      availableFrom: _dateMillis(map['available_from']),
      availableUntil: _dateMillis(map['available_until']),
      ownershipDurationDays: _nullableInt(map['ownership_duration_days']),
      stock: _nullableInt(map['stock']),
      sortOrder: _int(map['sort_order']),
      isActive: map['is_active'] == true,
    );
  }

  DateTime? get availableFromDate => availableFrom == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(availableFrom!);

  DateTime? get availableUntilDate => availableUntil == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(availableUntil!);
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

int? _nullableInt(dynamic value) => value == null ? null : _int(value);

int? _dateMillis(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.millisecondsSinceEpoch;
}
