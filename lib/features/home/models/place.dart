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
}
