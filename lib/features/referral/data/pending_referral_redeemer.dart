import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:dony/features/referral/data/referral_repository.dart';

/// Résultat de l'application automatique du code venu d'un lien.
enum PendingReferralOutcome {
  /// Aucun code en attente : rien n'a été tenté.
  none,

  /// Le serveur a accepté le code.
  applied,

  /// Le serveur (ou le réseau) a refusé le code : on n'en dit rien, la
  /// personne ne l'a jamais saisi.
  rejected,
}

/// Applique, sans que la personne ait à le saisir, le code parrain gardé par
/// [PendingReferralCodeStore] après un lien d'invitation.
///
/// Appelé une fois, juste après une nouvelle inscription. Le code est
/// toujours effacé dès qu'il a été tenté : un code refusé (inconnu, déjà
/// parrainé, auto-parrainage, réseau) ne doit pas être rejoué. Ne lève jamais.
class PendingReferralRedeemer {
  PendingReferralRedeemer(this._store, this._repository, this._analytics);

  final PendingReferralCodeStore _store;
  final ReferralRepository _repository;
  final AnalyticsService _analytics;

  Future<PendingReferralOutcome> apply() async {
    final code = _store.current;
    if (code == null) return PendingReferralOutcome.none;

    var outcome = PendingReferralOutcome.applied;
    try {
      await _repository.redeemCode(code);
    } catch (_) {
      outcome = PendingReferralOutcome.rejected;
    }
    await _store.clear();

    // Aucune PII : jamais la valeur du code.
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.referralAutoApplied,
        properties: {'outcome': outcome.name},
      ),
    );
    return outcome;
  }
}
