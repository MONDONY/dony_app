import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Réinitialise Stripe quand Android rattache le moteur Flutter à une activité
/// recréée (FLUTTER-CJ, G5, G6, G7).
///
/// Le moteur est mis en cache (MainActivity, appels audio) : il survit à la
/// recréation de l'activité, mais le module natif de `stripe_android` reste
/// lié à l'activité détruite, ou est recréé sans clé publique. La feuille de
/// paiement échouait alors avant toute saisie (« FragmentManager has been
/// destroyed »). `StripeActivityReattachPlugin` (Kotlin) rattache Stripe à la
/// nouvelle activité puis appelle `activityReattached` sur ce canal ; on
/// renvoie ici les réglages Stripe (clé, merchant, scheme) au nouveau module.
///
/// Reproduction manuelle (procédure complète dans dony_app/CLAUDE.md, § 9 bis) :
/// Options développeur › « Ne pas conserver les activités », ou « Texte en
/// gras » app ouverte, puis ouvrir un paiement. Sans ce rattachement, la
/// feuille échoue aussitôt.
class StripeReattachListener {
  StripeReattachListener({
    MethodChannel? channel,
    Future<void> Function()? reinitialize,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _reinitialize = reinitialize ?? Stripe.instance.applySettings,
       _onError = onError;

  static const channelName = 'com.yadony.yadony/activity';
  static const reattachedMethod = 'activityReattached';

  final MethodChannel _channel;
  final Future<void> Function() _reinitialize;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  /// Branche l'écoute. Sans effet hors Android : seul le plugin Android
  /// garde une activité périmée.
  void start() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler(handle);
  }

  void stop() => _channel.setMethodCallHandler(null);

  @visibleForTesting
  Future<void> handle(MethodCall call) async {
    if (call.method != reattachedMethod) return;
    try {
      await _reinitialize();
    } catch (error, stackTrace) {
      // Un échec ici ne doit pas faire planter l'app : le paiement suivant
      // remontera l'erreur à l'utilisateur et à Sentry.
      _onError?.call(error, stackTrace);
    }
  }
}
