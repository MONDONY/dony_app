part of 'blocked_users_bloc.dart';

sealed class BlockedUsersEvent {
  const BlockedUsersEvent();
}

class BlockedUsersLoadRequested extends BlockedUsersEvent {
  const BlockedUsersLoadRequested();
}

class BlockedUserUnblockRequested extends BlockedUsersEvent {
  final String userId;
  const BlockedUserUnblockRequested(this.userId);
}
