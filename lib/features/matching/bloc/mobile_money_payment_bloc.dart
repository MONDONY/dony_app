import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Paiement mobile money (Wave / Orange Money via pawaPay) d'un bid ou d'un
/// fil de négociation : ouverture de l'écran d'attente, initiation d'un
/// dépôt, sondage périodique du statut jusqu'au séquestre ou à l'expiration.
///
/// Côté bid, l'expéditeur choisit d'abord un opérateur parmi ceux acceptés
/// par le voyageur (`MobileMoneyPaymentChooseOperator`) avant qu'un dépôt ne
/// soit lancé ; côté fil de négociation, le back n'expose pas de catalogue
/// et l'initiation reste directe (lot 2, inchangé).
///
/// Style identique à `MobileMoneyAccountBloc` : le repository ne fait que
/// passer, c'est ici que les erreurs sont déballées (`unwrapDioError`) et
/// que les events analytics sont tirés, en `unawaited`, après l'émission.
class MobileMoneyPaymentBloc
    extends Bloc<MobileMoneyPaymentEvent, MobileMoneyPaymentState> {
  MobileMoneyPaymentBloc(
    this._repository,
    this._analytics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const MobileMoneyPaymentInitial()) {
    on<MobileMoneyPaymentOpened>(_onOpened);
    on<MobileMoneyPaymentInitiateRequested>(_onInitiateRequested);
    on<MobileMoneyPaymentProvidersRequested>(_onProvidersRequested);
    on<MobileMoneyStatusPolled>(_onPolled);
  }

  final MobileMoneyRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  Future<void> _onOpened(
    MobileMoneyPaymentOpened event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      final status = await _repository.getStatus(event.scope);
      final known = _stateFor(status);
      // Une ligne `CANCELLED` résiduelle sur un fil (renoncement, dépôt refusé
      // ou échéance) n'est pas une expiration à afficher : le fil est revenu
      // à « à payer » et le backend recycle la ligne au prochain `initiate`.
      // Seul un sondage en cours de suivi traduit `CANCELLED` en Expired.
      final residualCancelled =
          known is MobileMoneyPaymentExpired && status.isReverted;
      if (known != null && !residualCancelled) {
        _emitKnown(known, emit, event.scope);
        return;
      }
      final scope = event.scope;
      if (scope is BidMobileMoneyScope) {
        // Aucun dépôt encore tenté (ou ligne recyclable) pour ce bid :
        // l'expéditeur choisit d'abord son opérateur parmi ceux acceptés par
        // le voyageur (spec du 2026-09-11).
        await _loadCatalogAndEmit(scope, status, event.phoneNumber, null, emit);
      } else {
        // Fil de négociation : pas de catalogue côté back (lot 2), on initie
        // directement, comme avant.
        await _initiateAndEmit(scope, event.phoneNumber, null, emit);
      }
    } catch (e) {
      emit(MobileMoneyPaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onProvidersRequested(
    MobileMoneyPaymentProvidersRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final current = state;
    final (status, previous) = switch (current) {
      MobileMoneyPaymentChooseOperator() => (current.status, current.catalog),
      MobileMoneyPaymentDepositFailed() => (current.status, null),
      MobileMoneyPaymentAwaitingConfirmation() => (current.status, null),
      _ => (null, null),
    };
    // Sans statut connu, rien à recharger : l'écran repassera par Opened.
    if (status == null) return;
    try {
      await _loadCatalogAndEmit(
        event.scope,
        status,
        event.phoneNumber,
        previous,
        emit,
      );
    } catch (e) {
      // Symétrique à _onInitiateRequested : _loadCatalogAndEmit peut
      // retomber sur _initiateAndEmit (404, ou scope sans catalogue) sans
      // protection propre, cet appel pouvant lui-même échouer (réseau,
      // 422...). Sans ce filet, l'écran resterait figé sur
      // ChooseOperator(isLoadingCatalog: true) sans bandeau ni reprise.
      emit(MobileMoneyPaymentError(unwrapDioError(e)));
    }
  }

  /// Charge le catalogue payeur d'un bid et émet l'étape de choix. Un fil de
  /// négociation n'a pas de catalogue côté back (lot 2) : initiation directe
  /// sans opérateur, exactement comme le repli 404 d'un ancien back sur un
  /// bid. Un 404 sur un bid signale de même un back sans catalogue (ancien
  /// contrat) : on initie directement, comme avant, sans opérateur.
  Future<void> _loadCatalogAndEmit(
    MobileMoneyScope scope,
    MobileMoneyPaymentStatus status,
    String? phoneNumber,
    MobileMoneyProviderCatalog? previous,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(
      MobileMoneyPaymentChooseOperator(
        status: status,
        catalog: previous,
        payerPhone: phoneNumber,
        isLoadingCatalog: true,
      ),
    );
    if (scope is! BidMobileMoneyScope) {
      await _initiateAndEmit(scope, phoneNumber, null, emit);
      return;
    }
    try {
      final catalog = await _repository.providers(
        scope.id,
        phoneNumber: phoneNumber,
      );
      emit(
        MobileMoneyPaymentChooseOperator(
          status: status,
          catalog: catalog,
          payerPhone: phoneNumber,
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      if (error is NotFoundException) {
        await _initiateAndEmit(scope, phoneNumber, null, emit);
        return;
      }
      emit(
        MobileMoneyPaymentChooseOperator(
          status: status,
          catalog: previous,
          payerPhone: phoneNumber,
          error: error,
        ),
      );
    }
  }

  Future<void> _onInitiateRequested(
    MobileMoneyPaymentInitiateRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      await _initiateAndEmit(
        event.scope,
        event.phoneNumber,
        event.provider,
        emit,
      );
    } catch (e) {
      emit(MobileMoneyPaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onPolled(
    MobileMoneyStatusPolled event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    try {
      final status = await _repository.getStatus(event.scope);
      final known = _stateFor(status);
      // `null` : aucun dépôt encore renvoyé par le backend (rare en plein
      // sondage) — on garde l'état courant plutôt que de perdre l'écran.
      if (known != null) {
        _emitKnown(known, emit, event.scope);
      }
    } catch (e) {
      // Sondage silencieux : une erreur réseau transitoire ne casse pas
      // l'écran, le prochain sondage réessaiera. Exception : rien n'a encore
      // pu être affiché (Initial/Loading), il faut bien sortir du spinner.
      if (state is MobileMoneyPaymentInitial ||
          state is MobileMoneyPaymentLoading) {
        emit(MobileMoneyPaymentError(unwrapDioError(e)));
      }
    }
  }

  /// Appelle `initiate`, calcule l'état suivant (le résultat peut lui-même
  /// être déjà séquestré ou refusé), l'émet, puis journalise la tentative
  /// d'initiation — après l'émission, comme les autres events analytics.
  Future<void> _initiateAndEmit(
    MobileMoneyScope scope,
    String? phoneNumber,
    String? provider,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final status = await _repository.initiate(
      scope,
      phoneNumber: phoneNumber,
      provider: provider,
    );
    final next =
        _stateFor(status) ?? MobileMoneyPaymentAwaitingConfirmation(status);
    _emitKnown(next, emit, scope);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.mobileMoneyInitiated,
        properties: {
          'provider': status.deposit?.providerLabel ?? 'inconnu',
          'chosen': provider != null,
          'wave': status.isWaveRedirect,
          'scope': scope.analyticsName,
        },
      ),
    );
  }

  /// Émet [next] et journalise, une seule fois par transition, l'analytics
  /// de confirmation ou d'échec du dépôt — comparé à l'état courant juste
  /// avant l'émission, pour ne jamais re-déclencher l'event sur un sondage
  /// qui confirme un état déjà connu.
  void _emitKnown(
    MobileMoneyPaymentState next,
    Emitter<MobileMoneyPaymentState> emit,
    MobileMoneyScope scope,
  ) {
    final wasEscrowed = state is MobileMoneyPaymentEscrowed;
    final wasFailed = state is MobileMoneyPaymentDepositFailed;
    emit(next);
    if (next is MobileMoneyPaymentEscrowed && !wasEscrowed) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyConfirmed,
          properties: {'scope': scope.analyticsName},
        ),
      );
    } else if (next is MobileMoneyPaymentDepositFailed && !wasFailed) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyFailed,
          properties: {
            'failure_code': next.status.deposit?.failureCode ?? '',
            'scope': scope.analyticsName,
          },
        ),
      );
    }
  }

  /// Traduit un statut serveur en état d'écran. Ordre de priorité : un
  /// paiement déjà séquestré prime sur l'expiration, qui prime sur l'échec
  /// du dernier dépôt, qui prime sur un dépôt encore en cours. `null` quand
  /// aucun dépôt n'a jamais été tenté : il faut en initier un (ou, pour un
  /// bid, choisir d'abord un opérateur).
  MobileMoneyPaymentState? _stateFor(MobileMoneyPaymentStatus s) {
    if (s.isEscrowed) return MobileMoneyPaymentEscrowed(s);
    if (s.isExpired(_now())) return MobileMoneyPaymentExpired(s);
    if (s.isDepositFailed) return MobileMoneyPaymentDepositFailed(s);
    if (s.isDepositLive) return MobileMoneyPaymentAwaitingConfirmation(s);
    return null;
  }
}
