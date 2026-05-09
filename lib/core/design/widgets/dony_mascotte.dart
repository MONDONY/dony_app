import 'package:flutter/material.dart';

/// Mascotte officielle dony.
///
/// Centralise les chemins d'assets — préfère [DonyMascotte] à
/// `Image.asset('assets/mascottes/...')` pour garantir cohérence et typage.
enum DonyMascotteType {
  salue,
  tenantColis,
  colisLivre,
  pouceLeve,
  dansAvion,
  surAvion,
  aMoto,
  aVoiture,
  courir,
  noData,
  perdu;

  String get assetPath => switch (this) {
        salue       => 'assets/mascottes/salue.png',
        tenantColis => 'assets/mascottes/tenant_colis.png',
        colisLivre  => 'assets/mascottes/colis_livre.png',
        pouceLeve   => 'assets/mascottes/pouce_leve.png',
        dansAvion   => 'assets/mascottes/dans_avion.png',
        surAvion    => 'assets/mascottes/sur_avion.png',
        aMoto       => 'assets/mascottes/a_moto.png',
        aVoiture    => 'assets/mascottes/a_voiture.png',
        courir      => 'assets/mascottes/courir.png',
        noData      => 'assets/mascottes/no_data.png',
        perdu       => 'assets/mascottes/perdu.png',
      };

  String get semanticLabel => switch (this) {
        salue       => 'Mascotte qui salue',
        tenantColis => 'Mascotte tenant un colis',
        colisLivre  => 'Colis livré',
        pouceLeve   => 'Pouce levé',
        dansAvion   => 'Mascotte dans un avion',
        surAvion    => 'Mascotte sur un avion',
        aMoto       => 'Mascotte à moto',
        aVoiture    => 'Mascotte en voiture',
        courir      => 'Mascotte qui court',
        noData      => 'Aucun élément',
        perdu       => 'Quelque chose s\'est perdu',
      };
}

enum DonyMascotteSize {
  sm(64),
  md(96),
  lg(160),
  xl(240);

  const DonyMascotteSize(this.dimension);
  final double dimension;
}

class DonyMascotte extends StatelessWidget {
  const DonyMascotte({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;

  /// Override de la taille standard. Prend le pas sur [size] si non null.
  final double? customDimension;

  final BoxFit fit;

  /// Si non null, applique un ClipRRect.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dim = customDimension ?? size.dimension;

    final image = Image.asset(
      type.assetPath,
      width: dim,
      height: dim,
      fit: fit,
      semanticLabel: type.semanticLabel,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
