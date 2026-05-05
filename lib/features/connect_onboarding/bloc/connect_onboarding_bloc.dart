import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'connect_onboarding_event.dart';
part 'connect_onboarding_state.dart';

class ConnectOnboardingBloc
    extends Bloc<ConnectOnboardingEvent, ConnectOnboardingState> {
  final IConnectOnboardingRepository _repository;

  ConnectOnboardingBloc(this._repository)
      : super(const ConnectOnboardingInitial()) {
    on<ConnectOnboardingStatusRequested>(_onStatusRequested);
    on<ConnectOnboardingLinkRequested>(_onLinkRequested);
    on<ConnectOnboardingPollingRequested>(_onPollingRequested);
  }

  Future<void> _onStatusRequested(
    ConnectOnboardingStatusRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(const ConnectOnboardingLoading());
    try {
      final status = await _repository.getAccountStatus();
      if (status.isComplete) {
        emit(const ConnectOnboardingComplete());
      } else if (status.needsOnboarding) {
        emit(const ConnectOnboardingNeedsOnboarding());
      } else {
        emit(const ConnectOnboardingPending());
      }
    } catch (e) {
      emit(ConnectOnboardingError(e.toString()));
    }
  }

  Future<void> _onLinkRequested(
    ConnectOnboardingLinkRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(const ConnectOnboardingLoading());
    try {
      final url = await _repository.createOnboardingLink();
      emit(ConnectOnboardingUrlReady(url));
    } catch (e) {
      emit(ConnectOnboardingError(e.toString()));
    }
  }

  Future<void> _onPollingRequested(
    ConnectOnboardingPollingRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    try {
      final status = await _repository.getAccountStatus();
      if (status.isComplete) {
        emit(const ConnectOnboardingComplete());
      } else {
        emit(const ConnectOnboardingPending());
      }
    } catch (e) {
      emit(ConnectOnboardingError(e.toString()));
    }
  }
}
