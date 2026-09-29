import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'connect_onboarding_event.dart';
part 'connect_onboarding_state.dart';

class ConnectOnboardingBloc
    extends Bloc<ConnectOnboardingEvent, ConnectOnboardingState> {
  final IConnectOnboardingRepository _repository;

  /// Nullable pour les tests qui ne regardent pas l'analytics ; la DI en
  /// fournit toujours un.
  final AnalyticsService? _analytics;

  ConnectOnboardingBloc(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(const ConnectOnboardingInitial()) {
    on<ConnectOnboardingStatusRequested>(_onStatusRequested);
    on<ConnectOnboardingLinkRequested>(_onLinkRequested);
    on<ConnectOnboardingPollingRequested>(_onPollingRequested);
    on<ConnectOnboardingLaunchFailed>(_onLaunchFailed);
  }

  Future<void> _onStatusRequested(
    ConnectOnboardingStatusRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(const ConnectOnboardingLoading());
    try {
      final status = await _repository.getAccountStatus();
      if (status.isComplete) {
        emit(const ConnectOnboardingComplete());
      } else if (status.isDisabled) {
        emit(const ConnectOnboardingDisabled());
      } else if (status.isRejected) {
        emit(ConnectOnboardingRejected(reason: status.reason));
      } else if (status.needsOnboarding) {
        emit(const ConnectOnboardingNeedsOnboarding());
      } else {
        emit(const ConnectOnboardingPending());
      }
    } catch (e) {
      emit(ConnectOnboardingError(unwrapDioError(e)));
    }
  }

  Future<void> _onLinkRequested(
    ConnectOnboardingLinkRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(const ConnectOnboardingLoading());
    try {
      // Le lien d'onboarding suppose un compte Connect déjà provisionné : sans
      // lui le serveur répond 409 `stripe-account-required`, que le catalogue
      // d'erreurs rend par « L'état actuel ne permet pas cette action ». Tous
      // les points d'entrée qui mènent ici (publication d'un trajet, détail
      // d'annonce, étape prix, feuilles de blocage…) tombaient dessus, alors
      // que le parcours « Recevoir mes paiements » du profil, lui, créait bien
      // le compte avant de demander le lien. La création est idempotente côté
      // serveur : on l'aligne ici plutôt que sur chaque appelant.
      final account = await _repository.createConnectAccount();
      if (account.isComplete) {
        emit(const ConnectOnboardingComplete());
        return;
      }
      final url = await _repository.createOnboardingLink();
      emit(ConnectOnboardingUrlReady(url));
      _log(AnalyticsEvents.connectOnboardingLinkOpened);
    } catch (e) {
      final error = unwrapDioError(e);
      emit(ConnectOnboardingError(error));
      _logFailed('link', error.code);
    }
  }

  Future<void> _onPollingRequested(
    ConnectOnboardingPollingRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    // Passer par Loading n'est pas cosmétique. Les états sont des `const` sans
    // égalité de valeur : Dart les canonicalise, donc réémettre
    // ConnectOnboardingPending alors qu'on y est déjà est ignoré par Bloc. Sans
    // cette transition intermédiaire, taper « J'ai complété le formulaire »
    // sans avoir fini ne produisait strictement rien à l'écran, ni spinner ni
    // message, et l'utilisateur retapait dans le vide.
    emit(const ConnectOnboardingLoading());
    try {
      final status = await _repository.getAccountStatus();
      // Le poll suit un retour du formulaire Stripe : c'est ici, et non au
      // chargement initial du statut, qu'une activation se produit.
      if (status.isComplete) {
        emit(const ConnectOnboardingComplete());
        _log(AnalyticsEvents.connectOnboardingCompleted);
      } else if (status.isDisabled) {
        emit(const ConnectOnboardingDisabled());
        _logFailed('disabled', null);
      } else if (status.isRejected) {
        emit(ConnectOnboardingRejected(reason: status.reason));
        _logFailed('rejected', status.reason);
      } else {
        emit(const ConnectOnboardingPending());
        _log(AnalyticsEvents.connectOnboardingStillPending);
      }
    } catch (e) {
      final error = unwrapDioError(e);
      emit(ConnectOnboardingError(error));
      _logFailed('status', error.code);
    }
  }

  void _log(String event, [Map<String, Object>? properties]) {
    final analytics = _analytics;
    if (analytics == null) return;
    unawaited(analytics.logEvent(event, properties: properties));
  }

  void _logFailed(String stage, String? reason) => _log(
    AnalyticsEvents.connectOnboardingFailed,
    {'stage': stage, 'reason': ?reason},
  );

  Future<void> _onLaunchFailed(
    ConnectOnboardingLaunchFailed event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(
      const ConnectOnboardingError(
        NetworkException(
          "Impossible d'ouvrir le navigateur.", // i18n-ignore : code absent du catalogue, jamais affiché tel quel (ErrorCatalog retombe sur le message réseau générique), aligné sur payment-already-done
          code: 'launch-failed',
        ),
      ),
    );
    _logFailed('launch', 'launch-failed');
  }
}
