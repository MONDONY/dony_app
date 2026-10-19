import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/receptions_prompt_store.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route de l'onglet Suivi ouverte sur « Réceptions ».
const String kReceptionsSegmentRoute =
    '/tracking?mode=suivre&segment=receptions';

sealed class ReceptionsPromptState {
  const ReceptionsPromptState();
}

class ReceptionsPromptHidden extends ReceptionsPromptState {
  const ReceptionsPromptHidden();
}

class ReceptionsPromptVisible extends ReceptionsPromptState {
  const ReceptionsPromptVisible(this.pending);

  /// Colis à confirmer, jamais vide.
  final List<Reception> pending;

  /// Prénom de l'expéditeur quand un seul colis attend et qu'il est connu.
  String? get senderFirstName =>
      pending.length == 1 ? pending.single.senderFirstName : null;

  /// Un seul colis : son écran ; plusieurs : la liste de l'onglet Suivi.
  String get route => pending.length == 1
      ? '/receptions/${pending.single.bidId}'
      : kReceptionsSegmentRoute;
}

/// Bandeau « Un colis vous attend » de l'accueil (YADONY-FLUTTER-PROD-12).
///
/// Une destinataire qui vient de s'inscrire arrivait sur l'accueil sans rien
/// voir : les réceptions n'étaient chargées que dans l'onglet Suivi. Le
/// cubit lit `GET /receptions` une fois par compte (l'appel rattache aussi
/// côté back les colis envoyés à son numéro) et montre les colis encore à
/// confirmer, sauf ceux dont le bandeau a été fermé. Silencieux en échec :
/// un back sans la route (404) ou hors ligne, rien ne s'affiche.
class ReceptionsPromptCubit extends Cubit<ReceptionsPromptState> {
  ReceptionsPromptCubit(this._repository, this._store, this._analytics)
    : super(const ReceptionsPromptHidden());

  final ReceptionRepository _repository;
  final ReceptionsPromptStore _store;
  final AnalyticsService _analytics;

  String? _loadedFor;

  /// Charge pour le compte [userId], une seule fois par compte. `null`
  /// (visiteur, déconnexion) masque le bandeau.
  Future<void> loadFor(String? userId) async {
    if (userId == null) {
      _loadedFor = null;
      emit(const ReceptionsPromptHidden());
      return;
    }
    if (userId == _loadedFor) return;
    _loadedFor = userId;
    emit(const ReceptionsPromptHidden());
    try {
      final receptions = await _repository.getReceptions();
      if (isClosed || _loadedFor != userId) return;
      final dismissed = _store.dismissed();
      final pending = receptions
          .where((r) => r.isPending && !dismissed.contains(r.bidId))
          .toList(growable: false);
      if (pending.isEmpty) return;
      emit(ReceptionsPromptVisible(pending));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.receptionsPromptShown,
          properties: {'count': pending.length},
        ),
      );
    } catch (_) {
      // Bandeau secondaire : jamais d'erreur affichée.
    }
  }

  /// Toucher le bandeau : rend la route à ouvrir, ou `null` s'il est masqué.
  String? tap() {
    final current = state;
    if (current is! ReceptionsPromptVisible) return null;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.receptionsPromptTapped,
        properties: {'count': current.pending.length},
      ),
    );
    return current.route;
  }

  /// Croix : le bandeau ne revient plus pour ces colis sur cet appareil.
  Future<void> dismiss() async {
    final current = state;
    if (current is! ReceptionsPromptVisible) return;
    emit(const ReceptionsPromptHidden());
    await _store.dismiss(current.pending.map((r) => r.bidId));
  }
}
