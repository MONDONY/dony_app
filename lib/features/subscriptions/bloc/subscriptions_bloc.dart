import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  final SubscriptionsRepository _repository;

  SubscriptionsBloc(this._repository) : super(const SubscriptionsState()) {
    on<LoadSubscriptions>(_onLoad);
    on<UnsubscribeTraveler>(_onUnsubscribe);
    on<ToggleSubscriptionPush>(_onTogglePush);
  }

  Future<void> _onLoad(
      LoadSubscriptions e, Emitter<SubscriptionsState> emit) async {
    emit(state.copyWith(status: SubscriptionsStatus.loading));
    try {
      final items = await _repository.getMySubscriptions();
      emit(state.copyWith(status: SubscriptionsStatus.success, items: items));
    } catch (err) {
      emit(state.copyWith(
          status: SubscriptionsStatus.error, error: err.toString()));
    }
  }

  Future<void> _onUnsubscribe(
      UnsubscribeTraveler e, Emitter<SubscriptionsState> emit) async {
    try {
      await _repository.unsubscribe(e.travelerId);
      emit(state.copyWith(
        items: state.items
            .where((i) => i.travelerId != e.travelerId)
            .toList(),
      ));
    } catch (err) {
      emit(state.copyWith(
          status: SubscriptionsStatus.error, error: err.toString()));
    }
  }

  Future<void> _onTogglePush(
      ToggleSubscriptionPush e, Emitter<SubscriptionsState> emit) async {
    try {
      final s = await _repository.setPush(e.travelerId, e.enabled);
      emit(state.copyWith(
        items: state.items
            .map((i) => i.travelerId == e.travelerId
                ? i.copyWith(pushEnabled: s.pushEnabled)
                : i)
            .toList(),
      ));
    } catch (err) {
      emit(state.copyWith(
          status: SubscriptionsStatus.error, error: err.toString()));
    }
  }
}
