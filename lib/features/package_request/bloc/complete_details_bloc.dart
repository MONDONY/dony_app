import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/package_request_repository.dart';

/// Manages the "Complete delivery details" form submission for an accepted
/// package request (recipient name, phone, optional city).
///
/// Replaces the previous setState/getIt-direct anti-pattern in
/// `CompleteDetailsScreen`. The screen keeps its TextEditingControllers for
/// local form state, but the network call + loading/error/success transitions
/// flow through this BLoC, allowing BlocListener-based snackbar + navigation
/// and BlocBuilder-based button loading state.
sealed class CompleteDetailsEvent extends Equatable {
  const CompleteDetailsEvent();
  @override
  List<Object?> get props => [];
}

class CompleteDetailsSubmitted extends CompleteDetailsEvent {
  const CompleteDetailsSubmitted({
    required this.requestId,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientCity,
  });

  final String requestId;
  final String recipientName;
  final String recipientPhone;
  final String? recipientCity;

  @override
  List<Object?> get props => [
        requestId,
        recipientName,
        recipientPhone,
        recipientCity,
      ];
}

enum CompleteDetailsStatus { initial, loading, success, error }

class CompleteDetailsState extends Equatable {
  const CompleteDetailsState({
    this.status = CompleteDetailsStatus.initial,
    this.errorMessage,
  });

  final CompleteDetailsStatus status;
  final String? errorMessage;

  bool get isLoading => status == CompleteDetailsStatus.loading;
  bool get isSuccess => status == CompleteDetailsStatus.success;

  CompleteDetailsState copyWith({
    CompleteDetailsStatus? status,
    String? errorMessage,
  }) =>
      CompleteDetailsState(
        status: status ?? this.status,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, errorMessage];
}

class CompleteDetailsBloc
    extends Bloc<CompleteDetailsEvent, CompleteDetailsState> {
  CompleteDetailsBloc(this._repository) : super(const CompleteDetailsState()) {
    on<CompleteDetailsSubmitted>(_onSubmit);
  }

  final PackageRequestRepository _repository;

  Future<void> _onSubmit(
    CompleteDetailsSubmitted event,
    Emitter<CompleteDetailsState> emit,
  ) async {
    emit(state.copyWith(status: CompleteDetailsStatus.loading));
    try {
      await _repository.completeDetails(
        event.requestId,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        recipientCity: event.recipientCity,
      );
      emit(state.copyWith(status: CompleteDetailsStatus.success));
    } catch (err) {
      emit(state.copyWith(
        status: CompleteDetailsStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
