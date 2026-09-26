import 'package:flutter/services.dart';

/// Pastille de l'icône de l'application, le compteur rouge sur l'écran d'accueil.
///
/// iOS ne laisse que l'application effacer sa propre pastille. Lire les notifications,
/// dans le centre de notifications comme dans l'application, n'y change rien. Le backend
/// posait `1` en dur sur chaque push et rien ne remettait jamais la valeur à zéro : l'icône
/// affichait 1 dès la première notification reçue et le gardait pour toujours.
///
/// Les trois compteurs sont tenus séparément parce qu'ils viennent de trois sources qui
/// n'arrivent pas ensemble : le fil de notifications par l'API, la messagerie par Firestore,
/// le support par l'API. Le total n'est écrit sur l'icône que lorsqu'il change vraiment, pour
/// ne pas traverser la frontière native à chaque émission d'un flux.
class AppBadgeService {
  AppBadgeService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.yadony.yadony/app_badge';

  final MethodChannel _channel;

  int _notifications = 0;
  int _messages = 0;
  int _support = 0;
  int? _lastWritten;

  /// Ce que porte l'icône : tout ce qui attend l'utilisateur.
  int get total => _notifications + _messages + _support;

  Future<void> setNotifications(int count) =>
      _write(() => _notifications = _sane(count));

  Future<void> setMessages(int count) => _write(() => _messages = _sane(count));

  Future<void> setSupport(int count) => _write(() => _support = _sane(count));

  /// Remet tout à zéro, à la déconnexion notamment : une pastille ne doit pas
  /// survivre au compte qui l'a produite.
  Future<void> clear() => _write(() {
    _notifications = 0;
    _messages = 0;
    _support = 0;
  });

  static int _sane(int count) => count < 0 ? 0 : count;

  Future<void> _write(void Function() mutate) async {
    mutate();
    final value = total;
    if (value == _lastWritten) return;
    _lastWritten = value;
    try {
      await _channel.invokeMethod<void>('setBadge', <String, dynamic>{
        'count': value,
      });
    } on MissingPluginException {
      // Android : la pastille appartient au lanceur, il n'y a rien à écrire ici.
    } on PlatformException {
      // Pastille refusée, autorisation retirée par exemple. Sans conséquence
      // sur le reste de l'application.
    }
  }
}
