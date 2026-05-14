import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/package_request_repository.dart';

/// Manages the "Complete delivery details" form submission for an accepted
/// package request (addresses, recipient, declared value, disclaimer).
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
    required this.pickupAddressLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryAddressLabel,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.recipientName,
    required this.recipientPhone,
    required this.declaredValueEur,
  });

  final String requestId;
  final String pickupAddressLabel;
  final double pickupLat;
  final double pickupLng;
  final String deliveryAddressLabel;
  final double deliveryLat;
  final double deliveryLng;
  final String recipientName;
  final String recipientPhone;
  final double declaredValueEur;

  @override
  List<Object?> get props => [
        requestId,
        pickupAddressLabel,
        pickupLat,
        pickupLng,
        deliveryAddressLabel,
        deliveryLat,
        deliveryLng,
        recipientName,
        recipientPhone,
        declaredValueEur,
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
        pickupAddressLabel: event.pickupAddressLabel,
        pickupLat: event.pickupLat,
        pickupLng: event.pickupLng,
        deliveryAddressLabel: event.deliveryAddressLabel,
        deliveryLat: event.deliveryLat,
        deliveryLng: event.deliveryLng,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        declaredValueEur: event.declaredValueEur,
        disclaimerSigned: true,
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
