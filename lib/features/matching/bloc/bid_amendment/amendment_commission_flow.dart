import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// 3DS de la commission abandonnée ou refusée par la banque : la modification
/// reste en `COMMISSION_PENDING` côté serveur.
class AmendmentCommissionAuthInterrupted implements Exception {
  const AmendmentCommissionAuthInterrupted(this.cause);

  final Object cause;

  @override
  String toString() => 'AmendmentCommissionAuthInterrupted($cause)';
}

/// Commission d'une modification payée en espèces, prélevée au voyageur à
/// l'acceptation : la carte peut demander une 3DS (`commissionClientSecret`),
/// puis `POST …/commission/confirm`. Calque de [SupplementCommissionFlow], et
/// trace le mouvement d'argent (`context: bid_amendment_commission`).
class AmendmentCommissionFlow {
  AmendmentCommissionFlow(
    this._repository,
    this._analytics, {
    SupplementNextAction? nextAction,
  }) : _nextAction = nextAction ?? _stripeNextAction;

  final BidAmendmentRepository _repository;
  final AnalyticsService _analytics;
  final SupplementNextAction _nextAction;

  /// Une 3DS réussie peut, rarement, en appeler une seconde.
  static const maxAuthRounds = 2;

  static Future<void> _stripeNextAction(String clientSecret) async {
    await Stripe.instance.handleNextAction(clientSecret);
  }

  /// Tant que le serveur rend un client secret : 3DS puis confirmation. Rend
  /// la dernière vue du serveur. Lève [AmendmentCommissionAuthInterrupted] si
  /// la 3DS est abandonnée, les erreurs de l'API telles quelles sinon.
  Future<BidAmendment> settle(String bidId, BidAmendment amendment) async {
    var current = amendment;
    for (var round = 0; round < maxAuthRounds; round++) {
      if (!current.needsCommissionAuth) return current;
      try {
        await _nextAction(current.commissionClientSecret!);
      } catch (e) {
        throw AmendmentCommissionAuthInterrupted(e);
      }
      current = await _repository.confirmCommission(bidId, current.id);
    }
    return current;
  }

  /// Commission prélevée (`payment_succeeded`).
  void logCharged(BidAmendment amendment, SupplementCommissionSource source) {
    final commission = amendment.commissionAmount;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: {
          'method': _method(source),
          'context': AnalyticsPaymentContext.bidAmendmentCommission,
          'currency': amendment.currency,
          'amount_bracket': ?(commission == null
              ? null
              : analyticsAmountBracket(commission)),
        },
      ),
    );
  }

  /// Commission non prélevée (`payment_failed`).
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
          'context': AnalyticsPaymentContext.bidAmendmentCommission,
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
