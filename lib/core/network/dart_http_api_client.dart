import 'dart:convert';

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

class DartHttpApiClient implements ApiClient {
  @override
  final String baseUrl;

  @override
  final Map<String, String> defaultHeaders;

  final http.Client _client;
  final AuthTokenStorage _secureStorage;

  final String tokenStorageKey;

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
        _secureStorage =
            secureStorage ?? SecureAuthTokenStorage();

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

    final requestHeaders = await _buildHeaders(headers);

    final response = await _client.get(
      uri,
      headers: requestHeaders,
    );

    return _handleResponse(response);
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

    return _handleResponse(response);
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

    return _handleResponse(response);
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

    return _handleResponse(response);
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

    return _handleResponse(response);
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
    // TEMPORARY AUTH DEBUG
    // ----------------------------------------------------------

    print(
      'WAYN HTTP: '
      '${response.request?.method} '
      '${response.request?.url}',
    );

    print('WAYN HTTP STATUS: $status');

    print(
      'WAYN HTTP BODY: ${response.body}',
    );

    // ----------------------------------------------------------
    // Success
    // ----------------------------------------------------------

    if (status >= 200 && status < 300) {
      if (status == 204 || response.body.trim().isEmpty) {
        print('WAYN HTTP: empty successful response');
        return null;
      }

      try {
        final decoded = jsonDecode(response.body);

        print(
          'WAYN HTTP: JSON decoded successfully '
          '(${decoded.runtimeType})',
        );

        return decoded;
      } catch (error) {
        print(
          'WAYN HTTP: JSON decode failed: $error',
        );

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

    print(
      'WAYN HTTP ERROR: $message',
    );

    throw ApiClientException(
      message,
      statusCode: status,
    );
  }

  // ============================================================
  // Cleanup
  // ============================================================

  void dispose() {
    _client.close();
  }
}
