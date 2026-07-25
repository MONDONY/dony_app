import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Libellé affiché pour un mode tri-état.
String a11yModeLabel(String mode) => switch (mode) {
      AccessibilityMode.on => 'Toujours activé',
      AccessibilityMode.off => 'Toujours désactivé',
      _ => 'Suivre le téléphone',
    };

/// Largeur maximale du bloc de fin (libellé de mode + chevron) de
/// [A11yTristateRow].
///
/// `DonyListTile` ne borne pas son slot `trailing` (un enfant non-flex d'un
/// `Row` reçoit toute la largeur disponible comme contrainte, quels que
/// soient les autres enfants) : sans borne, le libellé le plus long
/// ('Suivre le téléphone', 228 px de large sans contrainte à 100 %) réclame
/// sa largeur naturelle sur une seule ligne et fait déborder tout le `Row`
/// du parent à 200 % de taille de texte.
///
/// Aucune largeur ne permet à la fois une seule ligne à 100 % ET l'absence
/// de débordement à 200 % : à 200 %, la ligne complète (icône + libellé +
/// ce bloc) ne tient physiquement que dans ~260 px sur l'écran de test le
/// plus étroit couramment ciblé (360 pt logiques), ce qui borne ce bloc à
/// ~200 px maximum pour laisser de la place au libellé principal — largement
/// sous les ~252 px qu'exigerait 'Suivre le téléphone' sur une seule ligne.
/// Le retour à la ligne à 100 % est donc assumé explicitement plutôt que
/// combattu : 176 est choisie pour qu'il reste propre (exactement deux
/// lignes, pas quatre) tout en gardant une marge confortable sous le budget
/// de 200 %. Verrouillé par le test dédié dans
/// `test/features/settings/presentation/widgets/a11y_rows_test.dart`
/// (mesuré sur un écran de 375 pt, iPhone SE).
const double kA11yTristateTrailingMaxWidth = 176;

/// Ligne de réglage tri-état, ouvrant une sheet à trois choix.
///
/// Motif du choix d'une sheet plutôt que de trois pastilles côte à côte :
/// trois libellés alignés déborderaient à 200 % de taille de texte, soit
/// exactement le défaut que cet écran corrige.
class A11yTristateRow extends StatelessWidget {
  const A11yTristateRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.sheetTitle,
    required this.onChanged,
    this.iconAsset,
    this.showDivider = true,
  });

  final String label;
  final String subtitle;
  final String value;
  final String sheetTitle;
  final ValueChanged<String> onChanged;
  final String? iconAsset;
  final bool showDivider;

  Future<void> _open(BuildContext context) async {
    final picked = await DonyBottomSheet.show<String>(
      context,
      title: sheetTitle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.base),
        child: DonyRadioGroup<String>(
          value: value,
          onChanged: (v) {
            if (v != null) {
              Navigator.of(context, rootNavigator: true).pop(v);
            }
          },
          options: const [
            DonyRadioOption(
              value: AccessibilityMode.system,
              label: 'Suivre le téléphone',
              subtitle: 'Utilise le réglage défini dans votre téléphone',
            ),
            DonyRadioOption(
              value: AccessibilityMode.on,
              label: 'Toujours activé',
              subtitle: 'Quel que soit le réglage du téléphone',
            ),
            DonyRadioOption(
              value: AccessibilityMode.off,
              label: 'Toujours désactivé',
              subtitle: 'Quel que soit le réglage du téléphone',
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyListTile(
      label: label,
      subtitle: subtitle,
      iconAsset: iconAsset,
      iconColor: cs.primary,
      iconBgColor: cs.primaryContainer,
      showDivider: showDivider,
      onTap: () => _open(context),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kA11yTristateTrailingMaxWidth,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                a11yModeLabel(value),
                textAlign: TextAlign.end,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
