import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Message d'erreur sous un contrôle qui n'est pas un champ de formulaire.
///
/// Pendant symétrique de [buildRequiredLabel] : celui-ci marque le champ comme
/// obligatoire, celui-là dit ce qui manque. Les vrais champs texte passent par
/// `InputDecoration.errorText` et n'ont pas besoin de ce widget ; il existe
/// pour les sélecteurs, chips et cartes d'adresse, qui n'ont pas de décoration.
///
/// Rend `SizedBox.shrink()` quand [message] est nul, pour s'insérer
/// inconditionnellement dans un `Column`.
class DonyFieldError extends StatelessWidget {
  const DonyFieldError({
    super.key,
    required this.message,
    this.textKey,
    this.withIcon = false,
  });

  final String? message;

  /// Clé posée sur le [Text], pour les finders de test.
  final Key? textKey;

  /// Ajoute l'icône d'alerte. Réservé aux erreurs de bloc (fenêtre de remise),
  /// où le message ne suit pas immédiatement un champ identifiable.
  final bool withIcon;

  @override
  Widget build(BuildContext context) {
    final msg = message;
    if (msg == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error);
    final text = Text(msg, key: textKey, style: style);

    return Padding(
      // Aligné sur le gabarit d'InputDecoration.errorText, pour que les
      // messages d'un même formulaire se placent tous pareil, qu'ils viennent
      // d'un champ décoré ou d'un sélecteur.
      padding: const EdgeInsets.only(
        top: DonySpacing.xs,
        left: DonySpacing.base,
        right: DonySpacing.base,
        bottom: DonySpacing.xs,
      ),
      child: withIcon
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('circle-alert', size: 16, color: cs.error),
                const SizedBox(width: DonySpacing.xs),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}
