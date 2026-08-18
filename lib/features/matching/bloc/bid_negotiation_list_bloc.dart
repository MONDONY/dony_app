import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:equatable/equatable.dart';

/// Liste des négociations de prix de trajet du viewer.
///
/// Jumeau de `NegotiationListBloc` (côté demandes d'envoi) : même contrat
/// d'events et de state, pour que « Discussions de prix » consomme les deux
/// sources de la même façon.
sealed class BidNegotiationListEvent extends Equatable {
  const BidNegotiationListEvent();

  @override
  List<Object?> get props => [];
}

class BidNegotiationListFetchRequested extends BidNegotiationListEvent {
  const BidNegotiationListFetchRequested();
}

class BidNegotiationListRefreshRequested extends BidNegotiationListEvent {
  const BidNegotiationListRefreshRequested();
}

enum BidNegotiationListStatus { initial, loading, loaded, error }

class BidNegotiationListState extends Equatable {
  const BidNegotiationListState({
    this.status = BidNegotiationListStatus.initial,
    this.summaries = const [],
    this.errorMessage,
  });

  final BidNegotiationListStatus status;
  final List<BidNegotiationSummary> summaries;
  final String? errorMessage;

  BidNegotiationListState copyWith({
    BidNegotiationListStatus? status,
    List<BidNegotiationSummary>? summaries,
    String? errorMessage,
  }) => BidNegotiationListState(
    status: status ?? this.status,
    summaries: summaries ?? this.summaries,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [status, summaries, errorMessage];
}

class BidNegotiationListBloc
    extends Bloc<BidNegotiationListEvent, BidNegotiationListState> {
  BidNegotiationListBloc(this._repository)
    : super(const BidNegotiationListState()) {
    on<BidNegotiationListFetchRequested>(_onFetch);
    on<BidNegotiationListRefreshRequested>(_onRefresh);
  }

  final BidNegotiationRepository _repository;

  Future<void> _onFetch(
    BidNegotiationListFetchRequested event,
    Emitter<BidNegotiationListState> emit,
  ) async {
    emit(state.copyWith(status: BidNegotiationListStatus.loading));
    await _load(emit);
  }

  /// Refresh silencieux : garde les données existantes visibles pendant l'appel.
  Future<void> _onRefresh(
    BidNegotiationListRefreshRequested event,
    Emitter<BidNegotiationListState> emit,
  ) => _load(emit);

  Future<void> _load(Emitter<BidNegotiationListState> emit) async {
    try {
      final summaries = await _repository.myNegotiations();
      emit(
        state.copyWith(
          status: BidNegotiationListStatus.loaded,
          summaries: summaries,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BidNegotiationListStatus.error,
          errorMessage: unwrapDioError(e).message,
        ),
      );
    }
  }
}
