import 'dart:async';

import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level — Firebase requirement for background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('[FCM] Background message: ${message.messageId}');
}

const _criticalTypes = {
  'PAYMENT_RELEASED',
  'DELIVERY_CONFIRMED',
  'DISPUTE_OPENED',
};

class NotificationService {
  final ApiClient _apiClient;
  final NotificationRepository _repository;

  NotificationService(this._apiClient, this._repository);

  // late: deferred until initialize() so tests can instantiate this class without Firebase
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Broadcasts the GoRouter path to navigate to when a notification is tapped
  final _navigationController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationController.stream;

  // Emits void whenever a new foreground notification arrives (for badge refresh)
  final _newNotificationController = StreamController<void>.broadcast();
  Stream<void> get newNotificationStream => _newNotificationController.stream;

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
    if (kDebugMode) debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');

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
      if (kDebugMode) debugPrint('[FCM] Token uploaded to backend');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Token upload failed: $e');
    }
  }

  Future<void> _ackIfCritical(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final notificationId = data['notificationId'] as String?;
    if (type == null || notificationId == null) return;
    if (!_criticalTypes.contains(type)) return;
    try {
      await _repository.ack(notificationId);
      if (kDebugMode) debugPrint('[FCM] ACK sent for $type / $notificationId');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] ACK failed: $e');
    }
  }

  @visibleForTesting
  Future<void> testAckIfCritical(Map<String, dynamic> data) => _ackIfCritical(data);

  @visibleForTesting
  String? testRouteForMessage(Map<String, dynamic> data) => _routeForMessage(data);

  void _handleForegroundMessage(RemoteMessage message) {
    _ackIfCritical(message.data);
    _newNotificationController.add(null);
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
    _ackIfCritical(message.data);
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
    final threadId = data['threadId'] as String?;

    return switch (type) {
      // Voyageur → liste des offres sur son annonce
      'BID_CREATED' when announcementId != null => '/announcements/$announcementId/bids',
      // Expéditeur → détail de son offre
      'BID_ACCEPTED' when bidId != null        => '/bids/$bidId',
      'BID_REJECTED' when bidId != null        => '/bids/$bidId',
      'HANDOVER_DEFINED' when bidId != null    => '/bids/$bidId',
      'DELIVERY_CONFIRMED' when bidId != null  => '/bids/$bidId',
      'PAYMENT_RELEASED' when bidId != null    => '/bids/$bidId',
      'DISPUTE_OPENED' when bidId != null      => '/bids/$bidId',
      // Négociation — les deux parties naviguent vers le thread
      'negotiation_started' when threadId != null      => '/negotiations/$threadId',
      'negotiation_counter' when threadId != null      => '/negotiations/$threadId',
      'negotiation_awaiting_trip' when threadId != null => '/negotiations/$threadId',
      'negotiation_awaiting_payment' when threadId != null => '/negotiations/$threadId',
      'negotiation_expired' when threadId != null      => '/negotiations/$threadId',
      'request_accepted' when threadId != null         => '/negotiations/$threadId',
      // Nouveau message → liste des conversations
      'NEW_MESSAGE'                            => '/messages',
      // Trajet annulé → pas de navigation (le trajet n'existe plus)
      'TRIP_CANCELLED'                         => null,
      _                                        => null,
    };
  }

  void dispose() {
    _navigationController.close();
    _newNotificationController.close();
  }
}
