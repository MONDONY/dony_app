import 'dart:async';

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/billing/data/billing_repository.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

/// Pilote l'abonnement PRO affiché à l'écran et l'ouverture du portail web
/// externe (vente/gestion), qui vit hors de l'app.
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc(this._repository, this._analytics)
    : super(const SubscriptionInitial()) {
    on<SubscriptionRequested>(
      _onRequested,
      // Droppable, pour la même raison que l'ouverture du portail : une
      // demande en vol suffit, une seconde n'apporte rien.
      //
      // Le retour du portail en émet une (l'abonnement a pu changer), et la
      // bascule non-PRO → PRO qui suit le rafraîchissement de profil en émet
      // une autre. Sans ce transformateur, ce ne sont pas seulement deux
      // appels réseau : ce sont **deux `pro_subscription_viewed` comptés pour
      // une seule ouverture**, donc un double comptage dans les statistiques.
      transformer: (events, mapper) => events.exhaustMap(mapper),
    );
    on<ProPortalOpenRequested>(
      _onPortalOpenRequested,
      // Droppable : ignore toute nouvelle demande tant qu'une ouverture est
      // encore en vol, plutôt que de la mettre en file (ce que ferait un
      // transformateur "sequential" comme celui de `HelpCenterBloc`).
      // Un double appui rapide sur le bouton du portail ne doit jamais
      // ouvrir le navigateur une seconde fois : une demande mise en file
      // finirait par le faire quand même, une fois la première terminée.
      transformer: (events, mapper) => events.exhaustMap(mapper),
    );
  }

  final BillingRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onRequested(
    SubscriptionRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());
    try {
      final subscription = await _repository.getSubscription();
      unawaited(
        _track(
          AnalyticsEvents.proSubscriptionViewed,
          properties: {'status': subscription.status.name},
        ),
      );
      emit(SubscriptionLoaded(subscription));
    } catch (e) {
      emit(SubscriptionError(unwrapDioError(e)));
    }
  }

  Future<void> _onPortalOpenRequested(
    ProPortalOpenRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Capturé avant l'appel réseau : c'est l'état à restaurer si l'ouverture
    // échoue, pour que l'écran reste affiché sans changement visible.
    final previous = state;
    final uri = Uri.parse(
      event.target == ProPortalTarget.upgrade
          ? proPortalUpgradeUrl()
          : proPortalSubscriptionUrl(),
    );

    final success = await _repository.openExternal(uri);
    if (success) {
      unawaited(
        _track(
          AnalyticsEvents.proPortalOpened,
          properties: {'target': event.target.name},
        ),
      );
      return;
    }

    unawaited(
      _track(
        AnalyticsEvents.proPortalOpenFailed,
        properties: {'target': event.target.name},
      ),
    );
    // Signalement transitoire, puis restauration immédiate : voir la
    // documentation de SubscriptionPortalLaunchFailed sur pourquoi ce n'est
    // jamais un drapeau porté par SubscriptionLoaded.
    emit(
      SubscriptionPortalLaunchFailed(
        previous is SubscriptionLoaded ? previous.subscription : null,
      ),
    );
    emit(previous);
  }

  /// Enveloppe `AnalyticsService.logEvent` pour garantir que le tracking ne
  /// remonte jamais comme exception non gérée. Appelé `unawaited` : sans ce
  /// filet, une Future de tracking rejetée (backend PostHog en panne)
  /// échapperait au `try/catch` du handler — celui-ci a déjà rendu la main
  /// avant qu'elle ne s'exécute — et deviendrait une erreur de zone non
  /// interceptée, un comportement que le tracking ne doit jamais produire.
  Future<void> _track(String event, {Map<String, Object>? properties}) async {
    try {
      await _analytics.logEvent(event, properties: properties);
    } catch (_) {
      // Best-effort : voir la doc ci-dessus.
    }
  }
}
