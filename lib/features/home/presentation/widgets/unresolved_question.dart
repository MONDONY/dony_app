import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/search_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pose la question que le parseur a refusé de trancher.
///
/// C'est la pièce qui empêche le scénario le plus coûteux : une phrase à moitié
/// comprise qui produirait une liste vide sans explication, et ferait conclure à
/// l'utilisateur que l'application est cassée.
class UnresolvedQuestion extends StatelessWidget {
  const UnresolvedQuestion(this.item, {super.key});

  final UnresolvedItem item;

  String get _question => switch (item.kind) {
    UnresolvedKind.priceVague => '« ${item.phrase} », c\'est combien ?',
    UnresolvedKind.cityUnknown => 'Vers quelle ville ?',
    UnresolvedKind.cityAmbiguous => 'Quelle ville exactement ?',
    UnresolvedKind.dateVague => 'Quand voulez-vous partir ?',
  };

  /// Libellé affiché et valeur renvoyée au BLoC.
  List<({String label, String value})> get _options => switch (item.kind) {
    UnresolvedKind.priceVague => const [
      (label: 'Jusqu\'à 6 €/kg', value: '6'),
      (label: 'Jusqu\'à 9 €/kg', value: '9'),
      (label: 'Peu importe le prix', value: ''),
    ],
    UnresolvedKind.dateVague => const [
      (label: 'Cette semaine', value: 'thisWeek'),
      (label: 'Ce mois', value: 'thisMonth'),
      (label: 'Peu importe', value: ''),
    ],
    // Les villes viennent du serveur : pour une ambiguïté ce sont les
    // candidats, pour une ville inconnue les corridors les plus fournis.
    UnresolvedKind.cityUnknown || UnresolvedKind.cityAmbiguous =>
      item.options.map((o) => (label: o, value: o)).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionLabel(_question, tint: cs.tertiary),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (final option in _options)
                InkWell(
                  onTap: () => context.read<SearchComposerBloc>().add(
                    SearchComposerUnresolvedAnswered(
                      kind: item.kind,
                      value: option.value,
                    ),
                  ),
                  child: Container(
                    // 44 pt minimum sur une cible tactile.
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(option.label, style: tt.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
