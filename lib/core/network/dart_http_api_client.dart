import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class DartHttpApiClient implements ApiClient {
  @override
  final String baseUrl;

  @override
  final Map<String, String> defaultHeaders;

  final http.Client _client;

  DartHttpApiClient({
    required this.baseUrl,
    Map<String, String>? defaultHeaders,
    http.Client? client,
  })  : defaultHeaders = defaultHeaders ??
            const {
              'Content-Type': 'application/json',
            },
        _client = client ?? http.Client();

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, queryParams),
    );

    final response = await _client.get(
      uri,
      headers: {
        ...defaultHeaders,
        ...?headers,
      },
    );

    return _handleResponse(response);
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final response = await _client.post(
      uri,
      headers: {
        ...defaultHeaders,
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );

    return _handleResponse(response);
  }

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final response = await _client.put(
      uri,
      headers: {
        ...defaultHeaders,
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );

    return _handleResponse(response);
  }

  @override
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final response = await _client.patch(
      uri,
      headers: {
        ...defaultHeaders,
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );

    return _handleResponse(response);
  }

  @override
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      _buildUrl(path, null),
    );

    final response = await _client.delete(
      uri,
      headers: {
        ...defaultHeaders,
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  String _buildUrl(
    String path,
    Map<String, dynamic>? query,
  ) {
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final normalizedPath =
        path.startsWith('/') ? path : '/$path';

    var uri = Uri.parse(
      '$trimmedBase$normalizedPath',
    );

    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: query.map(
          (key, value) => MapEntry(
            key,
            value.toString(),
          ),
        ),
      );
    }

    return uri.toString();
  }

  dynamic _handleResponse(
    http.Response response,
  ) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return null;
      }

      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    throw ApiClientException(
      'HTTP ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }
}