import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SupplementActionStatus { idle, busy, done, failure }

class SupplementActionState {
  const SupplementActionState({
    this.status = SupplementActionStatus.idle,
    this.error,
  });

  final SupplementActionStatus status;
  final AppException? error;

  bool get isBusy => status == SupplementActionStatus.busy;
}

/// Actions des encarts du supplément dans le détail d'envoi : le voyageur
/// retire sa demande, l'expéditeur la refuse. Le paiement par l'expéditeur
/// s'ajoutera ici avec les rails (PR A2 à A4). Après [SupplementActionStatus.done],
/// l'encart fait relire le colis.
class SupplementActionCubit extends Cubit<SupplementActionState> {
  SupplementActionCubit(this._repository, this._analytics)
    : super(const SupplementActionState());

  final BidSupplementRepository _repository;
  final AnalyticsService _analytics;
  bool _viewed = false;

  /// Encart affiché : une seule fois par encart, quel que soit le nombre de
  /// relectures du colis.
  void viewed({required bool isSender, required BidSupplementStatus status}) {
    if (_viewed) return;
    _viewed = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementViewed,
        properties: {
          'role': isSender ? 'sender' : 'traveler',
          'status': status.name,
        },
      ),
    );
  }

  Future<void> withdraw(BidModel bid, BidSupplement supplement) => _run(
    action: 'withdraw',
    call: () => _repository.withdraw(bid.id, supplement.id),
    onDone: () =>
        unawaited(_analytics.logEvent(AnalyticsEvents.bidSupplementWithdrawn)),
  );

  Future<void> decline(BidModel bid, BidSupplement supplement) => _run(
    action: 'decline',
    call: () => _repository.decline(bid.id, supplement.id),
    onDone: () => unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementDeclined,
        properties: {'payment_method': bid.paymentMethod.name},
      ),
    ),
  );

  Future<void> _run({
    required String action,
    required Future<BidSupplement> Function() call,
    required void Function() onDone,
  }) async {
    if (state.isBusy) return;
    emit(const SupplementActionState(status: SupplementActionStatus.busy));
    try {
      await call();
      if (isClosed) return;
      emit(const SupplementActionState(status: SupplementActionStatus.done));
      onDone();
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        SupplementActionState(
          status: SupplementActionStatus.failure,
          error: error,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidSupplementActionFailed,
          properties: {'action': action, 'error_code': error.code ?? 'unknown'},
        ),
      );
    }
  }
}
