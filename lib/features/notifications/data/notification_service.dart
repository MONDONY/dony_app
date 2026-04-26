import 'dart:async';

import 'package:dony/core/network/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level — Firebase requirement for background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Broadcasts the GoRouter path to navigate to when a notification is tapped
  final _navigationController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationController.stream;

  static const _androidChannel = AndroidNotificationChannel(
    'dony_transactional',
    'Notifications dony',
    description: 'Paiements, livraisons et mises à jour de vos envois',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // iOS / Android 13+ permission request
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Init flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Delay slightly so the router is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage);
      });
    }

    // Token upload is deferred to after authentication (called by app.dart).
    // onTokenRefresh re-uploads automatically once the user is signed in.
    _fcm.onTokenRefresh.listen(_uploadToken);
  }

  /// Call this after the user is authenticated (Firebase sign-in complete).
  Future<void> uploadCurrentToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _uploadToken(token);
  }

  Future<void> _uploadToken(String token) async {
    try {
      await _apiClient.dio.put('/auth/me/fcm-token', data: {'fcmToken': token});
      debugPrint('[FCM] Token uploaded to backend');
    } catch (e) {
      debugPrint('[FCM] Token upload failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _routeForMessage(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = _routeForMessage(message.data);
    if (route != null) {
      _navigationController.add(route);
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final route = response.payload;
    if (route != null && route.isNotEmpty) {
      _navigationController.add(route);
    }
  }

  /// Maps the FCM data `type` field to a GoRouter path.
  String? _routeForMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final bidId = data['bidId'] as String?;
    final announcementId = data['announcementId'] as String?;

    return switch (type) {
      'BID_CREATED' when announcementId != null => '/matching/bids/$announcementId',
      'BID_ACCEPTED' when bidId != null        => '/shipments/$bidId',
      'BID_REJECTED' when bidId != null        => '/shipments/$bidId',
      'HANDOVER_DEFINED' when bidId != null    => '/shipments/$bidId',
      'TRIP_CANCELLED'                         => '/home',
      'PAYMENT_RELEASED' when bidId != null    => '/shipments/$bidId',
      'DELIVERY_CONFIRMED' when bidId != null  => '/shipments/$bidId',
      'DISPUTE_OPENED' when bidId != null      => '/shipments/$bidId',
      _                                        => null,
    };
  }

  void dispose() {
    _navigationController.close();
  }
}
