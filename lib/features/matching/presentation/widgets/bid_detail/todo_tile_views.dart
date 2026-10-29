import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_service.dart';

/// Mesure d'affichage d'une tuile « À traiter » de la fiche colis :
/// l'événement à émettre, ses propriétés, et le [status] qui sert à le
/// dédoublonner (statut du colis, ou de la demande quand elle en a un).
class TodoTileShown {
  const TodoTileShown(this.event, this.properties, {required this.status});

  final String event;
  final Map<String, Object> properties;
  final String status;
}

/// Journal d'affichage des tuiles « À traiter », tenu par le `State` du corps
/// de la fiche : la grille se reconstruit à chaque relevé du colis, la mesure
/// ne part qu'une fois par colis, tuile et statut pour cette instance d'écran.
class TodoTileViewLog {
  final _seen = <String>{};

  /// Émet [shown] si ce colis, cette tuile et ce statut n'ont pas encore été
  /// mesurés.
  void logOnce({
    required String bidId,
    required String tile,
    required TodoTileShown shown,
  }) {
    if (!_seen.add('$bidId|$tile|${shown.status}')) return;
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        shown.event,
        properties: shown.properties,
      ),
    );
  }
}
