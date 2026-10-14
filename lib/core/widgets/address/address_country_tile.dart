import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Champ « Pays » d'un formulaire d'adresse : drapeau, nom traduit et chevron.
/// Le tap ouvre le sélecteur de pays (passé par [onTap]).
///
/// Tolère un code hors catalogue (ex. `GN`) : drapeau calculé à partir du
/// code, nom traduit s'il est connu, sinon le code lui-même. Un code mal formé
/// affiche une icône globe au lieu du drapeau.
class AddressCountryTile extends StatelessWidget {
  const AddressCountryTile({
    super.key,
    required this.countryCode,
    required this.label,
    required this.onTap,
  });

  final String countryCode;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = countryName(context.l10n, countryCode);
    final flag = countryFlagEmoji(countryCode);

    return Semantics(
      button: true,
      label: '$label, $name',
      excludeSemantics: true,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              children: [
                if (flag != null)
                  Text(flag, style: const TextStyle(fontSize: 22))
                else
                  DonyIcon('globe', size: 22, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(name, style: tt.bodyMedium),
                    ],
                  ),
                ),
                DonyIcon('chevron-right', color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
