import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Paiement mobile money (Wave / Orange Money via pawaPay) d'un bid :
/// ouverture de l'écran d'attente, initiation d'un dépôt, sondage
/// périodique du statut jusqu'au séquestre ou à l'expiration.
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
      final status = await _repository.getStatus(
        MobileMoneyScope.bid(event.bidId),
      );
      final known = _stateFor(status);
      if (known != null) {
        _emitKnown(known, emit);
        return;
      }
      // Aucun dépôt encore tenté pour ce bid : on en lance un immédiatement,
      // l'écran d'attente n'a pas de raison d'afficher un état intermédiaire
      // "rien à payer" avant que l'utilisateur agisse.
      await _initiateAndEmit(event.bidId, null, emit);
    } catch (e) {
      emit(MobileMoneyPaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onInitiateRequested(
    MobileMoneyPaymentInitiateRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      await _initiateAndEmit(event.bidId, event.phoneNumber, emit);
    } catch (e) {
      emit(MobileMoneyPaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onPolled(
    MobileMoneyStatusPolled event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    try {
      final status = await _repository.getStatus(
        MobileMoneyScope.bid(event.bidId),
      );
      final known = _stateFor(status);
      // `null` : aucun dépôt encore renvoyé par le backend (rare en plein
      // sondage) — on garde l'état courant plutôt que de perdre l'écran.
      if (known != null) {
        _emitKnown(known, emit);
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
    String bidId,
    String? phoneNumber,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final status = await _repository.initiate(
      MobileMoneyScope.bid(bidId),
      phoneNumber: phoneNumber,
    );
    final next =
        _stateFor(status) ?? MobileMoneyPaymentAwaitingConfirmation(status);
    _emitKnown(next, emit);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.mobileMoneyInitiated,
        properties: {
          'provider': status.deposit?.providerLabel ?? 'inconnu',
          'wave': status.isWaveRedirect,
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
  ) {
    final wasEscrowed = state is MobileMoneyPaymentEscrowed;
    final wasFailed = state is MobileMoneyPaymentDepositFailed;
    emit(next);
    if (next is MobileMoneyPaymentEscrowed && !wasEscrowed) {
      unawaited(_analytics.logEvent(AnalyticsEvents.mobileMoneyConfirmed));
    } else if (next is MobileMoneyPaymentDepositFailed && !wasFailed) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyFailed,
          properties: {'failure_code': next.status.deposit?.failureCode ?? ''},
        ),
      );
    }
  }

  /// Traduit un statut serveur en état d'écran. Ordre de priorité : un
  /// paiement déjà séquestré prime sur l'expiration, qui prime sur l'échec
  /// du dernier dépôt, qui prime sur un dépôt encore en cours. `null` quand
  /// aucun dépôt n'a jamais été tenté : il faut en initier un.
  MobileMoneyPaymentState? _stateFor(MobileMoneyPaymentStatus s) {
    if (s.isEscrowed) return MobileMoneyPaymentEscrowed(s);
    if (s.isExpired(_now())) return MobileMoneyPaymentExpired(s);
    if (s.isDepositFailed) return MobileMoneyPaymentDepositFailed(s);
    if (s.isDepositLive) return MobileMoneyPaymentAwaitingConfirmation(s);
    return null;
  }
}
