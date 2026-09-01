import '../../core/config/backend_config.dart';
import '../../core/network/dart_http_api_client.dart';

import '../../features/community/repositories/community_repository.dart';

import 'auth_repository.dart';
import 'category_repository.dart';
import 'contribution_repository.dart';
import 'place_repository.dart';
import 'point_transaction_repository.dart';
import 'social_repository.dart';
import 'task_repository.dart';
import 'user_repository.dart';

import 'fastapi_auth_repository.dart';
import 'fastapi_category_repository.dart';
import 'fastapi_contribution_repository.dart';
import 'fastapi_place_repository.dart';
import 'fastapi_social_repository.dart';
import 'fastapi_user_repository.dart';

final DartHttpApiClient _fastApiClient = DartHttpApiClient(
  baseUrl: BackendConfig.backendUrl,
);

// ============================================================
// AuthRepository
// ============================================================

AuthRepository createAuthRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiAuthRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// SocialRepository (follows + notifications)
// ============================================================

SocialRepository createSocialRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiSocialRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// PlaceRepository
// ============================================================

PlaceRepository createPlaceRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiPlaceRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// CategoryRepository
// ============================================================

CategoryRepository createCategoryRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiCategoryRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// UserRepository
// ============================================================

UserRepository createUserRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiUserRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// CommunityRepository
// ============================================================

CommunityRepository createCommunityRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return CommunityRepository(_fastApiClient);

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// TaskRepository
// ============================================================

TaskRepository createTaskRepository() {
  throw UnimplementedError(
    'FastAPI TaskRepository has not been implemented yet.',
  );
}

// ============================================================
// ContributionRepository
// ============================================================

ContributionRepository createContributionRepository() {
  switch (BackendConfig.backendType) {
    case 'fastapi':
      return FastApiContributionRepository(
        _fastApiClient,
      );

    default:
      throw UnsupportedError(
        'Unsupported repository backend: '
        '${BackendConfig.backendType}',
      );
  }
}

// ============================================================
// PointTransactionRepository
// ============================================================

PointTransactionRepository createPointTransactionRepository() {
  throw UnimplementedError(
    'FastAPI PointTransactionRepository has not been implemented yet.',
  );
}
