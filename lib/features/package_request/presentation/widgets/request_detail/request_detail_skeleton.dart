import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Squelette à la forme du billet et de deux cartes : rien ne saute à l'arrivée.
class RequestDetailSkeleton extends StatelessWidget {
  const RequestDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget block(double height, {double? width}) => Container(
      height: height, width: width,
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(DonyRadius.md)),
    );
    return Semantics(
      label: 'Chargement de ta demande',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block(250),
              const SizedBox(height: DonySpacing.lg),
              block(14, width: 140),
              const SizedBox(height: DonySpacing.sm),
              block(96),
              const SizedBox(height: DonySpacing.sm),
              block(96),
            ],
          ),
        ),
      ),
    );
  }
}
