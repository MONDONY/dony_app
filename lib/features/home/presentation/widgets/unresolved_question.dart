import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/search_section_label.dart';
import 'package:dony/l10n/l10n.dart';
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

  String _question(AppLocalizations l) => switch (item.kind) {
    UnresolvedKind.priceVague => l.homeUnresolvedPriceQuestion(item.phrase),
    UnresolvedKind.cityUnknown => l.homeUnresolvedCityUnknown,
    UnresolvedKind.cityAmbiguous => l.homeUnresolvedCityAmbiguous,
    UnresolvedKind.dateVague => l.homeUnresolvedDateQuestion,
  };

  /// Libellé affiché et valeur renvoyée au BLoC.
  ///
  /// Prix : montants scalés vers la devise ACTIVE (le backend interprète le
  /// filtre dans la devise du lecteur). « 6 €/kg » figé éliminait 100 % des
  /// annonces pour un lecteur XOF, tout prix CFA dépassant 6.
  List<({String label, String value})> _options(AppLocalizations l) =>
      switch (item.kind) {
        UnresolvedKind.priceVague => [
          for (final amount in quickPriceFilterOptionsActive())
            (
              label: l.homeUnresolvedUpTo(formatPriceActive(amount)),
              value: amount.toStringAsFixed(
                amount == amount.truncateToDouble() ? 0 : 2,
              ),
            ),
          (label: l.homeUnresolvedAnyPrice, value: ''),
        ],
        UnresolvedKind.dateVague => [
          (label: l.commonDateThisWeek, value: 'thisWeek'),
          (label: l.commonDateThisMonth, value: 'thisMonth'),
          (label: l.homeUnresolvedAnyTime, value: ''),
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
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionLabel(_question(l), tint: cs.tertiary),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (final option in _options(l))
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
