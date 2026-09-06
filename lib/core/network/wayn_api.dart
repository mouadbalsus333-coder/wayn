
import '../config/backend_config.dart';
import 'dart_http_api_client.dart';

/// Shared authenticated API client used by the user-facing UI.
final DartHttpApiClient waynApi = DartHttpApiClient(
  baseUrl: BackendConfig.backendUrl,
);
