class BackendConfig {
  /// 'fastapi' (default) or 'supabase'
  static const String backendType =
      String.fromEnvironment(
        'REPOSITORY_BACKEND',
        defaultValue: 'fastapi',
      );

  /// Example: 'http://127.0.0.1:8000'
  static const String backendUrl =
      String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://127.0.0.1:8000',
      );
}
