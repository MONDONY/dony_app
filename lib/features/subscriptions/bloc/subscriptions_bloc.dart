import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  final SubscriptionsRepository _repository;
  final AnalyticsService _analytics;
  StreamSubscription<BlockChange>? _blockSub;

  /// [blockEvents] reste nullable pour les tests unitaires qui n'ont pas besoin
  /// des blocages ; la DI en fournit toujours une instance.
  SubscriptionsBloc(
    this._repository,
    this._analytics, {
    BlockEventsService? blockEvents,
  }) : super(const SubscriptionsState()) {
    on<LoadSubscriptions>(_onLoad);
    on<UnsubscribeTraveler>(_onUnsubscribe);
    on<ToggleSubscriptionPush>(_onTogglePush);
    on<MarkAllSubscriptionsSeen>(_onMarkAllSeen);

    // Le serveur masque les abonnements vers un compte bloqué et les rend au
    // déblocage : dans les deux sens la liste en mémoire est périmée.
    _blockSub = blockEvents?.changes.listen((_) {
      if (!isClosed) {
        add(const LoadSubscriptions());
      }
    });
  }

  @override
  Future<void> close() {
    _blockSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    LoadSubscriptions e,
    Emitter<SubscriptionsState> emit,
  ) async {
    emit(state.copyWith(status: SubscriptionsStatus.loading));
    try {
      final items = await _repository.getMySubscriptions();
      emit(state.copyWith(status: SubscriptionsStatus.success, items: items));
    } catch (err) {
      emit(
        state.copyWith(
          status: SubscriptionsStatus.error,
          error: err.toString(),
        ),
      );
    }
  }

  Future<void> _onUnsubscribe(
    UnsubscribeTraveler e,
    Emitter<SubscriptionsState> emit,
  ) async {
    try {
      await _repository.unsubscribe(e.travelerId);
      unawaited(_analytics.logEvent(AnalyticsEvents.subscriptionRemoved));
      emit(
        state.copyWith(
          items: state.items
              .where((i) => i.travelerId != e.travelerId)
              .toList(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: SubscriptionsStatus.error,
          error: err.toString(),
        ),
      );
    }
  }

  /// Optimiste : les pastilles disparaissent sans attendre le serveur, et un
  /// échec réseau les fait revenir plutôt que d'afficher une erreur pour une
  /// action sans conséquence.
  Future<void> _onMarkAllSeen(
    MarkAllSubscriptionsSeen e,
    Emitter<SubscriptionsState> emit,
  ) async {
    final previous = state.items;
    emit(
      state.copyWith(
        items: previous.map((i) => i.copyWith(hasNew: false)).toList(),
      ),
    );
    try {
      await _repository.markAllSeen();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.subscriptionsMarkedAllSeen,
          properties: {'count': previous.where((i) => i.hasNew).length},
        ),
      );
    } catch (_) {
      emit(state.copyWith(items: previous));
    }
  }

  Future<void> _onTogglePush(
    ToggleSubscriptionPush e,
    Emitter<SubscriptionsState> emit,
  ) async {
    try {
      final s = await _repository.setPush(e.travelerId, e.enabled);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.subscriptionPushToggled,
          properties: {'enabled': s.pushEnabled},
        ),
      );
      emit(
        state.copyWith(
          items: state.items
              .map(
                (i) => i.travelerId == e.travelerId
                    ? i.copyWith(pushEnabled: s.pushEnabled)
                    : i,
              )
              .toList(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: SubscriptionsStatus.error,
          error: err.toString(),
        ),
      );
    }
  }
}
