import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/negotiation_thread.dart';
import '../data/negotiation_repository.dart';

/// BLoC managing the viewer's list of negotiation threads.
///
/// Used by:
/// - `MyNegotiationsBody` to render the list under the "Négos" tab of
///   `EnvoyerHubScreen`.
/// - `_CountedTab` "Négos" in `EnvoyerHubScreen` to display the active thread
///   count badge (matching the maquette's "1 demande · 2 nouvelles négos").
///
/// Active threads = anything in OPEN / AWAITING_TRIP / AWAITING_PAYMENT (i.e.
/// still requiring attention). Terminal states (accepted, rejected, expired,
/// auto-rejected) are listed but don't count toward the badge.
sealed class NegotiationListEvent extends Equatable {
  const NegotiationListEvent();
  @override
  List<Object?> get props => [];
}

class NegotiationListFetchRequested extends NegotiationListEvent {
  const NegotiationListFetchRequested();
}

class NegotiationListRefreshRequested extends NegotiationListEvent {
  const NegotiationListRefreshRequested();
}

enum NegotiationListStatus { initial, loading, loaded, error }

class NegotiationListState extends Equatable {
  NegotiationListState({
    this.status = NegotiationListStatus.initial,
    this.threads = const [],
    this.errorMessage,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime(2000);

  final NegotiationListStatus status;
  final List<NegotiationThread> threads;
  final String? errorMessage;

  /// Horodatage du dernier chargement réussi.
  final DateTime fetchedAt;

  /// Threads still requiring attention (used for the tab badge counter).
  int get activeCount => threads.where((t) =>
      t.status == NegotiationThreadStatus.open ||
      t.status == NegotiationThreadStatus.awaitingTrip ||
      t.status == NegotiationThreadStatus.awaitingPayment).length;

  NegotiationListState copyWith({
    NegotiationListStatus? status,
    List<NegotiationThread>? threads,
    String? errorMessage,
    DateTime? fetchedAt,
  }) =>
      NegotiationListState(
        status: status ?? this.status,
        threads: threads ?? this.threads,
        errorMessage: errorMessage ?? this.errorMessage,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  @override
  List<Object?> get props => [status, threads, errorMessage, fetchedAt];
}

class NegotiationListBloc
    extends Bloc<NegotiationListEvent, NegotiationListState> {
  NegotiationListBloc(this._repository) : super(NegotiationListState()) {
    on<NegotiationListFetchRequested>(_onFetch);
    on<NegotiationListRefreshRequested>(_onRefresh);
  }

  final NegotiationRepository _repository;

  Future<void> _onFetch(
    NegotiationListFetchRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    emit(state.copyWith(status: NegotiationListStatus.loading));
    try {
      final threads = await _repository.findMine();
      emit(state.copyWith(
        status: NegotiationListStatus.loaded,
        threads: threads,
        fetchedAt: DateTime.now(),
      ));
    } catch (err) {
      emit(state.copyWith(
        status: NegotiationListStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  /// Refresh silencieux : garde les données existantes visibles pendant l'appel.
  Future<void> _onRefresh(
    NegotiationListRefreshRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    try {
      final threads = await _repository.findMine();
      emit(state.copyWith(
        status: NegotiationListStatus.loaded,
        threads: threads,
        fetchedAt: DateTime.now(),
      ));
    } catch (err) {
      emit(state.copyWith(
        status: NegotiationListStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
