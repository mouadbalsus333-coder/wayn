import '../../core/network/api_client.dart';
import '../../features/home/models/place.dart';
import 'place_repository.dart';

class FastApiPlaceRepository implements PlaceRepository {
  final ApiClient _apiClient;

  FastApiPlaceRepository(this._apiClient);

  @override
  Future<List<Place>> getPlaces() async {
    final response = await _apiClient.get('/api/v1/places');
    return _placesFromResponse(response);
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    try {
      final response = await _apiClient.get('/api/v1/places/$id');

      if (response == null || response is! Map) {
        return null;
      }

      return _placeFromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  @override
  Future<List<Place>> searchPlaces(String query) async {
    final search = query.trim();

    if (search.isEmpty) {
      return getPlaces();
    }

    final response = await _apiClient.get(
      '/api/v1/places/search',
      queryParams: {'q': search},
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getPlacesByCategory(String categoryId) async {
    final response = await _apiClient.get(
      '/api/v1/places/category/$categoryId',
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getOpenPlaces() async {
    final response = await _apiClient.get('/api/v1/places/open');

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getHighestRatedPlaces({
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/top-rated',
    );

    final places = _placesFromResponse(response);

    return places.take(limit).toList();
  }

  @override
  Future<List<Place>> getMostVisitedPlaces({
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/most-visited',
    );

    final places = _placesFromResponse(response);

    return places.take(limit).toList();
  }

  List<Place> _placesFromResponse(dynamic response) {
    // The new API contract returns a PaginatedResponse object:
    // { "items": [...], "total": n, "page": n, "limit": n, "pages": n }
    // Extract the items list from the response.
    if (response == null) {
      return [];
    }

    if (response is Map) {
      final items = response['items'];
      if (items is List) {
        return items
            .map(
              (item) => _placeFromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    }

    if (response is List) {
      return response
          .map(
            (item) => _placeFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }

    return [];
  }

  Place _placeFromMap(Map<String, dynamic> data) {
    return Place(
      id: _stringValue(data['id']),
      categoryId: _nullableString(data['category_id']),
      name: _stringValue(data['name']),
      city: _stringValue(data['city']),

      // FastAPI يستخدم category_name
      // بينما Flutter Place يستخدم category.
      category: _stringValue(data['category_name']),

      imageUrl: _stringValue(data['image_url']),
      rating: _doubleValue(data['rating']),
      isOpen: _boolValue(data['is_open']),

      description: _nullableString(data['description']),
      address: _nullableString(data['address']),
      phone: _nullableString(data['phone']),
      website: _nullableString(data['website']),

      latitude: _nullableDouble(data['latitude']),
      longitude: _nullableDouble(data['longitude']),

      images: _stringList(data['images']),
      services: _stringList(data['services']),

      openingTime: _timeValue(data['opening_time']),
      closingTime: _timeValue(data['closing_time']),

      reviewsCount: _intValue(data['reviews_count']),
      visitsCount: _intValue(data['visits_count']),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  double _doubleValue(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
    }

    return false;
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  String? _timeValue(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return [];
  }
}