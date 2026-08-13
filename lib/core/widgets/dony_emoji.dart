import 'package:flutter/material.dart';

/// Emoji rendu comme un glyphe, dimensionné pour s'aligner avec un `Icon` ou du
/// texte. Utilisé pour les pictos avion/colis du style « filtre Home ».
///
/// Les emoji sont multicolores et non teintables : à réserver aux fonds clairs
/// ou neutres (cartes, listes, formulaires, sheets). Sur fond coloré/dégradé,
/// préférer [DonyIcon] (`plane-takeoff` / `plane-landing`) qui reste teintable
/// et lisible en mode sombre.
///
/// Raccourcis métier : [DonyEmoji.planeTakeoff], [DonyEmoji.planeLanding],
/// [DonyEmoji.parcel].
class DonyEmoji extends StatelessWidget {
  const DonyEmoji(this.emoji, {super.key, this.size = 16, this.semanticLabel});

  /// Décollage 🛫 — départ d'un trajet.
  const DonyEmoji.planeTakeoff({
    Key? key,
    double size = 16,
    String? semanticLabel,
  }) : this(
         '🛫',
         key: key,
         size: size,
         semanticLabel: semanticLabel ?? 'Décollage',
       );

  /// Atterrissage 🛬 — arrivée d'un trajet.
  const DonyEmoji.planeLanding({
    Key? key,
    double size = 16,
    String? semanticLabel,
  }) : this(
         '🛬',
         key: key,
         size: size,
         semanticLabel: semanticLabel ?? 'Atterrissage',
       );

  /// Colis 📦.
  const DonyEmoji.parcel({Key? key, double size = 16, String? semanticLabel})
    : this('📦', key: key, size: size, semanticLabel: semanticLabel ?? 'Colis');

  final String emoji;

  /// Taille visuelle (≈ équivalent du `size` d'un `Icon`).
  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      semanticsLabel: semanticLabel,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        height: 1.0,
        // Neutralise toute influence d'un DefaultTextStyle parent (couleur /
        // letterSpacing) sur le rendu de l'emoji.
        letterSpacing: 0,
      ),
    );
  }
}
