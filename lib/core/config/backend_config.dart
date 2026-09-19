class BackendConfig {
  /// FastAPI backend.
  static const String backendType =
      String.fromEnvironment(
        'REPOSITORY_BACKEND',
        defaultValue: 'fastapi',
      );

  /// Example: 'http://127.0.0.1:8000'
  ///
  /// NOTE: this must match the machine that is actually running the
  /// FastAPI backend. A stale LAN IP here makes the app talk to a
  /// dead/old server, so posts can appear to be created while the
  /// community feed reads from a different (stale) backend instance.
  ///
  /// Override per run with:
  ///   --dart-define=BACKEND_URL=http://`your-lan-ip`:8000
  /// (use your machine's LAN IP for physical Android/iOS devices, or
  ///  `adb reverse tcp:8000 tcp:8000` with 127.0.0.1 for emulators).
  static const String backendUrl =
      String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://127.0.0.1:8000',
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
