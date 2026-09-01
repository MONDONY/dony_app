import 'dart:async';

/// Un blocage ou un déblocage vient d'aboutir côté serveur.
class BlockChange {
  const BlockChange({required this.userId, required this.blocked});

  final String userId;

  /// `true` pour un blocage, `false` pour un déblocage.
  final bool blocked;
}

/// Diffuse les blocages et déblocages à travers l'application.
///
/// Un blocage change ce que le serveur renvoie à peu près partout : recherche,
/// conversations, profils. Or chaque route construit son propre BLoC
/// (`registerFactory`), donc l'écran qui déclenche le blocage n'a aucun moyen de
/// prévenir les autres. Ce singleton est ce moyen : les écrans concernés
/// s'abonnent et rechargent leurs données, plutôt que d'afficher un contenu que
/// le serveur ne renverrait plus.
///
/// Volontairement sans état : il ne mémorise pas qui est bloqué, la liste reste
/// au serveur. Il ne transporte qu'un signal.
class BlockEventsService {
  final StreamController<BlockChange> _controller =
      StreamController<BlockChange>.broadcast();

  Stream<BlockChange> get changes => _controller.stream;

  void notifyBlocked(String userId) =>
      _controller.add(BlockChange(userId: userId, blocked: true));

  void notifyUnblocked(String userId) =>
      _controller.add(BlockChange(userId: userId, blocked: false));

  Future<void> dispose() => _controller.close();
}
