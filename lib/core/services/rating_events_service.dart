import 'dart:async';

/// Diffuse les colis (bids) qui viennent d'être notés.
///
/// Une note part de plusieurs instances de `RatingBloc` (`registerFactory`) :
/// l'invite automatique posée à la racine (`main_shell.dart`), le détail d'un
/// colis, l'écran de scan… Le détail d'un colis n'écoutait que la sienne :
/// noté depuis l'invite racine, il gardait `senderHasRated` à faux et le
/// bouton « Noter le voyageur », dont un nouvel appui finissait en 409
/// « Déjà noté » (Sentry FLUTTER-HQ).
///
/// Volontairement sans état, comme `TripArrivalEventsService` : il ne
/// transporte que l'identifiant du colis, les écrans abonnés relisent le
/// serveur. Émis aussi sur un 409 `already-rated` : la note existe déjà côté
/// serveur, l'écran doit la refléter.
class RatingEventsService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Identifiants des colis notés.
  Stream<String> get rated => _controller.stream;

  void notifyRated(String bidId) {
    if (_controller.isClosed) return;
    _controller.add(bidId);
  }

  Future<void> dispose() => _controller.close();
}
