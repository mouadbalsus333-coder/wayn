import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging, RemoteMessage;


import 'device_sync.dart';
import 'local_notification_service.dart';

/// Lifecycle controller for Firebase Cloud Messaging on the device.
///
/// Everything here is intentionally best-effort and never throws: if Firebase
/// is not configured (no `google-services.json` / `GoogleService-Info.plist`),
/// or a platform is unsupported, we simply no-op instead of breaking startup.
///
/// Security: FCM tokens are never logged and never printed. Deep-link/data is
/// retained (not navigated-to) because no routes are invented.
class FcmController {
  final DeviceSync _deviceSync;

  bool _wired = false;
  bool _permissionRequested = false;

  // Retained for a future deep-link layer. No navigation is invented here.
  static RemoteMessage? _latestOpenedMessage;

  static RemoteMessage? get latestOpenedMessage => _latestOpenedMessage;

  // Set by callers and invoked by the top-level background handler.
  static final Future<void> Function(RemoteMessage) _backgroundCallback =
      (RemoteMessage _) async {};

  FcmController({DeviceSync? deviceSync})
      : _deviceSync = deviceSync ?? DeviceSync();

  // ============================================================
  // Public lifecycle
  // ============================================================

  /// Initialises Firebase, wires message handlers and registers this device.
  /// Safe to call at startup; never blocks or breaks the app on failure.
  Future<void> initialize() {
    return _initialize();
  }

  /// Registers the current device with the backend. Call this after a
  /// successful login so the FCM token is uploaded once the user session is
  /// established. Safe to call repeatedly — handlers are wired only once and
  /// registration is idempotent on the backend (upsert by device_id).
  Future<void> registerDeviceIfReady() async {
    try {
      if (!Firebase.apps.isNotEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      return;
    }
    _wireHandlers();
    await _requestPermissionOnce();
    await _registerCurrentDevice();
  }

  Future<void> _initialize() async {
    try {
      // Reads native config (google-services.json / GoogleService-Info.plist).
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase not configured on this platform/build — FCM is simply off.
      return;
    }

    _wireHandlers();
    await _requestPermissionOnce();
    await _registerCurrentDevice();
    await _consumeInitialMessage();
  }

  // ============================================================
  // Permission (requested once, best-effort)
  // ============================================================

  Future<void> _requestPermissionOnce() async {
    if (_permissionRequested) {
      return;
    }
    _permissionRequested = true;

    try {
      // Android: returns current authorization status (no repeated OS prompt
      // for already-authorised/denied states). iOS: one-off user dialog.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Ignore — permission prompting must never break startup.
    }
  }
// ============================================================
  // Token
  // ============================================================

  Future<String?> _obtainToken() async {
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Registration
  // ============================================================

  Future<void> _registerCurrentDevice() async {
    final token = await _obtainToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    // NOTE: `token` is deliberately never logged.
    await _deviceSync.register(fcmToken: token);
  }

  // ============================================================
  // Wiring handlers (once)
  // ============================================================

  void _wireHandlers() {
    if (_wired) {
      return;
    }
    _wired = true;

    // Foreground message received while the app is open.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleRemoteMessage(message);
    });

    // User tapped the notification (app opened from background state).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _latestOpenedMessage = message;
      _handleRemoteMessage(message);
    });

    // Background/terminated app message handler. Must be a top-level function.
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // A new FCM token was generated server-side — re-register it.
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      // Never log `token`.
      try {
        _deviceSync.register(fcmToken: token);
      } catch (_) {
        // Best-effort.
      }
    });
  }

  // ============================================================
  // Message handling
  // ============================================================

  void _handleRemoteMessage(RemoteMessage message) {
    // In-app notifications are the source of truth for the notifications
    // screen; a push is a delivery signal, not new data to persist.
    _latestOpenedMessage = message;

    // When the app is in the foreground, Firebase does not automatically
    // show a system notification on Android. Show it locally instead.
    LocalNotificationService.instance.showFromRemote(message);
  }

  /// Deactivates the current device on the backend (logout). Best-effort.
  Future<void> deactivateDevice() async {
    try {
      await _deviceSync.deactivate();
    } catch (_) {
      // Swallow — deactivation is best-effort and must never break logout.
    }
  }

  /// Handles the tap that launched a terminated app (deep-link data).
  Future<void> _consumeInitialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) {
        return;
      }
      _latestOpenedMessage = message;
    } catch (_) {
      // Best-effort.
    }
  }
}

/// Top-level background handler required by FirebaseMessaging.onBackgroundMessage.
Future<void> _backgroundHandler(RemoteMessage message) async {
  try {
    await FcmController._backgroundCallback(message);
  } catch (_) {
    // Never crash the isolate from a notification callback.
  }
}

/// Public entry point wired by main.dart at startup (fire-and-forget).
Future<void> initializeFirebasePush() async {
  final controller = FcmController();
  await controller.initialize();
}