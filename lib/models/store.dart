class StoreCategory {
  final String id, nameAr, nameEn;
  final String? descriptionAr, descriptionEn, iconUrl, imageUrl;
  final bool isActive;
  const StoreCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.iconUrl,
    this.imageUrl,
    required this.isActive,
  });
  factory StoreCategory.fromMap(Map<String, dynamic> m) => StoreCategory(
    id: m['id'].toString(),
    nameAr: m['name_ar']?.toString() ?? '',
    nameEn: m['name_en']?.toString() ?? '',
    descriptionAr: m['description_ar']?.toString(),
    descriptionEn: m['description_en']?.toString(),
    iconUrl: m['icon_url']?.toString(),
    imageUrl: m['image_url']?.toString(),
    isActive: m['is_active'] == true,
  );
}

class StoreItem {
  final String id, categoryId, nameAr, nameEn, itemType, currency;
  final String? descriptionAr, descriptionEn, imageUrl, assetId;
  final int price;
  final int? durationDays, ownershipDurationDays, stock;
  final DateTime? availableFrom, availableUntil;
  final bool isActive;
  const StoreItem({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    required this.itemType,
    required this.currency,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.assetId,
    required this.price,
    this.durationDays,
    this.ownershipDurationDays,
    this.availableFrom,
    this.availableUntil,
    this.stock,
    required this.isActive,
  });
  factory StoreItem.fromMap(Map<String, dynamic> m) => StoreItem(
    id: m['id'].toString(),
    categoryId: m['category_id'].toString(),
    nameAr: m['name_ar'] ?? '',
    nameEn: m['name_en'] ?? '',
    itemType: m['item_type']?.toString() ?? '',
    currency: m['currency']?.toString() ?? '',
    descriptionAr: m['description_ar']?.toString(),
    descriptionEn: m['description_en']?.toString(),
    imageUrl: m['image_url']?.toString(),
    assetId: m['asset_id']?.toString(),
    price: _int(m['price']),
    durationDays: _nullableInt(m['duration_days']),
    ownershipDurationDays: _nullableInt(m['ownership_duration_days']),
    availableFrom: _date(m['available_from']),
    availableUntil: _date(m['available_until']),
    stock: _nullableInt(m['stock']),
    isActive: m['is_active'] == true,
  );
}

class StorePurchase {
  final String id;
  final StoreItem item;
  final String currency;
  final int amount;
  final int ownedQuantity;
  final int balanceAfter;
  final DateTime? expiresAt;

  const StorePurchase({
    required this.id,
    required this.item,
    required this.currency,
    required this.amount,
    required this.ownedQuantity,
    required this.balanceAfter,
    required this.expiresAt,
  });

  factory StorePurchase.fromMap(Map<String, dynamic> m) => StorePurchase(
    id: m['id']?.toString() ?? '',
    item: StoreItem.fromMap(Map<String, dynamic>.from(m['item'] as Map)),
    currency: m['currency']?.toString() ?? '',
    amount: _int(m['amount']),
    ownedQuantity: _int(m['owned_quantity']),
    balanceAfter: _int(m['balance_after']),
    expiresAt: _date(m['expires_at']),
  );
}

class StoreOwnership {
  final StoreItem item;
  final int quantity;
  final DateTime? expiresAt;

  const StoreOwnership({
    required this.item,
    required this.quantity,
    required this.expiresAt,
  });

  factory StoreOwnership.fromMap(Map<String, dynamic> m) => StoreOwnership(
    item: StoreItem.fromMap(Map<String, dynamic>.from(m['item'] as Map)),
    quantity: _int(m['quantity']),
    expiresAt: _date(m['expires_at']),
  );
}

class StoreBanner {
  final String id, imageUrl;
  final String? titleAr, titleEn, targetUrl;
  const StoreBanner({
    required this.id,
    required this.imageUrl,
    this.titleAr,
    this.titleEn,
    this.targetUrl,
  });
  factory StoreBanner.fromMap(Map<String, dynamic> m) => StoreBanner(
    id: m['id'].toString(),
    imageUrl: m['image_url']?.toString() ?? '',
    titleAr: m['title_ar']?.toString(),
    titleEn: m['title_en']?.toString(),
    targetUrl: m['target_url']?.toString(),
  );
}

int _int(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
int? _nullableInt(dynamic v) => v == null ? null : _int(v);
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());
