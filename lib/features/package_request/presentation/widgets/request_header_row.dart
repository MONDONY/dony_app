import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// En-tête d'une demande d'envoi : l'étiquette à gauche, les pastilles
/// (statut, « Urgent », « Prix ferme »…) collées au bord droit.
///
/// Un `Wrap` seul ne suffisait pas : il ne prend que la largeur de son contenu,
/// donc `spaceBetween` n'avait rien à répartir et la pastille restait contre
/// l'étiquette. La pleine largeur lui est donnée ici. Sans place pour les deux,
/// les pastilles passent sous l'étiquette, jamais de débordement.
///
/// [leading] doit se contenter de sa largeur naturelle (`Row` en
/// `mainAxisSize.min`, texte tronquable dans un `Flexible`). Pas de
/// `LayoutBuilder` ici : l'en-tête vit dans un `IntrinsicHeight`.
class RequestHeaderRow extends StatelessWidget {
  const RequestHeaderRow({
    required this.leading,
    required this.trailing,
    super.key,
  });

  final Widget leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: DonySpacing.xxs,
        children: [
          leading,
          if (trailing.isNotEmpty)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: DonySpacing.xs,
              runSpacing: DonySpacing.xxs,
              children: trailing,
            ),
        ],
      ),
    );
  }
}
