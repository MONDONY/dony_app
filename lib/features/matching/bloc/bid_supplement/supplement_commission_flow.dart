import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Authentification bancaire (3DS) d'une PaymentIntent à partir de son
/// client secret (`Stripe.instance.handleNextAction` par défaut). Lève une
/// erreur si le voyageur l'abandonne ou si la banque la refuse.
typedef SupplementNextAction = Future<void> Function(String clientSecret);

/// 3DS de la commission abandonnée ou refusée par la banque : la demande
/// reste en `COMMISSION_PENDING` côté serveur, « Réessayer » la relance.
class SupplementCommissionAuthInterrupted implements Exception {
  const SupplementCommissionAuthInterrupted(this.cause);

  final Object cause;

  @override
  String toString() => 'SupplementCommissionAuthInterrupted($cause)';
}

/// Commission du supplément d'un colis payé en espèces, prélevée au voyageur
/// à la demande (décision du 19/10). Même mécanique que la commission d'une
/// acceptation en espèces (`BidAcceptanceBloc`) : la carte peut demander une
/// 3DS (`commissionClientSecret`), puis `POST …/commission/confirm`.
///
/// Partagé par la feuille de demande (`SupplementRequestCubit`) et l'encart
/// du voyageur (`SupplementCommissionCubit`, reprise d'une 3DS abandonnée).
/// Trace aussi le mouvement d'argent (`payment_succeeded` /
/// `payment_failed`, `context: bid_supplement_commission`), une seule fois
/// par issue : chaque appelant n'atteint une issue qu'une fois par geste.
class SupplementCommissionFlow {
  SupplementCommissionFlow(
    this._repository,
    this._analytics, {
    SupplementNextAction? nextAction,
  }) : _nextAction = nextAction ?? _stripeNextAction;

  final BidSupplementRepository _repository;
  final AnalyticsService _analytics;
  final SupplementNextAction _nextAction;

  /// Une 3DS réussie peut, rarement, en appeler une seconde : au-delà, la
  /// demande reste en attente et le voyageur réessaie.
  static const maxAuthRounds = 2;

  static Future<void> _stripeNextAction(String clientSecret) async {
    await Stripe.instance.handleNextAction(clientSecret);
  }

  /// Mène une demande jusqu'à l'expéditeur : tant que le serveur rend un
  /// client secret, 3DS puis confirmation. Rend la dernière vue du serveur
  /// (`PROPOSED` une fois la commission prélevée ; `COMMISSION_PENDING` sans
  /// secret quand Stripe traite encore, le webhook tranchera).
  ///
  /// Lève [SupplementCommissionAuthInterrupted] si la 3DS est abandonnée, et
  /// les erreurs de l'API telles quelles (carte refusée, réseau).
  Future<BidSupplement> settle(String bidId, BidSupplement supplement) async {
    var current = supplement;
    for (var round = 0; round < maxAuthRounds; round++) {
      if (!current.needsCommissionAuth) return current;
      try {
        await _nextAction(current.commissionClientSecret!);
      } catch (e) {
        throw SupplementCommissionAuthInterrupted(e);
      }
      current = await _repository.confirmCommission(bidId, current.id);
    }
    return current;
  }

  /// Reprend une demande restée en `COMMISSION_PENDING` (3DS abandonnée,
  /// débit sans réponse) : `…/commission/confirm`, jamais un nouveau
  /// `POST` (il rendrait 409 `supplement-already-active`), puis [settle].
  Future<BidSupplement> resume(String bidId, String supplementId) async =>
      settle(bidId, await _repository.confirmCommission(bidId, supplementId));

  /// Commission prélevée (`payment_succeeded`). Sans effet si rien n'a été
  /// prélevé (taux nul, back antérieur sans `commissionStatus`).
  void logCharged(BidSupplement supplement, SupplementCommissionSource source) {
    if (!supplement.commissionCharged) return;
    final commission = supplement.commissionAmount;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: {
          'method': _method(source),
          'context': AnalyticsPaymentContext.bidSupplementCommission,
          'currency': supplement.currency,
          'amount_bracket': ?(commission == null
              ? null
              : analyticsAmountBracket(commission)),
        },
      ),
    );
  }

  /// Commission non prélevée (`payment_failed`) : `reason` parmi
  /// `insufficient_balance`, `declined`, `authentication_failed`,
  /// `card_missing`, `generic`.
  void logFailed(
    SupplementCommissionSource source, {
    required String reason,
    required String errorCode,
    String? currency,
  }) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.paymentFailed,
        properties: {
          'method': _method(source),
          'context': AnalyticsPaymentContext.bidSupplementCommission,
          'reason': reason,
          'error_code': errorCode,
          'currency': ?currency,
        },
      ),
    );
  }

  static String _method(SupplementCommissionSource source) => switch (source) {
    SupplementCommissionSource.wallet => AnalyticsPaymentMethod.walletBalance,
    SupplementCommissionSource.card => AnalyticsPaymentMethod.card,
  };
}
