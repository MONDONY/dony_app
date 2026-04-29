import 'package:flutter/material.dart';

enum DonyLogoVariant {
  onLight, // fond clair : logo-blue-orange (PNG net)
  onDark,  // fond sombre/coloré : logo-white-orange (PNG net)
}

class DonyLogo extends StatelessWidget {
  const DonyLogo({
    super.key,
    this.variant = DonyLogoVariant.onLight,
    this.fontSize = 32,
  });

  final DonyLogoVariant variant;
  final double fontSize;

  // PNG avec résolutions 1x/2x/3x — Caveat rendu côté serveur, toujours net
  static const _assetLight = 'assets/logos/logo-blue-orange.png';
  static const _assetDark  = 'assets/logos/logo-white-orange.png';

  @override
  Widget build(BuildContext context) {
    final asset = variant == DonyLogoVariant.onDark ? _assetDark : _assetLight;

    // height = fontSize dp ; width calculé par l'aspect ratio 2:1
    return Image.asset(
      asset,
      height: fontSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}