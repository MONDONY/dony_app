import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/widgets.dart';

/// D'où s'ouvre le sheet d'une tuile « À traiter » (vues expéditeur et
/// voyageur) : propriété `source` de `bid_detail_tile_opened` (son `name`).
enum TodoSource {
  /// Tuile touchée dans la grille.
  tile,

  /// Lien d'une notification (`?action=amendment` côté expéditeur,
  /// `?action=supplement` côté voyageur) : le sheet s'ouvre de lui-même à
  /// l'affichage de la fiche.
  link,
}

/// Compte l'ouverture du sheet d'une tuile de la fiche colis
/// (`bid_detail_tile_opened`) : grilles « Votre envoi » / « Votre transport »
/// et tuiles « À traiter ». [tile] : nom de la tuile, [role] : `sender` ou
/// `traveler`, [source] : d'où part l'ouverture (`tile`, `link`, `menu`).
void logBidDetailTileOpened({
  required String tile,
  required String role,
  required String source,
}) => unawaited(
  getItSafe<AnalyticsService>()?.logEvent(
    AnalyticsEvents.bidDetailTileOpened,
    properties: {'tile': tile, 'role': role, 'source': source},
  ),
);

/// Mesure d'affichage d'une tuile « À traiter » de la fiche colis :
/// l'événement à émettre, la tuile et le [status] qui servent à le
/// dédoublonner (statut du colis, ou de la demande quand elle en a un), et
/// ses propriétés, construites seulement à l'émission.
class TodoTileShown {
  const TodoTileShown(
    this.event, {
    required this.tile,
    required this.status,
    required Map<String, Object> Function() properties,
  }) : _properties = properties;

  final String event;
  final String tile;
  final String status;
  final Map<String, Object> Function() _properties;

  /// Propriétés de l'événement.
  Map<String, Object> get properties => _properties();
}

/// Journal d'affichage des tuiles « À traiter », tenu par le `State` du corps
/// de la fiche : la grille se reconstruit à chaque relevé du colis, chaque
/// mesure ne part qu'une fois par colis, événement, tuile et statut pour
/// cette instance d'écran.
class TodoTileViewLog {
  final _seen = <String>{};

  static String _key(String bidId, TodoTileShown shown) =>
      '$bidId|${shown.event}|${shown.tile}|${shown.status}';

  /// Émet après l'image, dans l'ordre, les mesures de [shown] pas encore
  /// émises pour le colis [bidId]. Ne planifie rien quand toutes l'ont déjà
  /// été ; n'émet rien si [context] est démonté avant l'image.
  void logAll(
    BuildContext context,
    String bidId,
    Iterable<TodoTileShown> shown,
  ) {
    final fresh = [
      for (final s in shown)
        if (!_seen.contains(_key(bidId, s))) s,
    ];
    if (fresh.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      for (final s in fresh) {
        if (!_seen.add(_key(bidId, s))) continue;
        unawaited(
          getItSafe<AnalyticsService>()?.logEvent(
            s.event,
            properties: s.properties,
          ),
        );
      }
    });
  }
}
