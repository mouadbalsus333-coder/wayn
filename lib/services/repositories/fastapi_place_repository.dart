import '../../core/network/api_client.dart';
import '../../features/home/models/place.dart';
import 'place_repository.dart';

class FastApiPlaceRepository implements PlaceRepository {
  final ApiClient _apiClient;

  FastApiPlaceRepository(this._apiClient);

  // ---------------------------------------------------------------------------
  // Existing list-based API
  // ---------------------------------------------------------------------------

  @override
  Future<List<Place>> getPlaces() async {
    final response = await _apiClient.get(
      '/api/v1/places',
      queryParams: {
        'page': 1,
        'limit': 20,
      },
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
        'page': 1,
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
        'page': 1,
        'limit': 20,
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
      queryParams: {
        'page': 1,
        'limit': 20,
      },
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getOpenPlaces() async {
    final response = await _apiClient.get(
      '/api/v1/places/open',
      queryParams: {
        'page': 1,
        'limit': 20,
      },
    );

    return _placesFromResponse(response);
  }

  @override
  Future<List<Place>> getHighestRatedPlaces({
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/top-rated',
      queryParams: {
        'page': 1,
        'limit': limit,
      },
    );

    return _placesFromResponse(response).take(limit).toList();
  }

  @override
  Future<List<Place>> getMostVisitedPlaces({
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/most-visited',
      queryParams: {
        'page': 1,
        'limit': limit,
      },
    );

    return _placesFromResponse(response).take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Paginated API
  // ---------------------------------------------------------------------------

  @override
  Future<PaginatedPlaces> getPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places',
      queryParams: {
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> getNearbyPlacesPage({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/nearby',
      queryParams: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> searchPlacesPage(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final search = query.trim();

    if (search.isEmpty) {
      return getPlacesPage(
        page: page,
        limit: limit,
      );
    }

    final response = await _apiClient.get(
      '/api/v1/places/search',
      queryParams: {
        'q': search,
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> getPlacesByCategoryPage(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/category/$categoryId',
      queryParams: {
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> getOpenPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/open',
      queryParams: {
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> getHighestRatedPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/top-rated',
      queryParams: {
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PaginatedPlaces> getMostVisitedPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/places/most-visited',
      queryParams: {
        'page': page,
        'limit': limit,
      },
    );

    return _paginatedPlacesFromResponse(
      response,
      page: page,
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // Paginated response parsing
  // ---------------------------------------------------------------------------

  PaginatedPlaces _paginatedPlacesFromResponse(
    dynamic response, {
    required int page,
    required int limit,
  }) {
    if (response == null) {
      return PaginatedPlaces(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
        pages: 0,
      );
    }

    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        final parsedItems = _placesFromList(items);

        final total = _parseInt(
          response['total'],
          parsedItems.length,
        );

        final responsePage = _parseInt(
          response['page'],
          page,
        );

        final responseLimit = _parseInt(
          response['limit'],
          limit,
        );

        final pages = _parseInt(
          response['pages'],
          _calculatePages(
            total,
            responseLimit,
          ),
        );

        return PaginatedPlaces(
          items: parsedItems,
          total: total,
          page: responsePage,
          limit: responseLimit,
          pages: pages,
        );
      }

      return PaginatedPlaces(
        items: const [],
        total: 0,
        page: page,
        limit: limit,
        pages: 0,
      );
    }

    if (response is List) {
      final parsedItems = _placesFromList(response);

      return PaginatedPlaces(
        items: parsedItems,
        total: parsedItems.length,
        page: page,
        limit: limit,
        pages: parsedItems.isEmpty ? 0 : 1,
      );
    }

    return PaginatedPlaces(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
      pages: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // List response parsing
  // ---------------------------------------------------------------------------

  List<Place> _placesFromResponse(dynamic response) {
    if (response == null) {
      return [];
    }

    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        return _placesFromList(items);
      }

      return [];
    }

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

  // ---------------------------------------------------------------------------
  // Pagination helpers
  // ---------------------------------------------------------------------------

  int _parseInt(
    dynamic value,
    int fallback,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  int _calculatePages(
    int total,
    int limit,
  ) {
    if (total <= 0 || limit <= 0) {
      return 0;
    }

    return (total + limit - 1) ~/ limit;
  }
}