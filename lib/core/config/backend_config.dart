class BackendConfig {
  /// FastAPI backend.
  static const String backendType =
      String.fromEnvironment(
        'REPOSITORY_BACKEND',
        defaultValue: 'fastapi',
      );

  /// Example: 'http://127.0.0.1:8000'
  static const String backendUrl =
      String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://10.14.102.24:8000',
      );

  /// Converts a relative media path (for example
  /// `/api/v1/media/community/<user_id>/<uuid>.webp`)
  /// into an absolute URL using [backendUrl].
  ///
  /// Absolute http(s) URLs are returned unchanged.
  static String? resolveMediaUrl(String? url) {
    if (url == null) {
      return null;
    }

    final trimmed = url.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }

    final backendUrl = BackendConfig.backendUrl.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    final normalizedPath = trimmed.replaceFirst(
      RegExp(r'^/+'),
      '',
    );

    if (normalizedPath.startsWith('api/v1/media/')) {
      return '$backendUrl/$normalizedPath';
    }

    return '$backendUrl/api/v1/media/$normalizedPath';
  }
}
