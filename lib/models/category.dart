class Category {
  final String id;
  final String nameAr;
  final String? nameEn;
  final String? icon;
  final int sortOrder;

  const Category({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.icon,
    required this.sortOrder,
  });

  factory Category.fromMap(Map<String, dynamic> data) {
    return Category(
      id: data['id'].toString(),
      nameAr: data['name_ar']?.toString() ?? '',
      nameEn: data['name_en']?.toString(),
      icon: data['icon']?.toString(),
      sortOrder: (data['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
