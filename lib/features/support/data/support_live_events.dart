import 'dart:async';

/// Canal des messages support reçus en direct (push au premier plan).
///
/// Singleton (via GetIt) : `NotificationService` y publie l'identifiant du
/// ticket, le `SupportBloc` de l'écran de détail l'écoute pour recharger le
/// fil ouvert sans afficher de bandeau.
class SupportLiveEvents {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get messages => _controller.stream;

  void messageReceived(String ticketId) {
    if (_controller.isClosed || ticketId.isEmpty) return;
    _controller.add(ticketId);
  }

  Future<void> dispose() => _controller.close();
}
