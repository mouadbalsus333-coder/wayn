import 'package:flutter_test/flutter_test.dart';
import 'package:wayn/core/config/backend_config.dart';
import 'package:wayn/core/network/dart_http_api_client.dart';
import 'package:wayn/services/repositories/fastapi_category_repository.dart';
import 'package:wayn/services/repositories/fastapi_place_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DartHttpApiClient apiClient;
  late FastApiCategoryRepository categoryRepository;
  late FastApiPlaceRepository placeRepository;

  setUp(() {
    apiClient = DartHttpApiClient(
      baseUrl: BackendConfig.backendUrl,
      secureStorage: InMemoryAuthTokenStorage(),
    );

    categoryRepository = FastApiCategoryRepository(apiClient);
    placeRepository = FastApiPlaceRepository(apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  test(
    'FastAPI Category Repository Integration Test',
    () async {
      final result = await categoryRepository.getCategories();

      expect(
        result.categories,
        isNotNull,
      );
    },
  );

  test(
    'FastAPI Place Repository Integration Test',
    () async {
      final places = await placeRepository.getPlaces();

      expect(
        places,
        isNotNull,
      );

      final topRatedPlaces =
          await placeRepository.getHighestRatedPlaces();

      expect(
        topRatedPlaces,
        isNotNull,
      );

      final mostVisitedPlaces =
          await placeRepository.getMostVisitedPlaces();

      expect(
        mostVisitedPlaces,
        isNotNull,
      );

      final searchResults =
          await placeRepository.searchPlaces('test');

      expect(
        searchResults,
        isNotNull,
      );
    },
  );
}