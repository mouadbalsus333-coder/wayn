import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/backend_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';

/// Registers the current device (and its FCM token) with the WAYN backend.
///
/// The FCM token is sensitive and is never logged anywhere in this file.
///
/// Device identifier
/// -----------------
/// A stable random UUID is generated once and persisted in secure storage so
/// it does not change between app launches (and is independent of the FCM
/// token). Re-registering with the same `device_id` updates the token on the
/// existing row instead of creating duplicates.
class DeviceSync {
  final DartHttpApiClient _api;

  // Secure storage is used so the stable device id never lands in plain
  // logs, backups or analytics.
  final FlutterSecureStorage _secureStorage;

  static const String _deviceIdKey = 'wayn_stable_device_id';

  DeviceSync({
    DartHttpApiClient? api,
    FlutterSecureStorage? storage,
  })  : _api = api ??
            DartHttpApiClient(
              baseUrl: BackendConfig.backendUrl,
            ),
        _secureStorage = storage ?? const FlutterSecureStorage();

  // ============================================================
  // Stable device identifier
  // ============================================================

  Future<String> _ensureDeviceId() async {
    final existing = await _secureStorage.read(
      key: _deviceIdKey,
    );

    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final id = _generateUuid();
    await _secureStorage.write(
      key: _deviceIdKey,
      value: id,
    );

    return id;
  }

  // ============================================================
  // UUID v4 (no external dependency needed)
  // ============================================================

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set the version (4) and variant (10) bits.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ============================================================
  // Platform
  // ============================================================

  String? _platform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    // Web/desktop are not supported targets for FCM device registration.
    return null;
  }

  // ============================================================
  // Registration
  // ============================================================

  /// Registers (or updates) this device against the backend.
  ///
  /// Returns `true` when the backend accepted the device. Never throws for
  /// network/HTTP failures so callers can keep notification delivery
  /// best-effort without breaking authentication flows.
  Future<bool> register({required String fcmToken}) {
    return _register(fcmToken: fcmToken);
  }

  Future<bool> _register({required String fcmToken}) async {
    final platform = _platform();
    if (platform == null) {
      return false;
    }

    final deviceId = await _ensureDeviceId();

    try {
      await _api.post(
        '/api/v1/devices/register',
        body: {
          'device_id': deviceId,
          'fcm_token': fcmToken,
          'platform': platform,
        },
      );

      // Reaching the endpoint (2xx) is considered a successful registration.
      return true;
    } on ApiClientException {
      // 401 (expired session) or 4xx: swallow — registration stays best-effort.
      return false;
    } catch (_) {
      // Network errors must never bubble up into auth flows.
      return false;
    }
  }

  // ============================================================
  // Deactivation
  // ============================================================

  /// Deactivates this device (by matching its stable `device_id`) during
  /// logout so no FCM tokens remain active on the backend without a session.
  ///
  /// Best-effort: failures are swallowed to keep logout friendly.
  Future<void> deactivate() async {
    final deviceId = await _ensureDeviceId();

    try {
      final response = await _api.get(
        '/api/v1/devices',
      );

      if (response is! Map) {
        return;
      }

      final payload = Map<String, dynamic>.from(response);
      final rawDevices = payload['devices'];

      if (rawDevices is! List) {
        return;
      }

      for (final item in rawDevices) {
        if (item is! Map) {
          continue;
        }

        final device = Map<String, dynamic>.from(item);

        if (device['device_id']?.toString() == deviceId) {
          final id = device['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _api.delete(
              '/api/v1/devices/$id',
            );
          }
          return;
        }
      }
    } catch (_) {
      // Swallow — deactivation is best-effort.
    }
  }
}