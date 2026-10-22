import 'package:flutter/material.dart';

/// L'étiquette commune à tous les blocs de l'écran de recherche.
class SearchSectionLabel extends StatelessWidget {
  const SearchSectionLabel(this.label, {super.key});

  final String label;

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
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: cs.outlineVariant)),
        ],
      ),
    );
  }
}
