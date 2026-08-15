import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import Sentry

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let apiKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]
      ?? (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)
      ?? ""
    GMSServices.provideAPIKey(apiKey)

    // FirebaseAppDelegateProxyEnabled est à false : le swizzling de
    // GULAppDelegateSwizzler, sur lequel repose l'inscription automatique de
    // FLTFirebaseMessagingPlugin, ne s'applique pas. Personne ne demandait donc
    // l'inscription APNs : `didRegisterForRemoteNotificationsWithDeviceToken`
    // n'était jamais appelé, `getAPNSToken()` renvoyait null indéfiniment, et
    // `getToken()` levait `apns-token-not-set` à chaque tentative. L'appareil
    // n'était jamais enregistré comme cible de push.
    //
    // Appeler l'inscription ici n'affiche aucune demande d'autorisation : elle
    // reste portée par `requestPermission()`. iOS délivre le jeton APNs dès que
    // l'utilisateur a accordé les notifications.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // FirebaseAppDelegateProxyEnabled est à false (Info.plist) : sans le swizzling,
  // c'est à nous de donner le jeton APNs à FCM, sinon aucune push n'est délivrée.
  //
  // Pour Firebase Auth en revanche, on ne transmet pas le jeton en DEBUG : sans APNs,
  // Auth bascule sur le mode "numéro de test" (appVerificationDisabledForTesting) au
  // lieu de tenter une vérification push réelle qui ne peut pas aboutir.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Firebase est configuré depuis Dart, donc après le lancement natif. Or
    // l'inscription APNs demandée dans didFinishLaunching fait revenir ce
    // callback en quelques centaines de millisecondes : `Messaging.messaging()`
    // et `Auth.auth()` peuvent être atteints avant `FirebaseApp.configure()`,
    // ce qui est une erreur fatale et faisait planter l'application au
    // démarrage. On diffère alors la pose du jeton au lieu de la forcer.
    guard FirebaseApp.app() != nil else {
      deferAPNSToken(application, deviceToken)
      return
    }
    apnsRetryCount = 0
    Messaging.messaging().apnsToken = deviceToken
    #if !DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    #endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  /// Nombre de reports déjà effectués en attendant l'initialisation de Firebase.
  private var apnsRetryCount = 0

  /// Réessaie la pose du jeton APNs jusqu'à ce que Firebase soit configuré.
  /// Borné : sans cette limite, un échec d'initialisation ferait boucler ce
  /// report indéfiniment sur la boucle principale.
  private func deferAPNSToken(_ application: UIApplication, _ deviceToken: Data) {
    guard apnsRetryCount < 40 else {
      NSLog("[APNs] Firebase jamais configuré, jeton APNs abandonné")
      return
    }
    apnsRetryCount += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.application(
        application,
        didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
      )
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[APNs] Remote notification registration failed: %@", error.localizedDescription)
    SentrySDK.capture(error: error) { scope in
      scope.setTag(value: "apns_registration", key: "component")
      scope.setTag(value: "ios", key: "platform")
    }
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  // Laisse Firebase Auth consommer les notifications de vérification avant FCM.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}
