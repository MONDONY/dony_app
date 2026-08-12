import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TravelerHubBloc extends Bloc<TravelerHubEvent, TravelerHubState> {
  final SubscriptionsRepository _repository;
  String travelerId = '';

  TravelerHubBloc(this._repository) : super(const TravelerHubState()) {
    on<LoadTravelerHub>(_onLoad);
    on<HubSubscribePressed>(_onSubscribe);
    on<HubUnsubscribePressed>(_onUnsubscribe);
    on<HubTogglePush>(_onTogglePush);
  }

  Future<void> _onLoad(LoadTravelerHub e, Emitter<TravelerHubState> emit) async {
    if (state.status == TravelerHubStatus.loading) {
      return;
    }
    travelerId = e.travelerId;
    emit(state.copyWith(status: TravelerHubStatus.loading));
    try {
      final results = await Future.wait([
        _repository.getStatus(e.travelerId),
        _repository.getTravelerAnnouncements(e.travelerId),
      ]);
      final status = results[0] as SubscriptionStatus;
      final anns = results[1] as List<TravelerAnnouncement>;
      if (status.subscribed) {
        await _repository.markSeen(e.travelerId);
      }
      emit(state.copyWith(
        status: TravelerHubStatus.success,
        subscribed: status.subscribed,
        pushEnabled: status.pushEnabled,
        announcements: anns,
      ));
    } catch (err) {
      emit(state.copyWith(status: TravelerHubStatus.error, error: err.toString()));
    }
  }

  Future<void> _onSubscribe(HubSubscribePressed e, Emitter<TravelerHubState> emit) async {
    try {
      await _repository.subscribe(travelerId);
      emit(state.copyWith(subscribed: true));
    } catch (err) {
      emit(state.copyWith(status: TravelerHubStatus.error, error: err.toString()));
    }
  }

  Future<void> _onUnsubscribe(HubUnsubscribePressed e, Emitter<TravelerHubState> emit) async {
    try {
      await _repository.unsubscribe(travelerId);
      emit(state.copyWith(subscribed: false, pushEnabled: false));
    } catch (err) {
      emit(state.copyWith(status: TravelerHubStatus.error, error: err.toString()));
    }
  }

  Future<void> _onTogglePush(HubTogglePush e, Emitter<TravelerHubState> emit) async {
    try {
      final s = await _repository.setPush(travelerId, e.enabled);
      emit(state.copyWith(pushEnabled: s.pushEnabled));
    } catch (err) {
      emit(state.copyWith(status: TravelerHubStatus.error, error: err.toString()));
    }
  }
}
