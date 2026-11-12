import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter/material.dart';

/// Icône du mode de transport posée entre deux villes (ligne de corridor).
///
/// L'icône avion pointe vers le haut : seul l'avion reçoit un quart de tour
/// pour suivre le sens du trajet ; route, bateau et icône neutre sont déjà de
/// profil. Un [mode] `null` (demande « peu importe ») prend l'icône neutre,
/// jamais l'avion : les appelants d'un trajet ancien passent
/// `transportModeOrPlane(...)`.
class TransportModeIcon extends StatelessWidget {
  const TransportModeIcon({
    super.key,
    required this.mode,
    required this.size,
    required this.color,
  });

  final TransportMode? mode;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final current = mode;
    final icon = DonyIcon(
      current?.iconAsset ?? kNeutralTripIconAsset,
      size: size,
      color: color,
    );
    return current == TransportMode.plane
        ? RotatedBox(quarterTurns: 1, child: icon)
        : icon;
  }
}
