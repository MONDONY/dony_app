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
  'HANDOVER_REMINDER_H2',
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
  @visibleForTesting
  static const uploadMaxAttempts = 3;
  @visibleForTesting
  static const uploadRetryDelay = Duration(seconds: 1);

  final ApiClient _apiClient;
  final NotificationRepository _repository;
  final DeviceIdService _deviceIdService;
  final ErrorReportingService? _errorReporter;
  Future<void>? _inFlightUpload;
  Future<void>? _inFlightTokenUpload;
  bool _permissionDeniedReported = false;

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

  static const _androidGeneralChannel = AndroidNotificationChannel(
    'dony_general',
    'Actualités Yadony',
    description: 'Correspondances, invitations et informations générales',
  );

  Future<void> initialize() async {
    // iOS / Android 13+ permission request
    final settings = await _fcm.requestPermission();
    if (kDebugMode) {
      debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');
    }

    // Create Android notification channel
    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_androidChannel);
    await androidNotifications?.createNotificationChannel(
      _androidGeneralChannel,
    );

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
    _fcm.onTokenRefresh.listen((_) => _scheduleTokenUpload());

    // Au tout premier lancement, `authStateChanges` déclenche l'upload avant
    // que l'utilisateur n'ait répondu à la demande d'autorisation ci-dessus :
    // sans autorisation, iOS n'inscrit pas l'appareil auprès d'APNs, aucun
    // jeton n'existe et la tentative échoue. Or accepter la demande ne fait pas
    // passer l'application en arrière-plan — `onAppResumed` n'est donc jamais
    // appelé, et rien ne rattrapait cette première tentative perdue. On relance
    // ici, une fois l'autorisation connue.
    if (settings.authorizationStatus != AuthorizationStatus.denied &&
        FirebaseAuth.instance.currentUser != null) {
      _scheduleTokenUpload();
    }
  }

  /// Relance un upload en respectant celui déjà en vol : la garde de
  /// réentrance de [uploadCurrentToken] ferait sinon ignorer l'appel, et la
  /// tentative déclenchée par un événement plus récent serait perdue.
  void _scheduleTokenUpload() {
    final activeUpload = _inFlightUpload;
    if (activeUpload == null) {
      unawaited(uploadCurrentToken());
    } else {
      unawaited(activeUpload.whenComplete(uploadCurrentToken));
    }
  }

  /// Call this after the user is authenticated (Firebase sign-in complete).
  Future<void> uploadCurrentToken() {
    final activeUpload = _inFlightUpload;
    if (activeUpload != null) return activeUpload;

    late final Future<void> upload;
    upload = _uploadCurrentTokenOnce().whenComplete(() {
      if (identical(_inFlightUpload, upload)) {
        _inFlightUpload = null;
      }
    });
    _inFlightUpload = upload;
    return upload;
  }

  Future<void> _uploadCurrentTokenOnce() async {
    try {
      final token = await _resolveFcmToken();
      if (token != null) {
        await _uploadToken(token);
        return;
      }
      // Un jeton absent signifie que l'appareil ne sera jamais une cible de push.
      // L'ignorer en silence est ce qui a rendu les iPhone muets sans laisser de
      // trace : on le remonte désormais comme une vraie anomalie.
      if (kDebugMode) {
        debugPrint('[FCM] Aucun jeton FCM — appareil non enregistré');
      }
      final diagnosticContext = <String, Object>{
        'feature': 'notifications',
        'channel': 'fcm',
        'platform': Platform.operatingSystem,
      };
      if (Platform.isIOS) {
        try {
          diagnosticContext['apns_token_available'] =
              await _fcm.getAPNSToken() != null;
        } catch (_) {
          diagnosticContext['apns_token_available'] = false;
        }
      }
      unawaited(
        _errorReporter?.report(
              StateError('FCM token null — appareil non enregistré'),
              operation: 'notifications.fcm_token_unavailable',
              context: diagnosticContext,
            ) ??
            Future<void>.value(),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[FCM] uploadCurrentToken failed: $e');
      unawaited(
        _errorReporter?.report(
          e,
          operation: 'notifications.resolve_fcm_token',
          stackTrace: stackTrace,
          context: {
            'feature': 'notifications',
            'channel': 'fcm',
            'platform': Platform.operatingSystem,
          },
        ),
      );
    }
  }

  /// Réévalue l'autorisation et réenregistre le jeton après un retour depuis
  /// Réglages iOS ou après une reprise réseau.
  Future<void> onAppResumed() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    await resumeNotifications(
      getAuthorizationStatus: () async =>
          (await _fcm.getNotificationSettings()).authorizationStatus,
      uploadToken: uploadCurrentToken,
      reportDenied: () async {
        if (_permissionDeniedReported) return;
        _permissionDeniedReported = true;
        await (_errorReporter?.report(
              StateError('Notifications refusées dans les réglages système'),
              operation: 'notifications.permission_denied',
              context: {
                'feature': 'notifications',
                'channel': 'fcm',
                'platform': Platform.operatingSystem,
              },
            ) ??
            Future<void>.value());
      },
    );
  }

  @visibleForTesting
  static Future<void> resumeNotifications({
    required Future<AuthorizationStatus> Function() getAuthorizationStatus,
    required Future<void> Function() uploadToken,
    required Future<void> Function() reportDenied,
  }) async {
    final status = await getAuthorizationStatus();
    if (status == AuthorizationStatus.denied) {
      await reportDenied();
      return;
    }
    await uploadToken();
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

  /// Réessaie une opération réseau bornée. Le délai croît linéairement afin
  /// d'absorber les pertes de réseau transitoires au démarrage de l'iPhone.
  @visibleForTesting
  static Future<void> retryOperation(
    Future<void> Function() operation, {
    int maxAttempts = uploadMaxAttempts,
    Duration retryDelay = uploadRetryDelay,
    void Function(int attempt)? onAttempt,
  }) async {
    assert(maxAttempts >= 1, 'maxAttempts must be at least 1');
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      onAttempt?.call(attempt);
      try {
        await operation();
        return;
      } catch (error, stackTrace) {
        if (!_isTransientUploadFailure(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(retryDelay * attempt);
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  /// Le 429 est délibérément absent : il signale que l'appelant est déjà
  /// au-dessus du quota, et réessayer aggrave exactement ce qu'on subit. C'est
  /// ce qui s'est produit en staging, où l'endpoint héritait de la limite à
  /// 5 req/min de la zone `/auth` : chaque reprise déclenchait trois tentatives
  /// qui entretenaient la saturation, et l'appareil n'était jamais enregistré.
  static bool _isTransientUploadFailure(Object error) {
    if (error is! DioException) return false;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }

  /// Le 429 doit remonter : c'est une panne de configuration côté passerelle,
  /// pas un aléa réseau. Le filtrer a masqué neuf jours de notifications
  /// muettes, l'appareil n'étant jamais enregistré sans qu'aucune alerte ne
  /// parte.
  static bool _shouldReportFailure(Object error) {
    if (error is! DioException) return true;
    if (error.type != DioExceptionType.badResponse) return false;
    final status = error.response?.statusCode ?? 0;
    return status == 429 || status >= 500;
  }

  Future<void> _uploadToken(String token) {
    final activeUpload = _inFlightTokenUpload;
    if (activeUpload != null) return activeUpload;

    late final Future<void> upload;
    upload = _performTokenUpload(token).whenComplete(() {
      if (identical(_inFlightTokenUpload, upload)) {
        _inFlightTokenUpload = null;
      }
    });
    _inFlightTokenUpload = upload;
    return upload;
  }

  Future<void> _performTokenUpload(String token) async {
    var attempts = 0;
    try {
      await retryOperation(() async {
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
      }, onAttempt: (attempt) => attempts = attempt);
      if (kDebugMode) debugPrint('[FCM] Token uploaded to backend');
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[FCM] Token upload failed: $e');
      if (!_shouldReportFailure(e)) return;
      unawaited(
        _errorReporter?.report(
          e,
          operation: 'notifications.upload_fcm_token',
          stackTrace: stackTrace,
          context: {
            'feature': 'notifications',
            'channel': 'fcm',
            'attempts': attempts,
            'platform': Platform.operatingSystem,
          },
        ),
      );
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
      if (_shouldReportFailure(e)) {
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
