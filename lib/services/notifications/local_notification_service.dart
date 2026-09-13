import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kPushChannelId = 'wayn_push_channel';
const String kPushChannelName = 'WAYN Notifications';
const String kPushChannelDesc = 'Social and admin notifications from WAYN';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance =
      LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onTap,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();

        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            kPushChannelId,
            kPushChannelName,
            description: kPushChannelDesc,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );
      }

      _initialized = true;
    } catch (_) {
      return;
    }
  }

  Future<void> showFromRemote(RemoteMessage message) async {
    await ensureInitialized();

    if (!_initialized) return;

    final notification = message.notification;

    final title = (notification?.title ?? message.data['title'] ?? '')
        .trim();
    final body = (notification?.body ?? message.data['body'] ?? '').trim();

    if (title.isEmpty && body.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kPushChannelId,
        kPushChannelName,
        channelDescription: kPushChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        category: AndroidNotificationCategory.social,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final payload = message.data.isEmpty
        ? null
        : jsonEncode(message.data);

    final notificationId =
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    await _plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static void _onTap(NotificationResponse response) {
    // Navigation can be handled by the app layer later.
  }

  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse response) {
    // Background notification tap handling can be connected later.
  }
}
