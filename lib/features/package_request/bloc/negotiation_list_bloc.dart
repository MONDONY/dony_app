import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
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

/// Filtre « Archivées » : charge les fils rangés par l'appelant.
class NegotiationListArchivedFetchRequested extends NegotiationListEvent {
  const NegotiationListArchivedFetchRequested();
}

/// Archiver / désarchiver / supprimer un fil terminé, pour soi seulement.
class NegotiationArchiveActionRequested extends NegotiationListEvent {
  const NegotiationArchiveActionRequested(
    this.threadId,
    this.action, {
    this.fromDetail = false,
  });

  final String threadId;
  final NegoArchiveAction action;
  final bool fromDetail;

  @override
  List<Object?> get props => [threadId, action, fromDetail];
}

enum NegotiationListStatus { initial, loading, loaded, error }

class NegotiationListState extends Equatable {
  NegotiationListState({
    this.status = NegotiationListStatus.initial,
    this.threads = const [],
    this.errorMessage,
    DateTime? fetchedAt,
    this.archivedStatus = NegotiationListStatus.initial,
    this.archivedThreads = const [],
    this.lastAction,
  }) : fetchedAt = fetchedAt ?? DateTime(2000);

  final NegotiationListStatus status;

  /// Fils courants (non archivés). Seule source des compteurs et pastilles :
  /// un fil archivé est terminé, il n'y a jamais compté.
  final List<NegotiationThread> threads;
  final Object? errorMessage;

  /// Filtre « Archivées », chargé à la demande.
  final NegotiationListStatus archivedStatus;
  final List<NegotiationThread> archivedThreads;

  /// Dernière action d'archivage / suppression, pour le `listener` de l'écran.
  final NegoArchiveResult? lastAction;

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
    Object? errorMessage,
    DateTime? fetchedAt,
    NegotiationListStatus? archivedStatus,
    List<NegotiationThread>? archivedThreads,
    NegoArchiveResult? lastAction,
  }) => NegotiationListState(
    status: status ?? this.status,
    threads: threads ?? this.threads,
    errorMessage: errorMessage ?? this.errorMessage,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    archivedStatus: archivedStatus ?? this.archivedStatus,
    archivedThreads: archivedThreads ?? this.archivedThreads,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [
    status,
    threads,
    errorMessage,
    fetchedAt,
    archivedStatus,
    archivedThreads,
    lastAction,
  ];
}

class NegotiationListBloc
    extends Bloc<NegotiationListEvent, NegotiationListState> {
  NegotiationListBloc(this._repository) : super(NegotiationListState()) {
    on<NegotiationListFetchRequested>(_onFetch);
    on<NegotiationListRefreshRequested>(_onRefresh);
    on<NegotiationListArchivedFetchRequested>(_onArchivedFetch);
    on<NegotiationArchiveActionRequested>(_onArchiveAction);
  }

  final NegotiationRepository _repository;

  /// Les actions partent l'une après l'autre : « Annuler » juste après
  /// « Archiver » ne doit pas atteindre le serveur avant l'archivage.
  Future<void> _actionQueue = Future<void>.value();
  int _actionSeq = 0;

  Future<void> _onFetch(
    NegotiationListFetchRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    emit(state.copyWith(status: NegotiationListStatus.loading));
    try {
      final threads = _current(await _repository.findMine());
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
          errorMessage: unwrapDioError(err),
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
      final threads = _current(await _repository.findMine());
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
          errorMessage: unwrapDioError(err),
        ),
      );
    }
  }

  /// Un backend ancien ignore `archived` : on n'affiche jamais un fil archivé
  /// dans la liste courante, ni un fil courant sous « Archivées ».
  static List<NegotiationThread> _current(List<NegotiationThread> all) =>
      all.where((t) => !t.archived).toList();

  Future<void> _onArchivedFetch(
    NegotiationListArchivedFetchRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    emit(state.copyWith(archivedStatus: NegotiationListStatus.loading));
    await _loadArchived(emit);
  }

  Future<void> _loadArchived(Emitter<NegotiationListState> emit) async {
    try {
      final all = await _repository.findMine(archived: true);
      emit(
        state.copyWith(
          archivedStatus: NegotiationListStatus.loaded,
          archivedThreads: all.where((t) => t.archived).toList(),
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          archivedStatus: NegotiationListStatus.error,
          errorMessage: unwrapDioError(err),
        ),
      );
    }
  }

  Future<void> _onArchiveAction(
    NegotiationArchiveActionRequested event,
    Emitter<NegotiationListState> emit,
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
    NegotiationArchiveActionRequested event,
    Emitter<NegotiationListState> emit,
  ) async {
    final id = event.threadId;
    final before = state;
    // Optimiste : la tuile quitte aussitôt la liste où elle est affichée.
    emit(
      state.copyWith(
        threads: before.threads.where((t) => t.id != id).toList(),
        archivedThreads: before.archivedThreads
            .where((t) => t.id != id)
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
    } catch (err) {
      outcome = classifyNegoArchiveError(err);
      error = unwrapDioError(err);
    }
    final rollback =
        outcome == NegoArchiveOutcome.unsupported ||
        outcome == NegoArchiveOutcome.failed;
    emit(
      state.copyWith(
        threads: rollback ? before.threads : null,
        archivedThreads: rollback ? before.archivedThreads : null,
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
    // Rechargement silencieux : la vérité reste au serveur (fil rouvert,
    // retiré, ou passé d'une liste à l'autre).
    add(const NegotiationListRefreshRequested());
    if (state.archivedStatus != NegotiationListStatus.initial) {
      await _loadArchived(emit);
    }
  }
}
