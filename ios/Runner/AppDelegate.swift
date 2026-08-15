import Flutter
import UIKit
import GoogleMaps
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
    Messaging.messaging().apnsToken = deviceToken
    #if !DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    #endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
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
