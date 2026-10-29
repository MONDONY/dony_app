import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Section titrée de la fiche colis (« À traiter », « Votre envoi », « Votre
/// transport ») : un titre puis ses contenus, séparés de [spacing]. Partagée
/// par les vues expéditeur et voyageur.
class BidDetailSection extends StatelessWidget {
  const BidDetailSection({
    super.key,
    required this.title,
    required this.children,
    this.spacing = DonySpacing.base,
  });

  final String title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: DonySpacing.md),
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: spacing),
        children[i],
      ],
    ],
  );
}
