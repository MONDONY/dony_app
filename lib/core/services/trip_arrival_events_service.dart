import 'dart:async';

/// Diffuse les trajets que le voyageur vient de marquer arrivés.
///
/// Le marquage d'arrivée passe les colis récupérés en `ARRIVED` côté serveur,
/// mais il se déclenche depuis plusieurs écrans (fiche trajet, détail d'un
/// colis) dont chacun a son propre BLoC (`registerFactory`). Sans signal, le
/// hub Scan & Suivi et le détail d'un colis gardaient l'ancien statut et
/// proposaient encore le scan Transit, que le serveur refuse alors en 422
/// (Sentry FLUTTER-D6).
///
/// Volontairement sans état, comme `BlockEventsService` : il ne transporte
/// que l'identifiant du trajet, les écrans abonnés relisent le serveur.
class TripArrivalEventsService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Identifiants des trajets marqués arrivés.
  Stream<String> get arrivals => _controller.stream;

  void notifyArrived(String announcementId) => _controller.add(announcementId);

  Future<void> dispose() => _controller.close();
}
