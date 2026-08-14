import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/notification_route_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level — Firebase requirement for background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('[FCM] Background message: ${message.messageId}');
  await ackCriticalFromBackground(message.data);
}

const _criticalTypes = {
  'PAYMENT_RELEASED',
  'DELIVERY_CONFIRMED',
  'DISPUTE_OPENED',
};

/// Accuse réception d'une notification critique depuis l'isolate d'arrière-plan.
///
/// Sans ça, l'ACK ne partait que si l'application était au premier plan ou si
/// l'utilisateur tapait la notification. Le backend, lui, envoie un SMS 60 s
/// après une notification critique sans ACK : téléphone en poche, tout paiement
/// libéré ou toute livraison confirmée déclenchait donc un SMS, alors que le
/// push était bien arrivé. L'ACK mesurait l'ouverture, pas la réception.
///
/// Cet isolate ne partage rien avec l'app : ni GetIt, ni `ApiClient`, ni
/// `AuthInterceptor`. Tout est donc reconstruit à la main, et le moindre échec
/// est avalé — au pire l'utilisateur reçoit le SMS, comme avant.
@pragma('vm:entry-point')
@visibleForTesting
Future<void> ackCriticalFromBackground(
  Map<String, dynamic> data, {
  @visibleForTesting Dio? dioOverride,
  @visibleForTesting Future<String?> Function()? idTokenOverride,
}) async {
  final type = data['type'] as String?;
  final notificationId = data['notificationId'] as String?;
  if (type == null || notificationId == null) return;
  if (!_criticalTypes.contains(type)) return;

  try {
    if (idTokenOverride == null && Firebase.apps.isEmpty) {
      // L'isolate démarre vierge : Firebase doit y être initialisé avant de
      // pouvoir lire la session persistée.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final token = idTokenOverride != null
        ? await idTokenOverride()
        : await FirebaseAuth.instance.currentUser?.getIdToken();
    // Session absente (déconnexion, réinstallation) : rien à accuser, le SMS
    // reste le bon filet.
    if (token == null || token.isEmpty) return;

    final dio = dioOverride ?? Dio(BaseOptions(baseUrl: kApiBaseUrl));
    await dio.post<void>(
      '/notifications/$notificationId/ack',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (kDebugMode) {
      debugPrint('[FCM] ACK arrière-plan envoyé pour $type / $notificationId');
    }
  } catch (e) {
    // Aucun report d'erreur ici : Sentry n'est pas initialisé dans cet isolate,
    // et un ACK manqué dégrade proprement vers le SMS de secours.
    if (kDebugMode) debugPrint('[FCM] ACK arrière-plan échoué : $e');
  }
}

class NotificationService {
  /// Attente maximale du jeton APNs sur iOS : 10 tentatives d'une seconde.
  /// L'inscription APNs aboutit en général en moins de deux secondes ; la marge
  /// couvre un réseau lent sans retarder l'enregistrement dans le cas normal.
  @visibleForTesting
  static const apnsMaxAttempts = 10;
  @visibleForTesting
  static const apnsRetryDelay = Duration(seconds: 1);

  final ApiClient _apiClient;
  final NotificationRepository _repository;
  final DeviceIdService _deviceIdService;
  final ErrorReportingService? _errorReporter;

  NotificationService(
    this._apiClient,
    this._repository,
    this._deviceIdService, [
    this._errorReporter,
  ]);

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
    'Notifications Yadony',
    description: 'Paiements, livraisons et mises à jour de vos envois',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // iOS / Android 13+ permission request
    final settings = await _fcm.requestPermission();
    if (kDebugMode) {
      debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');
    }

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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
      final token = await _resolveFcmToken();
      if (token != null) {
        await _uploadToken(token);
        return;
      }
      // Un jeton absent signifie que l'appareil ne sera jamais une cible de push.
      // L'ignorer en silence est ce qui a rendu les iPhone muets sans laisser de
      // trace : on le remonte désormais comme une vraie anomalie.
      if (kDebugMode)
        debugPrint('[FCM] Aucun jeton FCM — appareil non enregistré');
      unawaited(
        _errorReporter?.report(
              StateError('FCM token null — appareil non enregistré'),
              operation: 'notifications.fcm_token_unavailable',
              context: {
                'feature': 'notifications',
                'channel': 'fcm',
                'platform': Platform.operatingSystem,
              },
            ) ??
            Future<void>.value(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] uploadCurrentToken failed: $e');
    }
  }

  /// Récupère le jeton FCM, en attendant le jeton APNs sur iOS.
  ///
  /// `getToken()` renvoie `null` sur iOS tant qu'APNs n'a pas répondu. Or
  /// `uploadCurrentToken` part de `authStateChanges`, qui se déclenche dès la
  /// restauration de session au démarrage — bien avant l'inscription APNs.
  /// Sans cette attente, le jeton était null, l'appareil n'était jamais
  /// enregistré, et l'iPhone ne recevait plus aucune notification. Aucune
  /// reprise ne rattrapait le coup : `onTokenRefresh` ne se déclenche que si le
  /// jeton change, ce qui n'arrive pas dans ce cas.
  Future<String?> _resolveFcmToken() => resolveFcmToken(
    isIOS: Platform.isIOS,
    getApnsToken: _fcm.getAPNSToken,
    getFcmToken: _fcm.getToken,
  );

  /// Cœur testable de [_resolveFcmToken], sans dépendance à Firebase.
  @visibleForTesting
  static Future<String?> resolveFcmToken({
    required bool isIOS,
    required Future<String?> Function() getApnsToken,
    required Future<String?> Function() getFcmToken,
    int maxAttempts = apnsMaxAttempts,
    Duration retryDelay = apnsRetryDelay,
  }) async {
    if (isIOS) {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (await getApnsToken() != null) break;
        await Future<void>.delayed(retryDelay);
      }
    }
    return getFcmToken();
  }

  Future<void> _uploadToken(String token) async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final (deviceName, platform) = await _getDeviceInfo();
      await _apiClient.dio.put(
        '/auth/me/fcm-token',
        data: {
          'fcmToken': token,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        },
      );
      if (kDebugMode) debugPrint('[FCM] Token uploaded to backend');
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[FCM] Token upload failed: $e');
      if (e is! DioException) {
        unawaited(
          _errorReporter?.report(
            e,
            operation: 'notifications.upload_fcm_token',
            stackTrace: stackTrace,
            context: {'feature': 'notifications', 'channel': 'fcm'},
          ),
        );
      }
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
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[FCM] ACK failed: $e');
      if (e is! DioException) {
        unawaited(
          _errorReporter?.report(
            e,
            operation: 'notifications.ack_critical',
            stackTrace: stackTrace,
            context: {'feature': 'notifications', 'channel': 'fcm'},
          ),
        );
      }
    }
  }

  @visibleForTesting
  Future<void> testAckIfCritical(Map<String, dynamic> data) =>
      _ackIfCritical(data);

  @visibleForTesting
  String? testRouteForMessage(Map<String, dynamic> data) =>
      _routeForMessage(data);

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

  /// Maps the FCM data `type` field to a GoRouter path via the shared resolver
  /// (also used by the in-app notification inbox, so both surfaces agree).
  String? _routeForMessage(Map<String, dynamic> data) =>
      resolveNotificationRoute(data['type'] as String?, data);

  void dispose() {
    _navigationController.close();
    _newNotificationController.close();
  }
}
