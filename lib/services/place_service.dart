import '../features/home/models/place.dart';
import 'repositories/place_repository.dart';
import 'repositories/repository_factory.dart';

class PlaceService {
  final PlaceRepository _placeRepository;

  PlaceService({
    PlaceRepository? placeRepository,
  }) : _placeRepository =
            placeRepository ?? createPlaceRepository();

  // ===============================================================
  // EXISTING LIST-BASED API
  // ===============================================================
  //
  // These methods are kept for existing screens such as MapPage
  // and PlacePickerPage.
  //

  Future<List<Place>> getPlaces() async {
    return _placeRepository.getPlaces();
  }

  Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int limit = 50,
  }) async {
    return _placeRepository.getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      limit: limit,
    );
  }

  Future<Place?> getPlaceById(String id) async {
    return _placeRepository.getPlaceById(id);
  }

  Future<List<Place>> searchPlaces(String query) async {
    return _placeRepository.searchPlaces(query);
  }

  Future<List<Place>> getPlacesByCategory(
    String categoryId,
  ) async {
    return _placeRepository.getPlacesByCategory(categoryId);
  }

  Future<List<Place>> getOpenPlaces() async {
    return _placeRepository.getOpenPlaces();
  }

  Future<List<Place>> getHighestRatedPlaces({
    int limit = 10,
  }) async {
    return _placeRepository.getHighestRatedPlaces(
      limit: limit,
    );
  }

  Future<List<Place>> getMostVisitedPlaces({
    int limit = 10,
  }) async {
    return _placeRepository.getMostVisitedPlaces(
      limit: limit,
    );
  }

  // ===============================================================
  // PAGINATED API
  // ===============================================================
  //
  // These methods are used by ExplorePage for real pagination.
  //

  Future<PaginatedPlaces> getPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getPlacesPage(
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> getNearbyPlacesPage({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getNearbyPlacesPage(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> searchPlacesPage(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.searchPlacesPage(
      query,
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> getPlacesByCategoryPage(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getPlacesByCategoryPage(
      categoryId,
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> getOpenPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getOpenPlacesPage(
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> getHighestRatedPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getHighestRatedPlacesPage(
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedPlaces> getMostVisitedPlacesPage({
    int page = 1,
    int limit = 20,
  }) async {
    return _placeRepository.getMostVisitedPlacesPage(
      page: page,
      limit: limit,
    );
  }
}