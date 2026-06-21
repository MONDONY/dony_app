import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
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
  final DeviceIdService _deviceIdService;

  NotificationService(
    this._apiClient,
    this._repository,
    this._deviceIdService,
  );

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
    try {
      final token = await _fcm.getToken();
      if (token != null) await _uploadToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] uploadCurrentToken failed: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final (deviceName, platform) = await _getDeviceInfo();
      await _apiClient.dio.put('/auth/me/fcm-token', data: {
        'fcmToken': token,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
      });
      if (kDebugMode) debugPrint('[FCM] Token uploaded to backend');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Token upload failed: $e');
    }
  }

  /// Returns (deviceName, platform) with graceful fallback on failure.
  /// Platform must be lowercase 'ios' or 'android' to match backend validation.
  Future<(String, String)> _getDeviceInfo() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return (ios.name, 'ios');
      } else {
        final android = await info.androidInfo;
        final name = formatAndroidName(android.manufacturer, android.model);
        return (name, 'android');
      }
    } catch (_) {
      return ('Appareil', Platform.isIOS ? 'ios' : 'android');
    }
  }

  /// Combines [manufacturer] and [model] into a friendly display name.
  /// Avoids duplication when [model] already starts with the manufacturer name.
  /// Exposed for unit testing via @visibleForTesting.
  @visibleForTesting
  static String formatAndroidName(String manufacturer, String model) {
    final mfr = manufacturer.trim();
    final mdl = model.trim();
    if (mfr.isEmpty || mdl.toLowerCase().startsWith(mfr.toLowerCase())) {
      return mdl;
    }
    return '${_capitalize(mfr)} $mdl';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @visibleForTesting
  Future<(String, String)> testGetDeviceInfo() => _getDeviceInfo();

  @visibleForTesting
  Future<void> testUploadToken(String token) => _uploadToken(token);

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

  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static bool _isUuid(String? v) => v != null && _uuidRegex.hasMatch(v);

  /// Maps the FCM data `type` field to a GoRouter path.
  /// IDs are validated as UUIDs before being embedded in routes to prevent
  /// path traversal from crafted FCM payloads.
  String? _routeForMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final bidId = data['bidId'] as String?;
    final announcementId = data['announcementId'] as String?;
    final threadId = data['threadId'] as String?;
    final requestId = data['requestId'] as String?;

    return switch (type) {
      // Voyageur → liste des offres sur son annonce
      'BID_CREATED' when _isUuid(announcementId) => '/announcements/$announcementId/bids',
      // Expéditeur → détail de son offre
      'BID_ACCEPTED' when _isUuid(bidId)         => '/bids/$bidId',
      'BID_REJECTED' when _isUuid(bidId)         => '/bids/$bidId',
      'HANDOVER_DEFINED' when _isUuid(bidId)     => '/bids/$bidId',
      'DELIVERY_CONFIRMED' when _isUuid(bidId)   => '/bids/$bidId',
      'PAYMENT_RELEASED' when _isUuid(bidId)     => '/bids/$bidId',
      'DISPUTE_OPENED' when _isUuid(bidId)       => '/bids/$bidId',
      // Négociation — les deux parties naviguent vers le thread
      'negotiation_started' when _isUuid(threadId)           => '/negotiations/$threadId',
      'negotiation_counter' when _isUuid(threadId)           => '/negotiations/$threadId',
      'negotiation_awaiting_trip' when _isUuid(threadId)     => '/negotiations/$threadId',
      'negotiation_awaiting_payment' when _isUuid(threadId)  => '/negotiations/$threadId',
      'negotiation_expired' when _isUuid(threadId)           => '/negotiations/$threadId',
      'request_accepted' when _isUuid(threadId)              => '/negotiations/$threadId',
      // Voyageur abonné → détail de l'annonce publiée
      'TRAVELER_NEW_ANNOUNCEMENT' when _isUuid(announcementId) => '/traveler/$announcementId',
      // Expéditeur → détail du trajet qui matche son alerte
      'CORRIDOR_ALERT' when _isUuid(announcementId) => '/traveler/$announcementId',
      // Voyageur → détail du colis qui matche un de ses trajets
      'PACKAGE_MATCH' when _isUuid(requestId) => '/package-requests/$requestId/public',
      // Nouveau message → liste des conversations
      'NEW_MESSAGE'                              => '/messages',
      // Trajet annulé → pas de navigation (le trajet n'existe plus)
      'TRIP_CANCELLED'                           => null,
      _                                          => null,
    };
  }

  void dispose() {
    _navigationController.close();
    _newNotificationController.close();
  }
}
