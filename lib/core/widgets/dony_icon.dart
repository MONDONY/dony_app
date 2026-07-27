import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icône SVG monochrome de l'app (Lucide, Phosphor, Heroicons…).
///
/// Les fichiers sont posés dans `assets/icons/` et référencés par leur nom
/// sans extension : `DonyIcon('plane')` → `assets/icons/plane.svg`.
///
/// - SVG « line » (mono) → passer [color] pour le teinter (défaut : couleur
///   d'origine du SVG conservée si [color] est null).
/// - SVG déjà multicolore → laisser [color] à null pour garder ses couleurs.
class DonyIcon extends StatelessWidget {
  const DonyIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  /// Nom du fichier sans extension ni dossier. Ex: `'plane'`.
  final String name;

  /// Côté du carré (largeur = hauteur). Défaut 24.
  final double size;

  /// Teinte appliquée (recolore tout le tracé). Null = couleurs d'origine.
  final Color? color;

  /// Label d'accessibilité (obligatoire si l'icône porte du sens seule).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Center(widthFactor/heightFactor: 1) : protège la taille du SVG.
    // Sans ça, un slot qui impose une contrainte min plus grande (ex:
    // InputDecoration.prefixIcon force min 48×48, ou un Container surdimensionné)
    // étirerait le SvgPicture pour remplir la boîte — contrairement à un glyphe
    // Material qui reste à taille fixe. Le widthFactor shrink-wrap évite aussi
    // l'erreur « infinite width » en usage inline non borné.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
        semanticsLabel: semanticLabel,
        // Fond transparent pendant le décodage → pas de flash.
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}

/// Icône 3D / illustration couleur en bitmap (3dicons, Fluent Emoji, Icons8…).
///
/// Les fichiers (PNG, idéalement @2x/@3x) sont posés dans `assets/icons_3d/`.
/// `DonyIcon3d('plane')` → `assets/icons_3d/plane.png`.
///
/// Pas de teinte : ces icônes gardent toujours leurs couleurs d'origine.
class DonyIcon3d extends StatelessWidget {
  const DonyIcon3d(
    this.name, {
    super.key,
    this.size = 48,
    this.semanticLabel,
  });

  /// Nom du fichier sans extension ni dossier. Ex: `'plane'`.
  final String name;

  /// Côté du carré (largeur = hauteur). Défaut 48 (les 3D rendent mieux grand).
  final double size;

  /// Label d'accessibilité.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons_3d/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
    );
  }
}

/// Raccourci pratique : icône SVG teintée en couleur primaire Yadony.
///
/// Équivaut à `DonyIcon(name, color: DonyColors.primary)`.
class DonyIconPrimary extends StatelessWidget {
  const DonyIconPrimary(
    this.name, {
    super.key,
    this.size = 24,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DonyIcon(
      name,
      size: size,
      color: DonyColors.primary,
      semanticLabel: semanticLabel,
    );
  }
}
