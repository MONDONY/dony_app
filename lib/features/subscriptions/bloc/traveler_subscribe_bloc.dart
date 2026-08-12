import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BLoC léger pour la barre « S'abonner » d'un voyageur (statut + abonnement +
/// cloche push). Ne charge PAS les annonces — contrairement à TravelerHubBloc.
class TravelerSubscribeBloc
    extends Bloc<TravelerSubscribeEvent, TravelerSubscribeState> {
  final SubscriptionsRepository _repository;
  String travelerId = '';

  TravelerSubscribeBloc(this._repository)
      : super(const TravelerSubscribeState()) {
    on<LoadSubscribeStatus>(_onLoad);
    on<SubscribePressed>(_onSubscribe);
    on<UnsubscribePressed>(_onUnsubscribe);
    on<TogglePushPressed>(_onTogglePush);
  }

  Future<void> _onLoad(
      LoadSubscribeStatus e, Emitter<TravelerSubscribeState> emit) async {
    travelerId = e.travelerId;
    emit(state.copyWith(status: TravelerSubscribeStatus.loading));
    try {
      final status = await _repository.getStatus(e.travelerId);
      emit(state.copyWith(
        status: TravelerSubscribeStatus.ready,
        subscribed: status.subscribed,
        pushEnabled: status.pushEnabled,
      ));
    } catch (err) {
      emit(state.copyWith(
          status: TravelerSubscribeStatus.error, error: err.toString()));
    }
  }

  Future<void> _onSubscribe(
      SubscribePressed e, Emitter<TravelerSubscribeState> emit) async {
    try {
      await _repository.subscribe(travelerId);
      emit(state.copyWith(
          status: TravelerSubscribeStatus.ready, subscribed: true));
    } catch (err) {
      emit(state.copyWith(
          status: TravelerSubscribeStatus.error, error: err.toString()));
    }
  }

  Future<void> _onUnsubscribe(
      UnsubscribePressed e, Emitter<TravelerSubscribeState> emit) async {
    try {
      await _repository.unsubscribe(travelerId);
      emit(state.copyWith(
          status: TravelerSubscribeStatus.ready,
          subscribed: false,
          pushEnabled: false));
    } catch (err) {
      emit(state.copyWith(
          status: TravelerSubscribeStatus.error, error: err.toString()));
    }
  }

  Future<void> _onTogglePush(
      TogglePushPressed e, Emitter<TravelerSubscribeState> emit) async {
    try {
      final s = await _repository.setPush(travelerId, e.enabled);
      emit(state.copyWith(
          status: TravelerSubscribeStatus.ready, pushEnabled: s.pushEnabled));
    } catch (err) {
      emit(state.copyWith(
          status: TravelerSubscribeStatus.error, error: err.toString()));
    }
  }
}
