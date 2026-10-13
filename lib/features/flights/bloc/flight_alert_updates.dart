import 'dart:async';

import 'package:dony/features/flights/data/models/flight_alert.dart';

/// Alertes prix modifiées hors de l'écran « Mes alertes » (singleton get_it).
///
/// Paramètres › Apparence met les alertes en pause quand l'utilisateur masque
/// les billets : chaque [FlightAlertsCubit] vivant (ligne des Outils du hub,
/// écran des alertes) applique ces versions à sa liste sans recharger.
class FlightAlertUpdates {
  final _controller = StreamController<FlightAlert>.broadcast();

  Stream<FlightAlert> get stream => _controller.stream;

  void publish(FlightAlert alert) {
    if (!_controller.isClosed) _controller.add(alert);
  }

  Future<void> dispose() => _controller.close();
}
