import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'wayn_access_token';

  final FlutterSecureStorage _storage;

  const TokenStorage({
    this._storage = const FlutterSecureStorage(),
  });

  Future<void> saveAccessToken(String token) async {
    await _storage.write(
      key: _accessTokenKey,
      value: token,
    );
  }

  Future<String?> getAccessToken() async {
    return _storage.read(
      key: _accessTokenKey,
    );
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(
      key: _accessTokenKey,
    );
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }
}