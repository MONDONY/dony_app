import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Instructions de retrait saisies par le voyageur à l'arrivée du trajet.
///
/// Affichées en encart permanent, hors du hero du détail d'envoi : le hero est
/// remplacé en priorité par une contestation ou une absence à la livraison, et
/// passe à « livré » une fois le colis remis. Les instructions y étaient donc
/// invisibles la plupart du temps, alors qu'elles servent à récupérer le colis.
///
/// [instructions] est un texte libre saisi par le voyageur (donnée serveur,
/// jamais un littéral à traduire). N'afficher ce widget que s'il est non vide :
/// voir [ArrivalInstructionsCard.hasText].
class ArrivalInstructionsCard extends StatelessWidget {
  const ArrivalInstructionsCard({super.key, required this.instructions});

  final String instructions;

  static bool hasText(String? instructions) =>
      (instructions ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return DonyStatusBanner(
      key: const Key('arrival-instructions-card'),
      type: DonyStatusBannerType.info,
      iconAsset: 'map-pin',
      title: context.l10n.tripOwnerArrivalEditingTitle,
      message: instructions.trim(),
    );
  }
}
