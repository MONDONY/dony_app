import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Paiement mobile money (opérateurs servis par pawaPay) d'un bid, d'un fil
/// de négociation ou du supplément de prix d'un colis, en trois étapes :
/// « Qui paie ? » (`MobileMoneyPaymentChoosePayer`, numéro et opérateur
/// choisis parmi ceux que le voyageur accepte), attente de la validation chez
/// l'opérateur (sondage périodique), puis issue (séquestre, refus, expiration).
///
/// Échéance passée avec un dépôt encore ouvert : le back n'annule rien tant
/// que le dépôt n'a pas de statut final, l'écran attend honnêtement
/// (`MobileMoneyPaymentOverdue`, sondage maintenu) au lieu d'annoncer un délai
/// dépassé.
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
    on<MobileMoneyPaymentResendRequested>(_onResendRequested);
    on<MobileMoneyPaymentChangePayerRequested>(_onChangePayerRequested);
    on<MobileMoneyStatusPolled>(_onPolled);
  }

  final MobileMoneyRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  /// Opérateurs acceptés par le voyageur, lus une fois par écran : « Payer
  /// avec un autre numéro » les réutilise sans nouvel appel. `null` après un
  /// 404 (back ancien) : aucune restriction.
  MobileMoneyAcceptedOperators? _accepted;
  bool _acceptedLoaded = false;

  /// Numéro complet et opérateur du dernier dépôt créé par cet écran, pour
  /// « Renvoyer une demande ». Inconnu quand l'écran reprend un dépôt créé
  /// ailleurs (notification) : le back n'expose que le numéro masqué.
  ({String phoneNumber, String? provider})? _lastPayer;

  /// Une relance avec le même numéro et le même opérateur est possible.
  bool get canResend => _lastPayer != null;

  Future<void> _onOpened(
    MobileMoneyPaymentOpened event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      final status = await _repository.getStatus(event.scope);
      final known = _stateFor(status, event.scope);
      if (known != null && !_isResidualCancelled(known, status, event.scope)) {
        _emitKnown(known, emit, event.scope);
        return;
      }
      emit(
        MobileMoneyPaymentChoosePayer(
          status: status,
          accepted: await _loadAccepted(event.scope),
        ),
      );
    } catch (e) {
      _emitError(emit, e, event.scope, 'open');
    }
  }

  /// Une ligne `CANCELLED` résiduelle sur un fil (renoncement, dépôt refusé
  /// ou échéance) n'est pas une expiration à afficher : le fil est revenu à
  /// « à payer » et le backend recycle la ligne au prochain `initiate`. Seul
  /// le suivi d'un dépôt en cours traduit `CANCELLED` en Expired. Un
  /// supplément `CANCELLED` (refusé, expiré, retiré) est clos pour de bon :
  /// rien à recycler, l'expiration s'affiche.
  bool _isResidualCancelled(
    MobileMoneyPaymentState known,
    MobileMoneyPaymentStatus status,
    MobileMoneyScope scope,
  ) =>
      known is MobileMoneyPaymentExpired &&
      status.isReverted &&
      !scope.cancelledIsFinal;

  /// Opérateurs acceptés, lus au plus une fois avec succès. Une erreur autre
  /// que 404 ne bloque pas le paiement : choix sans restriction, le back
  /// revérifie à l'initiation, et la lecture sera retentée au prochain retour
  /// à l'étape « Qui paie ? ».
  Future<MobileMoneyAcceptedOperators?> _loadAccepted(
    MobileMoneyScope scope,
  ) async {
    if (_acceptedLoaded) return _accepted;
    try {
      _accepted = await _repository.acceptedOperators(scope);
      _acceptedLoaded = true;
    } catch (e) {
      AppLog.warn(
        'mobile money: accepted operators unavailable',
        data: {
          'scope': scope.analyticsName,
          'error_code': unwrapDioError(e).code ?? 'unknown',
        },
      );
    }
    return _accepted;
  }

  Future<void> _onInitiateRequested(
    MobileMoneyPaymentInitiateRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final choosing = state;
    // Jamais de second dépôt : ni pendant un envoi déjà en cours (double
    // appui, le transformateur d'événements est concurrent), ni pendant
    // l'attente d'un dépôt vivant, ni une fois le paiement séquestré. Le
    // premier handler émet `isSubmitting`/`Loading` avant tout `await` : le
    // second voit donc déjà cet état.
    if (_initiateBlocked(choosing)) return;
    if (choosing is MobileMoneyPaymentChoosePayer) {
      // Le bandeau d'un refus précédent disparaît pendant le nouvel essai.
      emit(
        MobileMoneyPaymentChoosePayer(
          status: choosing.status,
          accepted: choosing.accepted,
          isSubmitting: true,
        ),
      );
    } else {
      emit(const MobileMoneyPaymentLoading());
    }
    try {
      await _initiateAndEmit(
        event.scope,
        event.phoneNumber,
        event.provider,
        emit,
      );
    } catch (e) {
      if (await _showRejectedDeposit(
        e,
        event.scope,
        event.phoneNumber,
        event.provider,
        emit,
      )) {
        return;
      }
      if (choosing is! MobileMoneyPaymentChoosePayer) {
        _emitError(emit, e, event.scope, 'initiate');
        return;
      }
      // Refus d'initiation (422 : opérateur non accepté, numéro refusé...) ou
      // réseau : l'expéditeur reste sur son choix, le motif en bandeau.
      final appError = unwrapDioError(e);
      emit(
        MobileMoneyPaymentChoosePayer(
          status: choosing.status,
          accepted: choosing.accepted,
          error: appError,
        ),
      );
      _logCallFailure(appError, event.scope, 'initiate');
    }
  }

  /// États où une initiation ne doit pas partir : envoi déjà en cours,
  /// chargement, dépôt vivant (avant ou après l'échéance), paiement
  /// séquestré. `Initial`, `Error`, `ChoosePayer` (hors envoi),
  /// `DepositFailed` et `Expired` restent ouverts, comme avant.
  bool _initiateBlocked(MobileMoneyPaymentState s) => switch (s) {
    MobileMoneyPaymentChoosePayer(:final isSubmitting) => isSubmitting,
    MobileMoneyPaymentLoading() ||
    MobileMoneyPaymentAwaitingConfirmation() ||
    MobileMoneyPaymentOverdue() ||
    MobileMoneyPaymentEscrowed() => true,
    _ => false,
  };

  /// Relance depuis un dépôt refusé avec le dernier couple connu. Sans
  /// couple connu, ou hors d'un dépôt refusé (un dépôt est en cours, ou le
  /// paiement est clos), rien ne part : jamais de second dépôt en parallèle.
  Future<void> _onResendRequested(
    MobileMoneyPaymentResendRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final payer = _lastPayer;
    if (payer == null || state is! MobileMoneyPaymentDepositFailed) return;
    emit(const MobileMoneyPaymentLoading());
    try {
      await _initiateAndEmit(
        event.scope,
        payer.phoneNumber,
        payer.provider,
        emit,
      );
    } catch (e) {
      if (await _showRejectedDeposit(
        e,
        event.scope,
        payer.phoneNumber,
        payer.provider,
        emit,
      )) {
        return;
      }
      _emitError(emit, e, event.scope, 'initiate');
    }
  }

  /// Refus immédiat de l'opérateur à l'initiation (422
  /// `mobile-money-deposit-rejected`) : le dépôt refusé existe côté back avec
  /// son motif traduit (`failureReasonCode`, `failureMessage`). On relit le
  /// statut et on montre le même écran qu'un refus constaté au sondage
  /// ([MobileMoneyPaymentDepositFailed] : motif, « Renvoyer une demande »,
  /// « Payer avec un autre numéro »), au lieu du seul message générique du
  /// 422. Le couple numéro et opérateur est retenu pour la relance. Rend
  /// `false` (l'appelant garde son comportement d'erreur) quand ce n'est pas
  /// ce refus, quand la relecture échoue ou ne montre aucun dépôt refusé.
  ///
  /// L'état est émis directement, sans `_emitKnown` : le refus est tracé ici,
  /// une seule fois, en `mobile_money_failed` `stage: initiate`.
  Future<bool> _showRejectedDeposit(
    Object error,
    MobileMoneyScope scope,
    String? phoneNumber,
    String? provider,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final appError = unwrapDioError(error);
    if (appError.code != 'mobile-money-deposit-rejected') return false;
    final MobileMoneyPaymentState? next;
    try {
      next = _stateFor(await _repository.getStatus(scope), scope);
    } catch (_) {
      return false;
    }
    if (next is! MobileMoneyPaymentDepositFailed) return false;
    _lastPayer = phoneNumber == null
        ? null
        : (phoneNumber: phoneNumber, provider: provider);
    emit(next);
    _logCallFailure(appError, scope, 'initiate');
    return true;
  }

  /// Retour à l'étape « Qui paie ? » depuis un dépôt refusé. Les opérateurs
  /// acceptés déjà lus sont réutilisés ; ils ne sont lus qu'ici quand l'écran
  /// a été rouvert directement sur le refus.
  Future<void> _onChangePayerRequested(
    MobileMoneyPaymentChangePayerRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    final current = state;
    final status = switch (current) {
      MobileMoneyPaymentDepositFailed() => current.status,
      MobileMoneyPaymentChoosePayer(isSubmitting: false) => current.status,
      _ => null,
    };
    if (status == null) return;
    final accepted = await _loadAccepted(event.scope);
    // Pendant la lecture des opérateurs, une relance a pu lancer un dépôt
    // (ou un sondage clore le paiement) : ne jamais masquer ce nouvel état
    // sous l'étape « Qui paie ? » (dépôt vivant caché, sondage coupé).
    if (state != current) return;
    emit(MobileMoneyPaymentChoosePayer(status: status, accepted: accepted));
  }

  Future<void> _onPolled(
    MobileMoneyStatusPolled event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    try {
      final status = await _repository.getStatus(event.scope);
      final known = _stateFor(status, event.scope);
      // `null` : aucun dépôt encore renvoyé par le backend (rare en plein
      // sondage) — on garde l'état courant plutôt que de perdre l'écran.
      if (known == null) return;
      // Pendant le choix d'un payeur, le back rapporte encore l'ancien dépôt
      // refusé (ou la ligne résiduelle d'un fil) tant qu'aucun nouveau n'est
      // lancé : un sondage tardif ne doit pas faire quitter le choix.
      if (state is MobileMoneyPaymentChoosePayer &&
          (known is MobileMoneyPaymentDepositFailed ||
              _isResidualCancelled(known, status, event.scope))) {
        return;
      }
      // Même ligne résiduelle pendant la lecture d'ouverture (Initial ou
      // Loading, opérateurs acceptés lents) : `Opened` va conclure par
      // l'étape « Qui paie ? », un sondage ne doit pas la précéder d'un
      // Expired ni de ses events analytics.
      if ((state is MobileMoneyPaymentInitial ||
              state is MobileMoneyPaymentLoading) &&
          _isResidualCancelled(known, status, event.scope)) {
        return;
      }
      _emitKnown(known, emit, event.scope);
    } catch (e) {
      // Sondage silencieux : une erreur réseau transitoire ne casse pas
      // l'écran, le prochain sondage réessaiera. Exception : rien n'a encore
      // pu être affiché (Initial/Loading), il faut bien sortir du spinner.
      if (state is MobileMoneyPaymentInitial ||
          state is MobileMoneyPaymentLoading) {
        _emitError(emit, e, event.scope, 'poll');
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
    // Un dépôt créé sans numéro explicite (numéro du compte côté back) ne
    // laisse aucun numéro complet à réutiliser.
    _lastPayer = phoneNumber == null
        ? null
        : (phoneNumber: phoneNumber, provider: provider);
    final next =
        _stateFor(status, scope) ??
        MobileMoneyPaymentAwaitingConfirmation(status);
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
    final wasExpired = state is MobileMoneyPaymentExpired;
    emit(next);
    if (next is MobileMoneyPaymentEscrowed && !wasEscrowed) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyConfirmed,
          properties: {'scope': scope.analyticsName},
        ),
      );
      _logPayment(AnalyticsEvents.paymentSucceeded, next.status, scope);
    } else if (next is MobileMoneyPaymentDepositFailed && !wasFailed) {
      final failureCode = next.status.deposit?.failureCode ?? '';
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyFailed,
          properties: {
            'failure_code': failureCode,
            'scope': scope.analyticsName,
          },
        ),
      );
      _logPayment(AnalyticsEvents.paymentFailed, next.status, scope, {
        'reason': 'declined',
        'error_code': failureCode.isEmpty ? 'unknown' : failureCode,
      });
    } else if (next is MobileMoneyPaymentExpired &&
        !wasExpired &&
        // Un remboursement n'est pas un paiement échoué : il a abouti avant.
        !next.status.isRefunded &&
        !next.status.isRefundInProgress) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyExpired,
          properties: {'scope': scope.analyticsName},
        ),
      );
      _logPayment(AnalyticsEvents.paymentFailed, next.status, scope, {
        'reason': 'expired',
      });
    }
  }

  /// Issue d'un paiement mobile money d'un colis (ou de son supplément de
  /// prix, `bid_supplement`, ou de sa modification, `bid_amendment`) dans la
  /// famille commune `payment_succeeded` / `payment_failed`
  /// (`method: mobile_money`), pour
  /// lire tous les moyens dans un même tableau. Les événements
  /// `mobile_money_*` restent émis à côté.
  void _logPayment(
    String event,
    MobileMoneyPaymentStatus status,
    MobileMoneyScope scope, [
    Map<String, Object> extra = const {},
  ]) {
    final amount = status.amount;
    final provider = status.deposit?.providerLabel;
    unawaited(
      _analytics.logEvent(
        event,
        properties: {
          'method': AnalyticsPaymentMethod.mobileMoney,
          'context': switch (scope) {
            BidMobileMoneyScope() => AnalyticsPaymentContext.bid,
            NegotiationMobileMoneyScope() =>
              AnalyticsPaymentContext.negotiation,
            SupplementMobileMoneyScope() =>
              AnalyticsPaymentContext.bidSupplement,
            AmendmentMobileMoneyScope() => AnalyticsPaymentContext.bidAmendment,
          },
          'currency': status.currency,
          if (amount != null) 'amount_bracket': analyticsAmountBracket(amount),
          'provider': ?provider,
          ...extra,
        },
      ),
    );
  }

  /// Émet l'erreur à l'écran et la trace en `mobile_money_failed`.
  void _emitError(
    Emitter<MobileMoneyPaymentState> emit,
    Object error,
    MobileMoneyScope scope,
    String stage,
  ) {
    final appError = unwrapDioError(error);
    emit(MobileMoneyPaymentError(appError));
    _logCallFailure(appError, scope, stage);
  }

  /// Trace un échec d'appel en `mobile_money_failed` : un échec d'appel
  /// (réseau, 422 à l'initiation) n'atteignait jamais PostHog, seuls les
  /// dépôts refusés par l'opérateur y figuraient. Propriétés `failure_code`
  /// (code métier, `unknown` sans code), `stage` (`open`, `initiate`, `poll`)
  /// et `scope`.
  void _logCallFailure(
    AppException appError,
    MobileMoneyScope scope,
    String stage,
  ) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.mobileMoneyFailed,
        properties: {
          'failure_code': appError.code ?? 'unknown',
          'stage': stage,
          'scope': scope.analyticsName,
        },
      ),
    );
  }

  /// Traduit un statut serveur en état d'écran. Ordre de priorité : un
  /// paiement déjà séquestré prime sur tout ; un supplément remboursé ou en
  /// cours de remboursement n'est plus à payer (fenêtre close) ; un dépôt
  /// encore ouvert après l'échéance attend son statut final (Overdue, jamais
  /// Expired : le back n'annule rien avant) ; puis l'expiration, l'échec du
  /// dernier dépôt, un dépôt encore en cours. `null` quand aucun dépôt n'a
  /// jamais été tenté : l'expéditeur doit d'abord choisir qui paie.
  ///
  /// Supplément et modification : un statut que l'app ne connaît pas encore
  /// (back plus récent) passe d'abord par l'échéance : échu, il expire ; sinon il
  /// s'affiche « en cours » plutôt que de rouvrir un choix que le back
  /// refuserait. Exception : avec un dépôt encore ouvert et l'échéance
  /// passée, `Overdue` prime aussi pour ce statut inconnu (le back attend
  /// l'issue du dépôt avant de clore le supplément ou la modification).
  MobileMoneyPaymentState? _stateFor(
    MobileMoneyPaymentStatus s,
    MobileMoneyScope scope,
  ) {
    if (s.isEscrowed) return MobileMoneyPaymentEscrowed(s);
    // Supplément et modification ont leur propre fenêtre de paiement, close
    // pour de bon (`CANCELLED` définitif) : mêmes règles.
    final ownWindow = scope.cancelledIsFinal;
    if (ownWindow && (s.isRefunded || s.isRefundInProgress)) {
      return MobileMoneyPaymentExpired(s);
    }
    if (_isOverdue(s)) return MobileMoneyPaymentOverdue(s);
    if (s.isExpired(_now())) return MobileMoneyPaymentExpired(s);
    if (ownWindow && !s.hasKnownPaymentStatus) {
      return MobileMoneyPaymentAwaitingConfirmation(s);
    }
    if (s.isDepositFailed) return MobileMoneyPaymentDepositFailed(s);
    if (s.isDepositLive) return MobileMoneyPaymentAwaitingConfirmation(s);
    return null;
  }

  /// Échéance passée, dépôt encore ouvert côté opérateur, sujet ni annulé ni
  /// libéré : l'expéditeur peut encore valider son code.
  bool _isOverdue(MobileMoneyPaymentStatus s) {
    final deadline = s.deadlineAt;
    return s.isDepositLive &&
        deadline != null &&
        _now().isAfter(deadline) &&
        s.subjectStatus != 'CANCELLED' &&
        s.paymentStatus != 'CANCELLED';
  }
}
