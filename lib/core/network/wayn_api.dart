
import '../config/backend_config.dart';
import 'dart_http_api_client.dart';

/// Shared authenticated API client used by the user-facing UI.
final DartHttpApiClient waynApi = DartHttpApiClient(
  baseUrl: BackendConfig.backendUrl,
);

/// Separate client for the admin session so an admin login never replaces
/// the normal user's JWT.
final DartHttpApiClient waynAdminApi = DartHttpApiClient(
  baseUrl: BackendConfig.backendUrl,
  tokenStorageKey: 'wayn_admin_access_token',
);
