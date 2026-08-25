import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Demande la permission caméra du système, que les WebView ne réclament pas
/// d'elles-mêmes.
///
/// `webview_flutter_android` se contente de relayer `PermissionRequest.grant()`
/// vers Android : son code natif ne contient ni `checkSelfPermission` ni
/// `requestPermissions`. Accorder la requête *web* ne sert donc à rien tant que
/// le système, lui, n'a pas dit oui — la page se croit autorisée et la caméra
/// reste noire.
///
/// Android seulement : WKWebView demande l'autorisation lui-même à partir de
/// `NSCameraUsageDescription`, d'où le court-circuit sur les autres plateformes.
class CameraPermissionService {
  const CameraPermissionService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.yadony.yadony/permissions');

  final MethodChannel _channel;

  Future<bool> request() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('requestCamera') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Binaire sans le pont natif (ancienne version, test). Refuser
      // franchement vaut mieux que laisser la page croire qu'elle a la caméra.
      return false;
    }
  }
}
