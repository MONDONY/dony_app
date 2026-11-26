import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import Sentry
import StoreKit
import UserNotifications
import stream_video_push_notification

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
    // Appels audio (Stream Video) : jeton VoIP PushKit, pour que CallKit fasse
    // sonner l'iPhone même app fermée ou écran verrouillé.
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBadgeChannel(engineBridge.pluginRegistry)
    registerAppStoreChannel(engineBridge.pluginRegistry)
  }

  /// Fiche App Store présentée par-dessus l'app (mise à jour). Apple n'offre aucune
  /// mise à jour depuis l'app : on évite au moins de faire quitter Yadony. Répond
  /// `false` si rien n'a pu être présenté, Dart ouvre alors le lien App Store.
  private func registerAppStoreChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "YadonyAppStore") else {
      NSLog("[AppStore] Registrar indisponible, fiche intégrée désactivée")
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.yadony.yadony/app_store",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showProductPage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let appId = (call.arguments as? [String: Any])?["appId"] as? String,
            let presenter = self?.topViewController() else {
        result(false)
        return
      }
      let store = SKStoreProductViewController()
      store.delegate = AppStoreDismissDelegate.shared
      presenter.present(store, animated: true)
      store.loadProduct(
        withParameters: [SKStoreProductParameterITunesItemIdentifier: appId]
      ) { loaded, error in
        if !loaded {
          NSLog("[AppStore] Fiche non chargée : %@", error?.localizedDescription ?? "?")
          store.dismiss(animated: true)
        }
        result(loaded)
      }
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  /// Pastille de l'icône. iOS ne laisse que l'application écrire ce nombre : lire les
  /// notifications ne l'efface pas, et le champ APNs `badge` est absolu, il écrit la
  /// valeur reçue. Sans ce canal, rien côté Dart ne pouvait remettre la pastille à zéro.
  private func registerBadgeChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "YadonyAppBadge") else {
      NSLog("[Badge] Registrar indisponible, pastille non pilotable")
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.yadony.yadony/app_badge",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
          DispatchQueue.main.async {
            if let error = error {
              NSLog("[Badge] Écriture refusée : %@", error.localizedDescription)
            }
            result(nil)
          }
        }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }
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
    // Même garde que didRegisterForRemoteNotifications : une silent push reçue
    // au démarrage à froid arrive avant `FirebaseApp.configure()` (fait depuis
    // Dart), et `Auth.auth()` serait alors une erreur fatale. Elle ne peut pas
    // être une vérification Firebase Auth en cours : FCM la traite.
    if FirebaseApp.app() != nil, Auth.auth().canHandleNotification(userInfo) {
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

/// Referme la fiche App Store intégrée quand l'utilisateur touche « OK ».
final class AppStoreDismissDelegate: NSObject, SKStoreProductViewControllerDelegate {
  static let shared = AppStoreDismissDelegate()

  func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
    viewController.dismiss(animated: true)
  }
}
