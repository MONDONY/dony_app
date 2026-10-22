import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/presentation/widgets/search_period.dart';
import 'package:dony/l10n/l10n.dart';
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

  static String? _label(AppLocalizations l, String field) => switch (field) {
    'arrivalCity' => l.homeRecapArrival,
    'departureCity' => l.homeRecapDeparture,
    'departureDateFrom' => l.homeRecapWhen,
    'minAvailableKg' => l.homeRecapMinWeight,
    'maxPricePerKg' => l.homeMaxPriceTitle,
    _ => null,
  };

  /// Valeur affichée d'un champ. La date arrive en ISO (`2027-03-01`) : elle
  /// s'écrit comme dans le champ « PÉRIODE », avec la borne haute
  /// `departureDateTo` quand le parseur rend une période (« en mars »). Une
  /// valeur illisible reste telle quelle.
  String _value(AppLocalizations l, RecognizedField f) {
    if (f.field != 'departureDateFrom') return f.value;
    final from = DateTime.tryParse(f.value);
    if (from == null) return f.value;
    final to = fields
        .where((e) => e.field == 'departureDateTo')
        .map((e) => DateTime.tryParse(e.value))
        .firstOrNull;
    return formatSearchPeriod(from, to, l.localeName);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final l = context.l10n;
    final known = [
      for (final f in fields)
        if (_label(l, f.field) case final label?)
          (label: label, value: _value(l, f)),
    ];
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
            l.homeRecapTitle,
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
                l.homeRecapFieldLine(field.label, field.value),
                style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}
