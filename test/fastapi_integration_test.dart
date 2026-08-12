import 'package:flutter_test/flutter_test.dart';
import 'package:wayn/services/repositories/repository_factory.dart';

void main() {
  test('FastAPI Category Repository Integration Test', () async {
    final categoryRepo = createCategoryRepository();
    final result = await categoryRepo.getCategories();
    print('Category Result Status: ${result.status}');
    print('Categories Count: ${result.categories.length}');
    expect(result.categories, isNotNull);
  });

  test('FastAPI Place Repository Integration Test', () async {
    final placeRepo = createPlaceRepository();

    final places = await placeRepo.getPlaces();
    print('Places Count: ${places.length}');
    expect(places, isNotNull);

    final topRated = await placeRepo.getHighestRatedPlaces();
    print('Top Rated Count: ${topRated.length}');
    expect(topRated, isNotNull);

    final mostVisited = await placeRepo.getMostVisitedPlaces();
    print('Most Visited Count: ${mostVisited.length}');
    expect(mostVisited, isNotNull);

    final searchResults = await placeRepo.searchPlaces('test');
    print('Search Count: ${searchResults.length}');
    expect(searchResults, isNotNull);
  });
}
