import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';

/// Le transporteur est payé au dépôt du colis (« Versé au transporteur au
/// dépôt du colis ») plutôt qu'à la livraison : trajet BOAT quand le bateau est
/// allumé côté serveur. Règle d'avant l'acceptation, quand aucun colis ne dit
/// encore son `payoutTrigger`. Jamais pour l'avion ni la route.
bool paidAtDeposit(TransportMode? tripMode) =>
    tripMode == TransportMode.boat && transportModes.boat;
