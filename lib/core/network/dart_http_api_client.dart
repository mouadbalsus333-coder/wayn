import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Abstraction over secure token storage.
abstract class AuthTokenStorage {
  Future<void> write({
    required String key,
    required String value,
  });

  Future<String?> read({
    required String key,
  });

  Future<void> delete({
    required String key,
  });
}

/// Production implementation backed by flutter_secure_storage.
class SecureAuthTokenStorage implements AuthTokenStorage {
  final FlutterSecureStorage _storage;

  SecureAuthTokenStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(
      key: key,
      value: value,
    );
  }

  @override
  Future<String?> read({
    required String key,
  }) {
    return _storage.read(
      key: key,
    );
  }

  @override
  Future<void> delete({
    required String key,
  }) {
    return _storage.delete(
      key: key,
    );
  }
}

/// Simple in-memory storage useful for tests.
class InMemoryAuthTokenStorage implements AuthTokenStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    _values.remove(key);
  }
}

class _CachedResponse {
  final dynamic data;
  final DateTime expiresAt;

  const _CachedResponse({
    required this.data,
    required this.expiresAt,
  });

  bool get isValid {
    return DateTime.now().isBefore(expiresAt);
  }
}

class DartHttpApiClient implements ApiClient {
  @override
  final String baseUrl;

  @override
  final Map<String, String> defaultHeaders;

  final http.Client _client;
  final AuthTokenStorage _secureStorage;

  final String tokenStorageKey;

  // ============================================================
  // GET Cache
  // ============================================================

  static const Duration _getCacheDuration = Duration(
    seconds: 15,
  );

  static const int _maxCacheEntries = 50;

  final Map<String, _CachedResponse> _getCache =
      <String, _CachedResponse>{};

  DartHttpApiClient({
    required this.baseUrl,
    Map<String, String>? defaultHeaders,
    http.Client? client,
    AuthTokenStorage? secureStorage,
    this.tokenStorageKey = 'wayn_access_token',
  })  : defaultHeaders = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?defaultHeaders,
        },
        _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? SecureAuthTokenStorage();

  // ============================================================
  // Authentication
  // ============================================================

  Future<void> setAuthToken(String token) async {
    final trimmedToken = token.trim();

    if (trimmedToken.isEmpty) {
      print('WAYN AUTH: received empty token');
      await clearAuthToken();
      return;
    }

    await _secureStorage.write(
      key: tokenStorageKey,
      value: trimmedToken,
    );

    // Auth state changed, so user-specific GET cache must not
    // survive the authentication transition.
    _clearGetCache();

    print(
      'WAYN AUTH: access token saved successfully '
      '(length: ${trimmedToken.length})',
    );
  }

  Future<String?> getAuthToken() async {
    final token = await _secureStorage.read(
      key: tokenStorageKey,
    );

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  Future<void> clearAuthToken() async {
    await _secureStorage.delete(
      key: tokenStorageKey,
    );

    // Prevent cached authenticated data from being reused
    // after logout.
    _clearGetCache();

    print('WAYN AUTH: access token cleared');
  }

  Future<bool> hasAuthToken() async {
    final token = await getAuthToken();

    return token != null && token.isNotEmpty;
  }

  // ============================================================
  // GET
  // ============================================================

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, queryParams),
    );

    final cacheKey = uri.toString();

    if (_isCacheableGet(path)) {
      final cached = _getCache[cacheKey];

      if (cached != null) {
        if (cached.isValid) {
          print(
            'WAYN HTTP CACHE HIT: GET $uri',
          );

          return cached.data;
        }

        _getCache.remove(cacheKey);
      }
    }

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.get(
      uri,
      headers: requestHeaders,
    );

    final result = _handleResponse(response);

    if (_isCacheableGet(path)) {
      _storeGetCache(
        cacheKey,
        result,
      );
    }

    return result;
  }

  // ============================================================
  // POST
  // ============================================================

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.post(
      uri,
      headers: requestHeaders,
      body: jsonEncode(
        body ?? <String, dynamic>{},
      ),
    );

    final result = _handleResponse(response);

    _invalidateCacheForPath(path);

    return result;
  }

  // ============================================================
  // PUT
  // ============================================================

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.put(
      uri,
      headers: requestHeaders,
      body: jsonEncode(
        body ?? <String, dynamic>{},
      ),
    );

    final result = _handleResponse(response);

    _invalidateCacheForPath(path);

    return result;
  }

  // ============================================================
  // PATCH
  // ============================================================

  @override
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.patch(
      uri,
      headers: requestHeaders,
      body: jsonEncode(
        body ?? <String, dynamic>{},
      ),
    );

    final result = _handleResponse(response);

    _invalidateCacheForPath(path);

    return result;
  }

  // ============================================================
  // DELETE
  // ============================================================

  @override
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.delete(
      uri,
      headers: requestHeaders,
      body: body == null ? null : jsonEncode(body),
    );

    final result = _handleResponse(response);

    _invalidateCacheForPath(path);

    return result;
  }

  // ============================================================
  // FILE UPLOAD
  // ============================================================

  @override
  Future<dynamic> uploadFile(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fieldName = 'file',
    String? contentType,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    if (fileBytes.isEmpty) {
      throw ApiClientException(
        'Cannot upload an empty file',
      );
    }

    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    final requestHeaders = await _buildHeaders(headers);

    // MultipartRequest generates its own Content-Type header
    // including the required boundary.
    requestHeaders.remove('Content-Type');
    requestHeaders.remove('content-type');

    request.headers.addAll(requestHeaders);

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
      ),
    );

    print(
      'WAYN HTTP UPLOAD: POST $uri',
    );

    print(
      'WAYN HTTP UPLOAD FILE: $fileName '
      '(${fileBytes.length} bytes)',
    );

    if (contentType != null && contentType.trim().isNotEmpty) {
      print(
        'WAYN HTTP UPLOAD CONTENT TYPE: $contentType',
      );
    }

    final streamedResponse = await _client.send(
      request,
    );

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    final result = _handleResponse(response);

    _invalidateCacheForPath(path);

    return result;
  }

  // ============================================================
  // Cache
  // ============================================================

  bool _isCacheableGet(String path) {
    final normalizedPath = path.startsWith('/')
        ? path
        : '/$path';

    // Only cache public/read-heavy place and category data.
    //
    // We intentionally do NOT cache:
    // - notifications
    // - profile/user endpoints
    // - community feeds
    // - favorites
    // - wallet
    // - reviews
    // - authentication endpoints
    //
    // This keeps user-specific and frequently changing data
    // fresh while reducing repeated requests for directory data.
    return normalizedPath == '/api/v1/categories' ||
        normalizedPath.startsWith('/api/v1/categories/') ||
        normalizedPath == '/api/v1/places' ||
        normalizedPath.startsWith('/api/v1/places/');
  }

  void _storeGetCache(
    String key,
    dynamic data,
  ) {
    if (_getCache.length >= _maxCacheEntries) {
      _removeOldestCacheEntry();
    }

    _getCache[key] = _CachedResponse(
      data: data,
      expiresAt: DateTime.now().add(
        _getCacheDuration,
      ),
    );

    print(
      'WAYN HTTP CACHE STORE: $key '
      '(TTL: ${_getCacheDuration.inSeconds}s)',
    );
  }

  void _removeOldestCacheEntry() {
    if (_getCache.isEmpty) {
      return;
    }

    String? oldestKey;
    DateTime? oldestExpiry;

    for (final entry in _getCache.entries) {
      if (oldestExpiry == null ||
          entry.value.expiresAt.isBefore(oldestExpiry)) {
        oldestKey = entry.key;
        oldestExpiry = entry.value.expiresAt;
      }
    }

    if (oldestKey != null) {
      _getCache.remove(oldestKey);
    }
  }

  void _clearGetCache() {
    if (_getCache.isEmpty) {
      return;
    }

    _getCache.clear();

    print('WAYN HTTP CACHE: cleared');
  }

  void _invalidateCacheForPath(String path) {
    if (!_isCacheableGet(path)) {
      return;
    }

    final normalizedPath = path.startsWith('/')
        ? path
        : '/$path';

    final keysToRemove = _getCache.keys.where((key) {
      final uri = Uri.tryParse(key);

      if (uri == null) {
        return false;
      }

      final requestPath = uri.path;

      if (normalizedPath == '/api/v1/places') {
        return requestPath == '/api/v1/places' ||
            requestPath.startsWith('/api/v1/places/');
      }

      if (normalizedPath.startsWith('/api/v1/categories')) {
        return requestPath == '/api/v1/categories' ||
            requestPath.startsWith('/api/v1/categories/');
      }

      return false;
    }).toList();

    for (final key in keysToRemove) {
      _getCache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      print(
        'WAYN HTTP CACHE: invalidated '
        '${keysToRemove.length} entr${keysToRemove.length == 1 ? 'y' : 'ies'}',
      );
    }
  }

  // ============================================================
  // Headers
  // ============================================================

  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? headers,
  ) async {
    final token = await getAuthToken();

    final result = <String, String>{
      ...defaultHeaders,
      ...?headers,
    };

    if (token != null && token.isNotEmpty) {
      result['Authorization'] = 'Bearer $token';
    }

    return result;
  }

  // ============================================================
  // URL
  // ============================================================

  String _buildUrl(
    String path,
    Map<String, dynamic>? query,
  ) {
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(
            0,
            baseUrl.length - 1,
          )
        : baseUrl;

    final normalizedPath = path.startsWith('/')
        ? path
        : '/$path';

    var uri = Uri.parse(
      '$trimmedBase$normalizedPath',
    );

    if (query != null && query.isNotEmpty) {
      final queryParameters = <String, String>{};

      query.forEach((key, value) {
        if (value == null) {
          return;
        }

        queryParameters[key] = value.toString();
      });

      if (queryParameters.isNotEmpty) {
        uri = uri.replace(
          queryParameters: queryParameters,
        );
      }
    }

    return uri.toString();
  }

  // ============================================================
  // Response handling
  // ============================================================

  dynamic _handleResponse(
    http.Response response,
  ) {
    final status = response.statusCode;

    // ----------------------------------------------------------
    // DEBUG HTTP LOGGING
    // ----------------------------------------------------------

    if (kDebugMode) {
      print(
        'WAYN HTTP: '
        '${response.request?.method} '
        '${response.request?.url}',
      );

      print('WAYN HTTP STATUS: $status');

      // Response bodies can be large, especially for places,
      // community posts, and other list endpoints.
      // Keep the full body logging available for debugging only.
      print(
        'WAYN HTTP BODY: ${response.body}',
      );
    }

    // ----------------------------------------------------------
    // Success
    // ----------------------------------------------------------

    if (status >= 200 && status < 300) {
      if (status == 204 || response.body.trim().isEmpty) {
        if (kDebugMode) {
          print('WAYN HTTP: empty successful response');
        }

        return null;
      }

      try {
        final decoded = jsonDecode(response.body);

        if (kDebugMode) {
          print(
            'WAYN HTTP: JSON decoded successfully '
            '(${decoded.runtimeType})',
          );
        }

        return decoded;
      } catch (error) {
        if (kDebugMode) {
          print(
            'WAYN HTTP: JSON decode failed: $error',
          );
        }

        return response.body;
      }
    }

    // ----------------------------------------------------------
    // Error
    // ----------------------------------------------------------

    String message = 'HTTP $status';

    dynamic decodedBody;

    if (response.body.trim().isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (decodedBody is Map<String, dynamic>) {
      final detail = decodedBody['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        message = detail.trim();
      } else if (detail != null) {
        message = detail.toString();
      } else {
        final errors = decodedBody['errors'];

        if (errors != null) {
          message = errors.toString();
        } else {
          message = decodedBody.toString();
        }
      }
    } else if (decodedBody != null) {
      message = decodedBody.toString();
    }

    if (kDebugMode) {
      print(
        'WAYN HTTP ERROR: $message',
      );
    }

    throw ApiClientException(
      message,
      statusCode: status,
    );
  }

  // ============================================================
  // Cleanup
  // ============================================================

  void dispose() {
    _getCache.clear();
    _client.close();
  }
}