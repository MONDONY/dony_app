import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Barre de sélection/confirmation affichée en bas d'un écran de sélection.
///
/// Affiche une ligne de contexte animée (résumé + compteur) quand une
/// sélection est active, puis un [DonyButton] dont l'état reflète la
/// présence ou l'absence de callback.
///
/// Exemple d'usage dans un [Scaffold.bottomNavigationBar] :
/// ```dart
/// SafeArea(
///   child: Padding(
///     padding: const EdgeInsets.fromLTRB(
///         DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, DonySpacing.lg),
///     child: DonySelectBar(
///       selectedSummary: _selectedTrip?.label,
///       selectedCount: _selectedTrip != null ? '1 trajet' : null,
///       onConfirm: _selectedTrip != null ? _onConfirm : null,
///     ),
///   ),
/// )
/// ```
class DonySelectBar extends StatelessWidget {
  const DonySelectBar({
    super.key,
    this.defaultLabel = 'Sélectionner',
    this.confirmedLabel = 'Confirmer la sélection',
    this.selectedSummary,
    this.selectedCount,
    required this.onConfirm,
    this.isLoading = false,
  });

  /// Label du bouton quand rien n'est sélectionné (bouton désactivé).
  final String defaultLabel;

  /// Label du bouton quand une sélection est active (bouton activé).
  final String confirmedLabel;

  /// Résumé textuel de la sélection (ex: "Paris → Dakar sélectionné").
  /// Si `null`, la ligne de contexte n'est pas affichée.
  final String? selectedSummary;

  /// Nombre/détail affiché en vert à droite (ex: "1 trajet").
  /// Affiché uniquement si [selectedSummary] est non-null.
  final String? selectedCount;

  /// Callback de confirmation. `null` = bouton désactivé.
  final VoidCallback? onConfirm;

  /// Si `true`, le bouton affiche un spinner (état chargement).
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final hasSelection = selectedSummary != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Ligne de contexte (animée) ──────────────────────────────────────
        if (hasSelection)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedSummary!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedCount != null) ...[
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    '✓ $selectedCount',
                    style: tt.bodySmall?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            )
                .animate()
                .fadeIn(duration: 200.ms)
                .slideY(begin: -0.3, duration: 200.ms),
          ),

        // ── Bouton principal ────────────────────────────────────────────────
        DonyButton(
          label: hasSelection ? confirmedLabel : defaultLabel,
          onPressed: onConfirm,
          isLoading: isLoading,
        ),
      ],
    );
  }
}
