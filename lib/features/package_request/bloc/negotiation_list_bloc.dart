import 'package:bloc/bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:equatable/equatable.dart';

/// BLoC managing the viewer's list of negotiation threads.
///
/// Used by:
/// - `MyNegotiationsBody` (standalone `MyNegotiationsScreen`, route
///   `/negotiations`, accessible depuis le profil) to render the full list.
/// - `EnvoyerHubScreen` to drive the "Demandes" tab badge — nouvelles offres +
///   contre-propositions reçues depuis la dernière visite de l'onglet.
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

  /// Threads still open (any turn) — alimente la pastille de la carte
  /// « Discussions de prix » : elle reste tant que la négociation est ouverte.
  int get activeCount => threads.where((t) => t.status.isActive).length;

  /// Threads ouverts où c'est à l'utilisateur de jouer — alimente le point de
  /// l'onglet Activités : il ne s'allume que quand une action est attendue de
  /// lui (pas quand on attend la partie adverse).
  int get actionableCount =>
      threads.where((t) => t.status.isActive && t.isMyTurn).length;

  int unreadCountForRequests(Set<String> requestIds) => threads
      .where(
        (thread) =>
            requestIds.contains(thread.packageRequestId) && thread.hasUnread,
      )
      .length;

  NegotiationListState copyWith({
    NegotiationListStatus? status,
    List<NegotiationThread>? threads,
    String? errorMessage,
    DateTime? fetchedAt,
  }) => NegotiationListState(
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
      emit(
        state.copyWith(
          status: NegotiationListStatus.loaded,
          threads: threads,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: NegotiationListStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }

  /// Refresh silencieux : garde les données existantes visibles pendant l'appel.
  Future<void> _onRefresh(
    NegotiationListRefreshRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    try {
      final threads = await _repository.findMine();
      emit(
        state.copyWith(
          status: NegotiationListStatus.loaded,
          threads: threads,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: NegotiationListStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }
}
