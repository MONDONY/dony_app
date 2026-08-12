import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/models/package_request.dart';
import '../data/package_request_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

sealed class PackageRequestEvent extends Equatable {
  const PackageRequestEvent();
  @override
  List<Object?> get props => [];
}

class FetchMyRequests extends PackageRequestEvent {
  const FetchMyRequests();
}

class RefreshMyRequests extends PackageRequestEvent {
  const RefreshMyRequests();
}

class CancelRequest extends PackageRequestEvent {
  const CancelRequest(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// ─── State ────────────────────────────────────────────────────────────────────

enum PackageRequestListStatus { initial, loading, loaded, cancelling, error }

class PackageRequestState extends Equatable {
  PackageRequestState({
    this.status = PackageRequestListStatus.initial,
    this.requests = const [],
    this.errorMessage,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime(2000);

  final PackageRequestListStatus status;
  final List<PackageRequest> requests;
  final String? errorMessage;

  /// Horodatage du dernier chargement réussi.
  final DateTime fetchedAt;

  PackageRequestState copyWith({
    PackageRequestListStatus? status,
    List<PackageRequest>? requests,
    String? errorMessage,
    DateTime? fetchedAt,
  }) => PackageRequestState(
    status: status ?? this.status,
    requests: requests ?? this.requests,
    errorMessage: errorMessage ?? this.errorMessage,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );

  @override
  List<Object?> get props => [status, requests, errorMessage, fetchedAt];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class PackageRequestBloc
    extends Bloc<PackageRequestEvent, PackageRequestState> {
  PackageRequestBloc(this._repository) : super(PackageRequestState()) {
    on<FetchMyRequests>(_onFetch);
    on<RefreshMyRequests>(_onRefresh);
    on<CancelRequest>(_onCancel);
  }

  final PackageRequestRepository _repository;

  Future<void> _onFetch(
    FetchMyRequests e,
    Emitter<PackageRequestState> emit,
  ) async {
    if (state.requests.isEmpty) {
      emit(state.copyWith(status: PackageRequestListStatus.loading));
    }
    try {
      final page = await _repository.findMine();
      emit(
        state.copyWith(
          status: PackageRequestListStatus.loaded,
          requests: page.content,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: PackageRequestListStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }

  Future<void> _onRefresh(
    RefreshMyRequests e,
    Emitter<PackageRequestState> emit,
  ) async {
    // Refresh without showing full loading state; keep existing data visible
    try {
      final page = await _repository.findMine();
      emit(
        state.copyWith(
          status: PackageRequestListStatus.loaded,
          requests: page.content,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: PackageRequestListStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }

  Future<void> _onCancel(
    CancelRequest e,
    Emitter<PackageRequestState> emit,
  ) async {
    emit(state.copyWith(status: PackageRequestListStatus.cancelling));
    try {
      await _repository.cancel(e.id);
      // Refetch to get fresh list after cancellation
      final page = await _repository.findMine();
      emit(
        state.copyWith(
          status: PackageRequestListStatus.loaded,
          requests: page.content,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: PackageRequestListStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }
}
