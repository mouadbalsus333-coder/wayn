abstract class ApiClient {
  String get baseUrl;

  Map<String, String> get defaultHeaders;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  });

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });
}

class ApiClientException implements Exception {
  final String message;
  final int? statusCode;

  ApiClientException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiClientException(statusCode: $statusCode, message: $message)';
}
