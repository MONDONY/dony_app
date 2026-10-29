import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AmendmentActionStatus { idle, busy, done, failure }

class AmendmentActionState {
  const AmendmentActionState({
    this.status = AmendmentActionStatus.idle,
    this.error,
  });

  final AmendmentActionStatus status;
  final AppException? error;

  bool get isBusy => status == AmendmentActionStatus.busy;
}

/// Actions des encarts de la modification dans le détail d'envoi :
/// l'expéditeur annule sa demande, le voyageur la refuse ou déclare que les
/// kilos en plus ne sont pas là. Après [AmendmentActionStatus.done], l'encart
/// fait relire le colis.
class AmendmentActionCubit extends Cubit<AmendmentActionState> {
  AmendmentActionCubit(this._repository, this._analytics)
    : super(const AmendmentActionState());

  final BidAmendmentRepository _repository;
  final AnalyticsService _analytics;
  bool _viewed = false;

  /// Encart affiché : une seule fois par encart, quel que soit le nombre de
  /// relectures du colis.
  void viewed({required bool isSender, required BidAmendmentStatus status}) {
    if (_viewed) return;
    _viewed = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidAmendmentViewed,
        properties: {
          'role': isSender ? 'sender' : 'traveler',
          'status': status.wire,
        },
      ),
    );
  }

  Future<void> cancel(BidModel bid, BidAmendment a) => _run(
    action: 'cancel',
    call: () => _repository.cancel(bid.id, a.id),
    onDone: () =>
        unawaited(_analytics.logEvent(AnalyticsEvents.bidAmendmentCancelled)),
  );

  Future<void> decline(BidModel bid, BidAmendment a) => _run(
    action: 'decline',
    call: () => _repository.decline(bid.id, a.id),
    onDone: () => _logWithMethod(AnalyticsEvents.bidAmendmentDeclined, a),
  );

  Future<void> notBrought(BidModel bid, BidAmendment a) => _run(
    action: 'not_brought',
    call: () => _repository.notBrought(bid.id, a.id),
    onDone: () => _logWithMethod(AnalyticsEvents.bidAmendmentNotBrought, a),
  );

  void _logWithMethod(String event, BidAmendment a) => unawaited(
    _analytics.logEvent(event, properties: {'method': amendmentMethodOf(a)}),
  );

  Future<void> _run({
    required String action,
    required Future<BidAmendment> Function() call,
    required void Function() onDone,
  }) async {
    if (state.isBusy) return;
    emit(const AmendmentActionState(status: AmendmentActionStatus.busy));
    try {
      await call();
      // Mesuré même si l'encart s'est fermé pendant l'appel (sheet refermé de
      // force) : l'action est confirmée par le serveur.
      onDone();
      if (isClosed) return;
      emit(const AmendmentActionState(status: AmendmentActionStatus.done));
    } catch (e) {
      final error = unwrapDioError(e);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidAmendmentActionFailed,
          properties: {'action': action, 'error_code': error.code ?? 'unknown'},
        ),
      );
      if (isClosed) return;
      emit(
        AmendmentActionState(
          status: AmendmentActionStatus.failure,
          error: error,
        ),
      );
    }
  }
}

/// Moyen de paiement de la modification, pour l'analytics :
/// `card` / `mobile_money` / `cash`.
String amendmentMethodOf(BidAmendment a) => a.isCash
    ? 'cash'
    : a.isMobileMoney
    ? 'mobile_money'
    : 'card';
