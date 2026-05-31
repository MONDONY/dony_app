import Flutter
import UIKit
import GoogleMaps
import FirebaseAuth

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Transmet le jeton APNs à Firebase Auth (vérification téléphone par silent push).
  // En DEBUG, on NE transmet PAS le token : sans APNs, Firebase Auth bascule sur
  // le mode "numéro de test" (appVerificationDisabledForTesting) au lieu de tenter
  // une vérification push réelle qui ne peut pas aboutir sans clé APNs serveur.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if !DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    #endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
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
