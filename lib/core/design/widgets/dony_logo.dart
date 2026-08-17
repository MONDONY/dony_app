import 'package:flutter/material.dart';

enum DonyLogoVariant {
  onLight, // fond clair : mot-logo Yadony (bleu nuit + orange)
  onDark, // fond sombre/coloré : idem, faute de déclinaison claire
}

class DonyLogo extends StatelessWidget {
  const DonyLogo({
    super.key,
    this.variant = DonyLogoVariant.onLight,
    this.fontSize = 32,
  });

  final DonyLogoVariant variant;
  final double fontSize;

  /// Mot-logo Yadony — même image que le splash natif, servie en haute
  /// résolution (1081×295) donc nette à toutes les tailles d'affichage.
  ///
  /// Public pour permettre un `precacheImage` : les surfaces qui rastérisent
  /// leur rendu (l'affiche partageable) doivent attendre le décodage avant de
  /// capturer, sinon le logo manque à l'image exportée. Recopier le chemin
  /// ailleurs le ferait diverger le jour d'un renommage.
  ///
  /// Les anciens logo-blue-orange / logo-white-orange portaient le mot « dony »
  /// et ne sont plus utilisés. Tant qu'aucune déclinaison sur fond sombre
  /// n'existe, [DonyLogoVariant.onDark] réutilise le même fichier.
  static const String asset = 'assets/logos/logo-yadony.png';

  @override
  Widget build(BuildContext context) {
    // Une seule image pour les deux variantes tant que la déclinaison claire
    // n'existe pas ; `variant` reste dans l'API pour ne pas casser les appelants
    // le jour où elle arrivera.
    const asset = DonyLogo.asset;

    // height = fontSize dp ; width calculé par l'aspect ratio (~3,7:1)
    return Image.asset(
      asset,
      height: fontSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
