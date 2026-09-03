import '../../features/home/models/place.dart';

class PaginatedPlaces {
  final List<Place> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  const PaginatedPlaces({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  bool get hasNextPage => page < pages;
}

abstract class PlaceRepository {
  // ---------------------------------------------------------------------------
  // Existing list-based API
  // ---------------------------------------------------------------------------
  //
  // These methods remain List<Place> intentionally so existing screens such as
  // MapPage and PlacePickerPage are not broken.
  //

  Future<List<Place>> getPlaces();

  Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int limit = 50,
  });

  Future<Place?> getPlaceById(String id);

  Future<List<Place>> searchPlaces(String query);

  Future<List<Place>> getPlacesByCategory(String categoryId);

  Future<List<Place>> getOpenPlaces();

  Future<List<Place>> getHighestRatedPlaces({
    int limit = 10,
  });

  Future<List<Place>> getMostVisitedPlaces({
    int limit = 10,
  });

  // ---------------------------------------------------------------------------
  // Paginated API
  // ---------------------------------------------------------------------------
  //
  // These methods are used by ExplorePage for real pagination/infinite scroll.
  //

  Future<PaginatedPlaces> getPlacesPage({
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> getNearbyPlacesPage({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> searchPlacesPage(
    String query, {
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> getPlacesByCategoryPage(
    String categoryId, {
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> getOpenPlacesPage({
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> getHighestRatedPlacesPage({
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedPlaces> getMostVisitedPlacesPage({
    int page = 1,
    int limit = 20,
  });
}