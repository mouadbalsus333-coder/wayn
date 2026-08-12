import '../../core/config/backend_config.dart';
import '../../core/network/dart_http_api_client.dart';

import 'supabase_category_repository.dart';
import 'supabase_contribution_repository.dart';
import 'supabase_place_repository.dart';
import 'supabase_point_transaction_repository.dart';
import 'supabase_task_repository.dart';
import 'supabase_user_repository.dart';

import 'fastapi_category_repository.dart';
import 'fastapi_place_repository.dart';

import 'category_repository.dart';
import 'contribution_repository.dart';
import 'place_repository.dart';
import 'point_transaction_repository.dart';
import 'task_repository.dart';
import 'user_repository.dart';

final DartHttpApiClient _fastApiClient = DartHttpApiClient(
  baseUrl: BackendConfig.backendUrl,
);

PlaceRepository createPlaceRepository() {
  if (BackendConfig.backendType == 'fastapi') {
    return FastApiPlaceRepository(_fastApiClient);
  }

  return SupabasePlaceRepository();
}

CategoryRepository createCategoryRepository() {
  if (BackendConfig.backendType == 'fastapi') {
    return FastApiCategoryRepository(_fastApiClient);
  }

  return SupabaseCategoryRepository();
}

UserRepository createUserRepository() => SupabaseUserRepository();

TaskRepository createTaskRepository() => SupabaseTaskRepository();

ContributionRepository createContributionRepository() =>
    SupabaseContributionRepository();

PointTransactionRepository createPointTransactionRepository() =>
    SupabasePointTransactionRepository();