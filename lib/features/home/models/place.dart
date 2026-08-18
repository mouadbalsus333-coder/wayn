class Place {
  final String id;
  final String? categoryId;
  final String name;
  final String city;
  final String category;
  final String imageUrl;

  final double rating;
  final bool isOpen;

  final String? description;
  final String? address;
  final String? phone;
  final String? website;

  final double? latitude;
  final double? longitude;

  final List<String> images;
  final List<String> services;

  final String? openingTime;
  final String? closingTime;

  final int reviewsCount;
  final int visitsCount;

  const Place({
    required this.id,
    this.categoryId,
    required this.name,
    required this.city,
    required this.category,
    required this.imageUrl,
    required this.rating,
    required this.isOpen,

    this.description,
    this.address,
    this.phone,
    this.website,

    this.latitude,
    this.longitude,

    this.images = const [],
    this.services = const [],

    this.openingTime,
    this.closingTime,

    this.reviewsCount = 0,
    this.visitsCount = 0,
  });
  factory Place.fromMap(Map<String, dynamic> data) {
    double? d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    bool b(dynamic v) => v == true || v?.toString().toLowerCase() == 'true';
    List<String> list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    return Place(
      id: data['id']?.toString() ?? '',
      categoryId: data['category_id']?.toString(),
      name: data['name']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      category: data['category_name']?.toString() ?? '',
      imageUrl: data['image_url']?.toString() ?? '',
      rating: d(data['rating']) ?? 0,
      isOpen: b(data['is_open']),
      description: data['description']?.toString(),
      address: data['address']?.toString(),
      phone: data['phone']?.toString(),
      website: data['website']?.toString(),
      latitude: d(data['latitude']),
      longitude: d(data['longitude']),
      images: list(data['images']),
      services: list(data['services']),
      openingTime: data['opening_time']?.toString(),
      closingTime: data['closing_time']?.toString(),
      reviewsCount: i(data['reviews_count']),
      visitsCount: i(data['visits_count']),
    );
  }

}
