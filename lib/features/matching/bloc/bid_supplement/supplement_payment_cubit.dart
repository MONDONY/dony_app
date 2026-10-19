import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SupplementPaymentStatus {
  idle,

  /// Vérification locale (`requirePaymentAuth`) ouverte : le bouton est
  /// désactivé, un double tap n'ouvre pas une seconde invite.
  authorizing,

  /// `POST …/accept` en cours.
  accepting,

  /// PaymentIntent prêt : l'écran ouvre la feuille de paiement avec
  /// [SupplementPaymentState.checkout].
  readyToPay,

  /// Paiement autorisé, `POST …/confirm-payment` en cours.
  confirming,

  /// Supplément payé (ou déjà payé), confirmé par le serveur : l'écran
  /// relit le colis et annonce le succès.
  paid,

  /// Paiement autorisé par la feuille mais pas encore confirmé payé par le
  /// serveur (traitement Stripe en cours, `payment-busy`, réseau) : message
  /// neutre et relecture du colis, jamais « payé ».
  confirmationPending,
  failure,
}

class SupplementPaymentState extends Equatable {
  const SupplementPaymentState({
    this.status = SupplementPaymentStatus.idle,
    this.checkout,
    this.error,
  });

  final SupplementPaymentStatus status;
  final SupplementCheckout? checkout;
  final AppException? error;

  bool get isBusy =>
      status == SupplementPaymentStatus.authorizing ||
      status == SupplementPaymentStatus.accepting ||
      status == SupplementPaymentStatus.readyToPay ||
      status == SupplementPaymentStatus.confirming;

  @override
  List<Object?> get props => [status, checkout, error];
}

/// Paiement par carte d'un supplément de prix par l'expéditeur (PR A2).
///
/// L'écran pose [beginAuthorization], passe `requirePaymentAuth`, puis
/// appelle [pay] (ou [authorizationDenied] sur un refus), ouvre la feuille de
/// paiement sur [SupplementPaymentStatus.readyToPay] et attend [confirmPayment]
/// dans son `onSuccess`. Le paiement lui-même (`payment_*`) est tracé par la
/// feuille (`PaymentSheetBloc`, `context: bid_supplement`), jamais ici.
class SupplementPaymentCubit extends Cubit<SupplementPaymentState> {
  SupplementPaymentCubit(
    this._repository,
    this._analytics, {
    ErrorReportingService? errorReporter,
  }) : _errorReporter = errorReporter,
       super(const SupplementPaymentState());

  final BidSupplementRepository _repository;
  final AnalyticsService _analytics;
  final ErrorReportingService? _errorReporter;

  /// Accepte le supplément : rend le PaymentIntent à présenter, ou passe
  /// directement à [SupplementPaymentStatus.paid] s'il n'y a plus rien à
  /// payer (supplément déjà payé ailleurs).
  Future<void> pay(BidModel bid, BidSupplement supplement) async {
    if (state.isBusy && state.status != SupplementPaymentStatus.authorizing) {
      return;
    }
    emit(
      const SupplementPaymentState(status: SupplementPaymentStatus.accepting),
    );
    try {
      final checkout = await _repository.accept(bid.id, supplement.id);
      if (isClosed) return;
      if (!checkout.needsPayment) {
        emit(
          SupplementPaymentState(
            status: SupplementPaymentStatus.paid,
            checkout: checkout,
          ),
        );
        return;
      }
      emit(
        SupplementPaymentState(
          status: SupplementPaymentStatus.readyToPay,
          checkout: checkout,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidSupplementPaymentStarted,
          properties: {
            'method': AnalyticsPaymentMethod.card,
            'currency': checkout.currency,
            'amount_bracket': analyticsAmountBracket(checkout.amount),
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        SupplementPaymentState(
          status: SupplementPaymentStatus.failure,
          error: error,
        ),
      );
      _logFailure('pay', error);
    }
  }

  /// Ouvre la vérification locale. Rend `false` si une action est déjà en
  /// cours (double tap) : l'appelant n'ouvre alors pas d'invite.
  bool beginAuthorization() {
    if (isClosed || state.isBusy) return false;
    emit(
      const SupplementPaymentState(status: SupplementPaymentStatus.authorizing),
    );
    return true;
  }

  /// Vérification refusée ou abandonnée : le bouton revient.
  void authorizationDenied() {
    if (isClosed || state.status != SupplementPaymentStatus.authorizing) {
      return;
    }
    emit(const SupplementPaymentState());
  }

  /// Feuille fermée sans paiement : le supplément reste `PAYMENT_PENDING`
  /// côté serveur et le bouton « Payer » revient. Sans effet après un succès
  /// (la confirmation est déjà partie).
  void sheetClosed() {
    if (isClosed || state.status != SupplementPaymentStatus.readyToPay) return;
    emit(const SupplementPaymentState());
  }

  /// Confirme au serveur le paiement autorisé par la feuille. À attendre
  /// dans `onSuccess`, sans garde de montage : la requête doit partir même si
  /// l'écran se ferme. Seul un statut payé rendu par le serveur mène à
  /// [SupplementPaymentStatus.paid] ; un statut encore en attente ou un échec
  /// (rapporté, le webhook Stripe prend le relais) mène à
  /// [SupplementPaymentStatus.confirmationPending].
  Future<void> confirmPayment(BidModel bid, BidSupplement supplement) async {
    if (!isClosed) {
      emit(
        SupplementPaymentState(
          status: SupplementPaymentStatus.confirming,
          checkout: state.checkout,
        ),
      );
    }
    var confirmed = false;
    try {
      final result = await _repository.confirmPayment(bid.id, supplement.id);
      confirmed = result.status.isPaid;
    } catch (e, stackTrace) {
      _logFailure('confirm_payment', unwrapDioError(e));
      await _errorReporter?.report(
        e,
        operation: 'bid.supplement.confirmPayment',
        stackTrace: stackTrace,
      );
    }
    if (isClosed) return;
    emit(
      SupplementPaymentState(
        status: confirmed
            ? SupplementPaymentStatus.paid
            : SupplementPaymentStatus.confirmationPending,
        checkout: state.checkout,
      ),
    );
  }

  void _logFailure(String action, AppException error) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementActionFailed,
        properties: {'action': action, 'error_code': error.code ?? 'unknown'},
      ),
    );
  }
}
