import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Libellé long affiché dans la sheet de choix, un par option : c'est là que
/// l'utilisateur décide, il a besoin du sens complet ('Suivre le téléphone'
/// plutôt que 'Automatique' explicite ce que fait réellement ce choix).
String a11yModeLabel(String mode) => switch (mode) {
      AccessibilityMode.on => 'Toujours activé',
      AccessibilityMode.off => 'Toujours désactivé',
      _ => 'Suivre le téléphone',
    };

/// Libellé court affiché comme valeur de fin de ligne (avant ouverture de la
/// sheet) : distinct de [a11yModeLabel] parce qu'une valeur de ligne doit
/// tenir sur un mot, là où le choix complet a besoin d'une phrase — les
/// fusionner forcerait soit une phrase entière en bout de ligne (déborde),
/// soit un mot unique dans la sheet (perd le sens).
String a11yModeShortLabel(String mode) => switch (mode) {
      AccessibilityMode.on => 'Activé',
      AccessibilityMode.off => 'Désactivé',
      _ => 'Automatique',
    };

/// Largeur maximale du bloc de fin (libellé court de mode + chevron) de
/// [A11yTristateRow].
///
/// `DonyListTile` ne borne pas son slot `trailing` (un enfant non-flex d'un
/// `Row` reçoit toute la largeur disponible comme contrainte, quels que
/// soient les autres enfants) : sans borne, un libellé long ('Suivre le
/// téléphone', 228 px de large sans contrainte à 100 %) réclamerait sa
/// largeur naturelle sur une seule ligne et ferait déborder tout le `Row` du
/// parent à 200 % de taille de texte. C'est ce qui a motivé le passage à
/// [a11yModeShortLabel] pour cette position : le plus long des trois
/// libellés courts, 'Automatique', ne fait que ~136 px de large sur une
/// ligne au rendu réel à 100 % (mesuré via un widget pompé, style
/// `bodySmall` ; un `TextPainter` autonome hors arbre de widgets sous-estime
/// cette largeur d'environ 4 px, la police n'étant pas garantie chargée de
/// la même façon — se fier au rendu réel, pas à une mesure isolée).
///
/// 168 px tient ce libellé sur une seule ligne à 100 % (136 px de texte +
/// 4 px d'espacement + 20 px de chevron = 160 px, sous la borne ; en
/// pratique le seuil exact est 165 px, vérifié par balayage) ET ne fait pas
/// déborder à 200 % : sur l'écran de test le plus étroit couramment ciblé
/// (360 pt logiques une fois le zoom pris en compte), le `Row` entier
/// dispose d'environ 260 px pour le libellé principal, l'espacement et ce
/// bloc combinés — 168 px laisse encore ~84 px au libellé principal
/// ('Contraste élevé' etc., qui peut se replier sur plusieurs lignes sans
/// jamais faire déborder un `Expanded`), et une largeur de 200 px en ce
/// point reproduit un débordement (vérifié). Contrairement à
/// [a11yModeLabel], aucun compromis n'est nécessaire ici : plus de retour à
/// la ligne ni de risque de débordement, dans les deux configurations.
/// Verrouillé par les tests dédiés dans
/// `test/features/settings/presentation/widgets/a11y_rows_test.dart`
/// (mesuré sur un écran de 375 pt, iPhone SE).
const double kA11yTristateTrailingMaxWidth = 168;

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
                a11yModeShortLabel(value),
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
