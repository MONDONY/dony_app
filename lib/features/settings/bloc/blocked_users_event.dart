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

/// Blocage demandé depuis un point d'entrée hors de l'écran Confidentialité
/// (fiche profil, conversation). L'appelant fournit sa propre instance du BLoC.
class BlockedUserBlockRequested extends BlockedUsersEvent {
  final String userId;
  const BlockedUserBlockRequested(this.userId);
}
