import '../../features/home/models/place.dart';

abstract class PlaceRepository {
  Future<List<Place>> getPlaces();

  Future<Place?> getPlaceById(String id);

  Future<List<Place>> searchPlaces(String query);

  Future<List<Place>> getPlacesByCategory(String categoryId);

  Future<List<Place>> getOpenPlaces();

  Future<List<Place>> getHighestRatedPlaces({int limit = 10});

  Future<List<Place>> getMostVisitedPlaces({int limit = 10});
}
