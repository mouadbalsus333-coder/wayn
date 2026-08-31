import '../../core/network/api_client.dart';
import '../../features/home/models/place.dart';
import 'place_repository.dart';

class FastApiPlaceRepository implements PlaceRepository {
  final ApiClient _apiClient;

  FastApiPlaceRepository(this._apiClient);

  @override
  Future<List<Place>> getPlaces() async {
    final response = await _apiClient.get(
      '/api/v1/places',
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int limit = 50,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/nearby',
      queryParams: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'limit': limit,
      },
    );

    return _placesFromResponse(response);
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/places/$id',
      );

      if (response == null || response is! Map) {
        return null;
      }

      return Place.fromMap(
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
      queryParams: {
        'q': search,
      },
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getPlacesByCategory(
    String categoryId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/places/category/$categoryId',
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getOpenPlaces() async {
    final response = await _apiClient.get(
      '/api/v1/places/open',
    );

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

  // ===============================================================
  // RESPONSE PARSING
  // ===============================================================

  List<Place> _placesFromResponse(dynamic response) {
    if (response == null) {
      return [];
    }

    // PaginatedResponse:
    //
    // {
    //   "items": [...],
    //   "total": 100,
    //   "page": 1,
    //   "limit": 50,
    //   "pages": 2
    // }
    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        return _placesFromList(items);
      }

      return [];
    }

    // Direct list response:
    //
    // [
    //   {...},
    //   {...}
    // ]
    if (response is List) {
      return _placesFromList(response);
    }

    return [];
  }

  List<Place> _placesFromList(List<dynamic> items) {
    final places = <Place>[];

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      try {
        places.add(
          Place.fromMap(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        // Ignore malformed place objects instead of
        // breaking the entire places response.
        continue;
      }
    }

    return places;
  }
}