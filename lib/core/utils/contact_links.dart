import 'package:flutter/foundation.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Lien `wa.me` qui ouvre la conversation WhatsApp avec [phone], message
/// [text] pré-rempli.
///
/// Rend `null` quand le numéro n'est pas au format international (`+…` ou
/// `00…`) : sans indicatif pays, `wa.me` ouvrirait la conversation d'un
/// inconnu, voire d'un numéro d'un autre pays.
Uri? whatsAppChatUri(String? phone, String text) {
  if (phone == null) {
    return null;
  }
  final trimmed = phone.trim();
  if (!trimmed.startsWith('+') && !trimmed.startsWith('00')) {
    return null;
  }
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.length < 8) {
    return null;
  }
  return Uri.https('wa.me', '/$digits', {'text': text});
}

/// Lien `sms:` qui ouvre la messagerie du téléphone sur [phone], corps [body]
/// pré-rempli.
///
/// Le séparateur du corps diffère selon le système : Android lit
/// `sms:<numéro>?body=…`, iOS `sms:<numéro>&body=…` (avec `?`, Messages
/// ignore le texte). Espaces, tirets et parenthèses du numéro sont retirés,
/// le `+` de l'indicatif est gardé.
///
/// Rend `null` sans numéro exploitable (moins de 6 chiffres).
Uri? smsUri(String? phone, String body, {TargetPlatform? platform}) {
  if (phone == null) {
    return null;
  }
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) {
    return null;
  }
  final number = trimmed.startsWith('+') ? '+$digits' : digits;
  final isIos = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  final separator = isIos ? '&' : '?';
  return Uri.parse('sms:$number${separator}body=${Uri.encodeComponent(body)}');
}

/// Ouvre un lien de contact (WhatsApp, SMS) dans l'application dédiée.
///
/// Toujours en `externalApplication` : le mode par défaut de url_launcher
/// ouvre un lien `https` (`wa.me`) dans une webview interne, où WhatsApp ne
/// se lance pas. Le lanceur de la plateforme est lu à l'appel, ce qui permet
/// aux tests de le remplacer par `UrlLauncherPlatform.instance`.
class ContactLinkLauncher {
  ContactLinkLauncher({UrlLauncherPlatform? launcher}) : _launcher = launcher;

  final UrlLauncherPlatform? _launcher;

  /// `false` si aucune application ne prend le lien ou si le lanceur lève :
  /// jamais d'exception propagée, l'appelant bascule sur son repli.
  Future<bool> open(Uri uri) async {
    try {
      return await (_launcher ?? UrlLauncherPlatform.instance).launchUrl(
        uri.toString(),
        const LaunchOptions(mode: PreferredLaunchMode.externalApplication),
      );
    } catch (_) {
      return false;
    }
  }
}
