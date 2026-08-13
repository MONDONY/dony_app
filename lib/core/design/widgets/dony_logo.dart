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

  // Mot-logo Yadony — même image que le splash native, servie en haute
  // résolution (1081×295) donc nette à toutes les tailles d'affichage.
  // Les anciens logo-blue-orange / logo-white-orange portaient le mot « dony »
  // et ne sont plus utilisés. Tant qu'aucune déclinaison sur fond sombre
  // n'existe, onDark réutilise le même fichier.
  static const _assetLight = 'assets/logos/logo-yadony.png';
  static const _assetDark = 'assets/logos/logo-yadony.png';

  @override
  Widget build(BuildContext context) {
    final asset = variant == DonyLogoVariant.onDark ? _assetDark : _assetLight;

    // height = fontSize dp ; width calculé par l'aspect ratio (~3,7:1)
    return Image.asset(
      asset,
      height: fontSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
