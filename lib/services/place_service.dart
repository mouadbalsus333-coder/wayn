import '../features/home/models/place.dart';
import 'repositories/place_repository.dart';
import 'repositories/repository_factory.dart';

class PlaceService {
  final PlaceRepository _placeRepository;

  PlaceService({PlaceRepository? placeRepository})
    : _placeRepository = placeRepository ?? createPlaceRepository();

  // ===============================================================
  // GET ALL ACTIVE PLACES
  // ===============================================================

  Future<List<Place>> getPlaces() async {
    return _placeRepository.getPlaces();
  }

  // ===============================================================
  // GET PLACE BY ID
  // ===============================================================

  Future<Place?> getPlaceById(String id) async {
    return _placeRepository.getPlaceById(id);
  }

  // ===============================================================
  // SEARCH PLACES
  // ===============================================================

  Future<List<Place>> searchPlaces(String query) async {
    return _placeRepository.searchPlaces(query);
  }

  // ===============================================================
  // GET PLACES BY CATEGORY
  // ===============================================================

  Future<List<Place>> getPlacesByCategory(String categoryId) async {
    return _placeRepository.getPlacesByCategory(categoryId);
  }

  // ===============================================================
  // GET OPEN PLACES
  // ===============================================================

  Future<List<Place>> getOpenPlaces() async {
    return _placeRepository.getOpenPlaces();
  }

  // ===============================================================
  // GET HIGHEST RATED PLACES
  // ===============================================================

  Future<List<Place>> getHighestRatedPlaces({int limit = 10}) async {
    return _placeRepository.getHighestRatedPlaces(limit: limit);
  }

  // ===============================================================
  // GET MOST VISITED PLACES
  // ===============================================================

  Future<List<Place>> getMostVisitedPlaces({int limit = 10}) async {
    return _placeRepository.getMostVisitedPlaces(limit: limit);
  }
}
