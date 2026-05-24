part of 'blocked_users_bloc.dart';

sealed class BlockedUsersState extends Equatable {
  const BlockedUsersState();

  @override
  List<Object?> get props => [];
}

class BlockedUsersInitial extends BlockedUsersState {
  const BlockedUsersInitial();
}

class BlockedUsersLoading extends BlockedUsersState {
  const BlockedUsersLoading();
}

class BlockedUsersLoaded extends BlockedUsersState {
  final List<BlockedUserModel> users;
  const BlockedUsersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class BlockedUsersUnblocking extends BlockedUsersState {
  final String userId;
  final List<BlockedUserModel> currentUsers;
  const BlockedUsersUnblocking({
    required this.userId,
    required this.currentUsers,
  });

  @override
  List<Object?> get props => [userId, currentUsers];
}

class BlockedUsersError extends BlockedUsersState {
  final String message;
  const BlockedUsersError(this.message);

  @override
  List<Object?> get props => [message];
}
