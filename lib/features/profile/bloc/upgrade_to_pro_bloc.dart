import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'upgrade_to_pro_event.dart';
part 'upgrade_to_pro_state.dart';

/// Code métier RFC 7807 rendu par `DELETE /auth/me/upgrade-to-pro` quand
/// l'abonnement en cours vient de Stripe et donne encore accès : la
/// résiliation passe alors obligatoirement par le portail web.
///
/// Le serveur porte ce code dans la propriété `code` du `ProblemDetail`, en
/// plus de `type`. Ne jamais se raccrocher à `title` ou `detail`, qui sont de
/// la copie et peuvent changer sans préavis.
const String kActiveStripeSubscriptionCode = 'active-stripe-subscription';

/// Ne pilote plus qu'un seul geste : le retour en compte standard.
///
/// La souscription PRO n'existe plus dans l'application : elle se fait sur le
/// portail web (`SubscriptionBloc` / `ProPortalTarget.upgrade`).
/// `POST /auth/me/upgrade-to-pro` n'accorde plus le statut PRO côté serveur,
/// un formulaire local ne pourrait donc que mentir sur son effet.
class UpgradeToProBloc extends Bloc<UpgradeToProEvent, UpgradeToProState> {
  UpgradeToProBloc(this._repository, this._analytics)
    : super(UpgradeToProInitial()) {
    on<DowngradeRequested>(_onDowngrade);
  }

  final ProfileRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onDowngrade(
    DowngradeRequested event,
    Emitter<UpgradeToProState> emit,
  ) async {
    emit(UpgradeToProLoading());
    try {
      await _repository.downgradePro();
      emit(DowngradeSuccess());
    } catch (e) {
      final error = unwrapDioError(e);
      if (error.code == kActiveStripeSubscriptionCode) {
        // Aucune propriété : ni identifiant, ni message serveur. L'event ne
        // mesure qu'une chose, le fait que le refus se soit produit.
        unawaited(_track(AnalyticsEvents.proDowngradeBlocked));
      }
      emit(DowngradeError(error));
    }
  }

  /// Enveloppe `AnalyticsService.logEvent` pour que le tracking ne remonte
  /// jamais comme exception non gérée. Appelé `unawaited` : sans ce filet,
  /// une Future de tracking rejetée échapperait au `try/catch` du handler,
  /// qui a déjà rendu la main, et deviendrait une erreur de zone.
  Future<void> _track(String event, {Map<String, Object>? properties}) async {
    try {
      await _analytics.logEvent(event, properties: properties);
    } catch (_) {
      // Best-effort : voir la doc ci-dessus.
    }
  }
}
