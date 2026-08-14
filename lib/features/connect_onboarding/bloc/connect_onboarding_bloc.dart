import 'package:dony/core/error/app_exception.dart';
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
    on<ConnectOnboardingLaunchFailed>(_onLaunchFailed);
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
      } else if (status.isDisabled) {
        emit(const ConnectOnboardingDisabled());
      } else if (status.isRejected) {
        emit(ConnectOnboardingRejected(reason: status.reason));
      } else if (status.needsOnboarding) {
        emit(const ConnectOnboardingNeedsOnboarding());
      } else {
        emit(const ConnectOnboardingPending());
      }
    } catch (e) {
      emit(ConnectOnboardingError(unwrapDioError(e)));
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
      emit(ConnectOnboardingError(unwrapDioError(e)));
    }
  }

  Future<void> _onPollingRequested(
    ConnectOnboardingPollingRequested event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    // Passer par Loading n'est pas cosmétique. Les états sont des `const` sans
    // égalité de valeur : Dart les canonicalise, donc réémettre
    // ConnectOnboardingPending alors qu'on y est déjà est ignoré par Bloc. Sans
    // cette transition intermédiaire, taper « J'ai complété le formulaire »
    // sans avoir fini ne produisait strictement rien à l'écran, ni spinner ni
    // message, et l'utilisateur retapait dans le vide.
    emit(const ConnectOnboardingLoading());
    try {
      final status = await _repository.getAccountStatus();
      if (status.isComplete) {
        emit(const ConnectOnboardingComplete());
      } else if (status.isDisabled) {
        emit(const ConnectOnboardingDisabled());
      } else if (status.isRejected) {
        emit(ConnectOnboardingRejected(reason: status.reason));
      } else {
        emit(const ConnectOnboardingPending());
      }
    } catch (e) {
      emit(ConnectOnboardingError(unwrapDioError(e)));
    }
  }

  Future<void> _onLaunchFailed(
    ConnectOnboardingLaunchFailed event,
    Emitter<ConnectOnboardingState> emit,
  ) async {
    emit(
      ConnectOnboardingError(
        NetworkException(event.message, code: 'launch-failed'),
      ),
    );
  }
}
