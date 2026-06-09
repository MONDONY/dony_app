// ActiveRoleCubit a été supprimé dans la Phase 4 (migration modèle additif).
// Le fichier lib/features/auth/bloc/active_role_cubit.dart a été effacé via `git rm`.
//
// Le concept de "rôle actif" est désormais résolu par user.isTraveler (calculé depuis
// user.roles) dans AuthBloc, sans état local persisté.
//
// Les comportements anciennement testés ici (switchToTraveler, switchToSender, reset,
// persistance Hive) n'existent plus : les tests associés sont supprimés.
