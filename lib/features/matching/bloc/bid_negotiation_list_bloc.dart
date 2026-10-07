import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
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

/// Filtre « Archivées » : charge les fils de trajet rangés par l'appelant.
class BidNegotiationListArchivedFetchRequested extends BidNegotiationListEvent {
  const BidNegotiationListArchivedFetchRequested();
}

/// Archiver / désarchiver / supprimer un fil de trajet terminé, pour soi
/// seulement.
class BidNegotiationArchiveActionRequested extends BidNegotiationListEvent {
  const BidNegotiationArchiveActionRequested(
    this.bidId,
    this.action, {
    this.fromDetail = false,
  });

  final String bidId;
  final NegoArchiveAction action;
  final bool fromDetail;

  @override
  List<Object?> get props => [bidId, action, fromDetail];
}

enum BidNegotiationListStatus { initial, loading, loaded, error }

class BidNegotiationListState extends Equatable {
  const BidNegotiationListState({
    this.status = BidNegotiationListStatus.initial,
    this.summaries = const [],
    this.errorMessage,
    this.archivedStatus = BidNegotiationListStatus.initial,
    this.archivedSummaries = const [],
    this.lastAction,
  });

  final BidNegotiationListStatus status;

  /// Fils courants (non archivés) : seule source des compteurs.
  final List<BidNegotiationSummary> summaries;
  final Object? errorMessage;

  /// Filtre « Archivées », chargé à la demande.
  final BidNegotiationListStatus archivedStatus;
  final List<BidNegotiationSummary> archivedSummaries;

  /// Dernière action d'archivage / suppression, pour le `listener` de l'écran.
  final NegoArchiveResult? lastAction;

  BidNegotiationListState copyWith({
    BidNegotiationListStatus? status,
    List<BidNegotiationSummary>? summaries,
    Object? errorMessage,
    BidNegotiationListStatus? archivedStatus,
    List<BidNegotiationSummary>? archivedSummaries,
    NegoArchiveResult? lastAction,
  }) => BidNegotiationListState(
    status: status ?? this.status,
    summaries: summaries ?? this.summaries,
    errorMessage: errorMessage ?? this.errorMessage,
    archivedStatus: archivedStatus ?? this.archivedStatus,
    archivedSummaries: archivedSummaries ?? this.archivedSummaries,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [
    status,
    summaries,
    errorMessage,
    archivedStatus,
    archivedSummaries,
    lastAction,
  ];
}

class BidNegotiationListBloc
    extends Bloc<BidNegotiationListEvent, BidNegotiationListState> {
  BidNegotiationListBloc(this._repository)
    : super(const BidNegotiationListState()) {
    on<BidNegotiationListFetchRequested>(_onFetch);
    on<BidNegotiationListRefreshRequested>(_onRefresh);
    on<BidNegotiationListArchivedFetchRequested>(_onArchivedFetch);
    on<BidNegotiationArchiveActionRequested>(_onArchiveAction);
  }

  final BidNegotiationRepository _repository;

  /// Les actions partent l'une après l'autre : « Annuler » juste après
  /// « Archiver » ne doit pas atteindre le serveur avant l'archivage.
  Future<void> _actionQueue = Future<void>.value();
  int _actionSeq = 0;

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
          // Un backend ancien ignore `archived` : jamais de fil archivé ici.
          summaries: summaries.where((s) => !s.archived).toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BidNegotiationListStatus.error,
          errorMessage: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onArchivedFetch(
    BidNegotiationListArchivedFetchRequested event,
    Emitter<BidNegotiationListState> emit,
  ) async {
    emit(state.copyWith(archivedStatus: BidNegotiationListStatus.loading));
    await _loadArchived(emit);
  }

  Future<void> _loadArchived(Emitter<BidNegotiationListState> emit) async {
    try {
      final all = await _repository.myNegotiations(archived: true);
      emit(
        state.copyWith(
          archivedStatus: BidNegotiationListStatus.loaded,
          // Un backend ancien renvoie la liste courante : rien n'y est archivé.
          archivedSummaries: all.where((s) => s.archived).toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          archivedStatus: BidNegotiationListStatus.error,
          errorMessage: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onArchiveAction(
    BidNegotiationArchiveActionRequested event,
    Emitter<BidNegotiationListState> emit,
  ) async {
    final previous = _actionQueue;
    final done = Completer<void>();
    _actionQueue = done.future;
    try {
      await previous;
      await _runAction(event, emit);
    } finally {
      done.complete();
    }
  }

  Future<void> _runAction(
    BidNegotiationArchiveActionRequested event,
    Emitter<BidNegotiationListState> emit,
  ) async {
    final id = event.bidId;
    final before = state;
    // Optimiste : la tuile quitte aussitôt la liste où elle est affichée.
    emit(
      state.copyWith(
        summaries: before.summaries.where((s) => s.bidId != id).toList(),
        archivedSummaries: before.archivedSummaries
            .where((s) => s.bidId != id)
            .toList(),
      ),
    );
    NegoArchiveOutcome outcome;
    Object? error;
    try {
      await switch (event.action) {
        NegoArchiveAction.archive => _repository.archive(id),
        NegoArchiveAction.unarchive => _repository.unarchive(id),
        NegoArchiveAction.delete => _repository.delete(id),
      };
      outcome = NegoArchiveOutcome.success;
    } catch (e) {
      outcome = classifyNegoArchiveError(e);
      error = unwrapDioError(e);
    }
    final rollback =
        outcome == NegoArchiveOutcome.unsupported ||
        outcome == NegoArchiveOutcome.failed;
    emit(
      state.copyWith(
        summaries: rollback ? before.summaries : null,
        archivedSummaries: rollback ? before.archivedSummaries : null,
        lastAction: NegoArchiveResult(
          id: id,
          action: event.action,
          outcome: outcome,
          seq: ++_actionSeq,
          fromDetail: event.fromDetail,
          error: error,
        ),
      ),
    );
    if (outcome == NegoArchiveOutcome.unsupported) {
      return;
    }
    // Rechargement silencieux : la vérité reste au serveur.
    add(const BidNegotiationListRefreshRequested());
    if (state.archivedStatus != BidNegotiationListStatus.initial) {
      await _loadArchived(emit);
    }
  }
}
