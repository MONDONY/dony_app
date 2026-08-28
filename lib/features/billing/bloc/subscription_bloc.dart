import 'dart:async';

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/billing/data/billing_repository.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

/// Pilote l'abonnement PRO affiché à l'écran et l'ouverture du portail web
/// externe (vente/gestion), qui vit hors de l'app.
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc(this._repository, this._analytics)
    : super(const SubscriptionInitial()) {
    on<SubscriptionRequested>(_onRequested);
    on<ProPortalOpenRequested>(_onPortalOpenRequested);
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
        _analytics.logEvent(
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
        _analytics.logEvent(
          AnalyticsEvents.proPortalOpened,
          properties: {'target': event.target.name},
        ),
      );
      return;
    }

    unawaited(
      _analytics.logEvent(
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
}
