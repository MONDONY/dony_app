import 'package:dony/core/error/app_exception.dart';
import 'package:uuid/uuid.dart';

/// Clés d'idempotence (`Idempotency-Key`) des créations de trajet d'un même
/// formulaire.
///
/// Une clé par tentative logique de création, créée à la première demande et
/// gardée tant qu'un renvoi doit retomber sur le trajet déjà créé :
///  - elle RESTE LA MÊME après un échec où le serveur a pu créer le trajet
///    (pas de réponse, délai dépassé, connexion perdue, 5xx) : le renvoi du
///    formulaire rend le trajet créé au lieu d'en créer un second ;
///  - elle est RENOUVELÉE après un refus définitif du serveur (4xx :
///    validation, limite de brouillons ou mensuelle…) : rien n'a été créé et
///    le voyageur va corriger sa saisie ;
///  - elle n'est JAMAIS renouvelée après un succès : un renvoi du même
///    formulaire retombe sur le trajet créé.
///
/// Une clé par intention : brouillon serveur et publication, trajet simple et
/// voyage à étapes (la route et le corps diffèrent) ne partagent jamais la
/// leur.
///
/// Le formulaire porte l'instance (un simple champ de son `State`, pas d'état
/// d'affichage). La clé ne part jamais dans l'analytics ni dans les logs.
class TripCreationKeys {
  TripCreationKeys({String Function()? generate})
    : _generate = generate ?? (() => const Uuid().v4());

  final String Function() _generate;
  final Map<(bool, bool), String> _keys = {};
  (bool, bool)? _last;

  /// Clé de l'intention demandée, créée si besoin. Mémorise cette intention
  /// comme la dernière envoyée, celle que [onFailure] et [renewLast]
  /// concernent.
  String keyFor({required bool saveAsDraft, required bool multiLeg}) {
    final slot = (saveAsDraft, multiLeg);
    _last = slot;
    return _keys.putIfAbsent(slot, _generate);
  }

  /// Échec de la dernière création envoyée : la clé est renouvelée seulement
  /// si le serveur a refusé pour de bon ([mayHaveBeenCreated] faux).
  void onFailure(AppException error) {
    if (!mayHaveBeenCreated(error)) renewLast();
  }

  /// Oublie la clé de la dernière intention : la prochaine demande en crée une
  /// nouvelle. Sans effet avant le premier envoi.
  void renewLast() {
    final slot = _last;
    if (slot != null) _keys.remove(slot);
  }

  /// `true` quand le serveur a pu créer le trajet malgré l'échec : aucune
  /// réponse (délai dépassé, connexion perdue, socket coupée), 5xx ou erreur
  /// non classée. `false` pour un refus 4xx, où rien n'a été créé. Dans le
  /// doute, la clé est gardée : le renvoi retombe au pire sur un trajet déjà
  /// créé, jamais sur un doublon.
  static bool mayHaveBeenCreated(AppException error) {
    if (error is ValidationException ||
        error is UnauthorizedException ||
        error is ForbiddenException ||
        error is NotFoundException ||
        error is ConflictException ||
        error is RateLimitException) {
      return false;
    }
    // Un 4xx sans type dédié (405, 410…) arrive en NetworkException dont le
    // code est le statut HTTP.
    if (error is NetworkException) {
      final status = int.tryParse(error.code ?? '');
      if (status != null && status >= 400 && status < 500) return false;
    }
    return true;
  }
}
