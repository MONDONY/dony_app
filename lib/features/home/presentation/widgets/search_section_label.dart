import 'package:flutter/material.dart';

/// L'étiquette commune à tous les blocs de l'écran de recherche.
///
/// Le bloc « En une phrase » porte exactement la même, avec `optional: true`.
/// C'est ce qui pose la parité : un champ de recherche en héros dirait que les
/// filtres sont un pis-aller, alors qu'ils sont un parcours de plein droit.
class SearchSectionLabel extends StatelessWidget {
  const SearchSectionLabel(
    this.label, {
    super.key,
    this.optional = false,
    this.tint,
  });

  final String label;
  final bool optional;

  /// Couleur du texte quand elle diffère de la teinte neutre par défaut —
  /// utilisée par [UnresolvedQuestion] pour distinguer visuellement une
  /// question du parseur des blocs de filtres ordinaires.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: tint ?? cs.onSurfaceVariant,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                'Facultatif',
                style: tt.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: cs.outlineVariant)),
        ],
      ),
    );
  }
}
