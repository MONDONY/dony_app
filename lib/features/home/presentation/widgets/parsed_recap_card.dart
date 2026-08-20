import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:flutter/material.dart';

/// Récapitulatif de ce que le parseur a compris dans la phrase, affiché
/// juste sous le champ « En une phrase ».
///
/// Un champ dont le nom serveur n'a pas de libellé humain connu n'est pas
/// affiché : mieux vaut un récapitulatif incomplet qu'une clé technique
/// brute (`minAvailableKg`) sous les yeux de l'utilisateur.
class ParsedRecapCard extends StatelessWidget {
  const ParsedRecapCard(this.fields, {super.key});

  final List<RecognizedField> fields;

  static const _labels = <String, String>{
    'arrivalCity': 'Arrivée',
    'departureCity': 'Départ',
    'departureDateFrom': 'Quand',
    'minAvailableKg': 'Poids minimum',
    'maxPricePerKg': 'Prix maximum',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final known = fields.where((f) => _labels.containsKey(f.field)).toList();
    if (known.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: DonySpacing.md),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RÉGLÉ DEPUIS VOTRE PHRASE',
            style: tt.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          for (final field in known)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_labels[field.field]} : ${field.value}',
                style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}
