import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';

/// Icône (`DonyIcon`) du mode d'une demande d'envoi. « Peu importe » (`null`)
/// prend l'icône neutre : une demande sans mode imposé n'est pas un avion.
String requestModeIconAsset(TransportMode? mode) =>
    mode?.iconAsset ?? kNeutralTripIconAsset;

/// Libellé du mode d'une demande : « Peu importe » quand aucun mode n'est
/// imposé, sinon le nom du mode (le bus s'affiche « Route »).
String requestModeLabel(AppLocalizations l, TransportMode? mode) =>
    mode == null ? l.requestCreateTransportAny : mode.label(l);
