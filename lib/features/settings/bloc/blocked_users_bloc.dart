import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'blocked_users_event.dart';
part 'blocked_users_state.dart';

class BlockedUsersBloc extends Bloc<BlockedUsersEvent, BlockedUsersState> {
  final BlockedUsersRepository _repo;

  BlockedUsersBloc(this._repo) : super(const BlockedUsersInitial()) {
    on<BlockedUsersLoadRequested>(_onLoad);
    on<BlockedUserUnblockRequested>(_onUnblock);
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
      final updated = await _repo.fetchBlockedUsers();
      emit(BlockedUsersLoaded(updated));
    } catch (_) {
      emit(BlockedUsersLoaded(current));
    }
  }
}
