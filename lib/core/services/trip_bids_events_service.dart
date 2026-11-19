import 'dart:async';

/// Diffuse les changements de colis ou de demandes d'un trajet : demande
/// acceptée, refusée, colis annulé.
///
/// Le voyageur répond aux demandes depuis plusieurs écrans (Demandes, fiche
/// du colis, fiche de la demande), chacun avec son propre BLoC
/// (`registerFactory`). L'écran du trajet, resté dessous dans la pile
/// GoRouter, ne voyait rien de ces réponses : compteurs de colis périmés et
/// entrée « Mettre en brouillon » du menu encore affichée alors qu'un colis
/// était dessus. Il s'abonne ici et relit le trajet et ses colis.
///
/// Volontairement sans état, comme `TripArrivalEventsService` : il ne
/// transporte que l'identifiant du trajet (`null` quand l'émetteur ne le
/// connaît pas : l'abonné relit alors par prudence).
class TripBidsEventsService {
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  /// Trajets dont les colis ou demandes viennent de changer.
  Stream<String?> get changes => _controller.stream;

  void notifyChanged([String? announcementId]) {
    if (!_controller.isClosed) _controller.add(announcementId);
  }

  Future<void> dispose() => _controller.close();
}
