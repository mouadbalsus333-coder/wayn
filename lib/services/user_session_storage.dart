import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// Persistent storage for the locally cached authenticated user.
///
/// The access token is stored separately by DartHttpApiClient.
/// This class only stores the latest known User object so the app
/// can restore the authenticated session when the device is offline.
class UserSessionStorage {
  static const String userStorageKey = 'wayn_cached_user';

  final FlutterSecureStorage _storage;

  UserSessionStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  // ============================================================
  // Save user
  // ============================================================

  Future<void> saveUser(User user) async {
    final encodedUser = jsonEncode(
      user.toMap(),
    );

    await _storage.write(
      key: userStorageKey,
      value: encodedUser,
    );
  }

  // ============================================================
  // Get cached user
  // ============================================================

  Future<User?> getCachedUser() async {
    final encodedUser = await _storage.read(
      key: userStorageKey,
    );

    if (encodedUser == null ||
        encodedUser.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encodedUser);

      if (decoded is! Map) {
        return null;
      }

      return User.fromMap(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      // If the cached data is corrupted or no longer valid,
      // remove it rather than allowing it to break app startup.
      await clearUser();
      return null;
    }
  }

  // ============================================================
  // Clear cached user
  // ============================================================

  Future<void> clearUser() async {
    await _storage.delete(
      key: userStorageKey,
    );
  }
}