import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'blocked_users_event.dart';
part 'blocked_users_state.dart';

class BlockedUsersBloc extends Bloc<BlockedUsersEvent, BlockedUsersState> {
  final BlockedUsersRepository _repo;
  final AnalyticsService _analytics;
  final BlockEventsService _blockEvents;

  BlockedUsersBloc(this._repo, this._analytics, this._blockEvents)
    : super(const BlockedUsersInitial()) {
    on<BlockedUsersLoadRequested>(_onLoad);
    on<BlockedUserUnblockRequested>(_onUnblock);
    on<BlockedUserBlockRequested>(_onBlock);
  }

  Future<void> _onLoad(
    BlockedUsersLoadRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(const BlockedUsersLoading());
    try {
      final users = await _repo.fetchBlockedUsers();
      emit(BlockedUsersLoaded(users));
    } catch (_) {
      emit(
        const BlockedUsersError(
          'Impossible de charger les utilisateurs bloqués',
        ),
      );
    }
  }

  Future<void> _onUnblock(
    BlockedUserUnblockRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    final current = state is BlockedUsersLoaded
        ? (state as BlockedUsersLoaded).users
        : <BlockedUserModel>[];
    emit(BlockedUsersUnblocking(userId: event.userId, currentUsers: current));
    try {
      await _repo.unblockUser(event.userId);
      unawaited(_analytics.logEvent(AnalyticsEvents.userUnblocked));
      _blockEvents.notifyUnblocked(event.userId);
      final updated = await _repo.fetchBlockedUsers();
      emit(BlockedUsersLoaded(updated));
    } catch (_) {
      emit(BlockedUsersLoaded(current));
    }
  }

  Future<void> _onBlock(
    BlockedUserBlockRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(BlockedUserBlocking(event.userId));
    try {
      await _repo.blockUser(event.userId);
      unawaited(_analytics.logEvent(AnalyticsEvents.userBlocked));
      // Diffusé avant l'état de succès : les écrans abonnés rechargent pendant
      // que le dialog se ferme, plutôt qu'après le retour de l'utilisateur.
      _blockEvents.notifyBlocked(event.userId);
      emit(BlockedUserBlockSuccess(event.userId));
    } catch (_) {
      emit(
        const BlockedUserBlockFailure(
          'Une erreur est survenue. Réessaie plus tard.',
        ),
      );
    }
  }
}
