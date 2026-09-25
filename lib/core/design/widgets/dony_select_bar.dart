import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/l10n/l10n.dart';
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
    this.defaultLabel,
    this.confirmedLabel,
    this.selectedSummary,
    this.selectedCount,
    required this.onConfirm,
    this.isLoading = false,
  });

  /// Label du bouton quand rien n'est sélectionné (bouton désactivé).
  final String? defaultLabel;

  /// Label du bouton quand une sélection est active (bouton activé).
  final String? confirmedLabel;

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
    final l = context.l10n;

    final hasSelection = selectedSummary != null;
    final effectiveDefaultLabel = defaultLabel ?? l.dsSelect;
    final effectiveConfirmedLabel = confirmedLabel ?? l.dsConfirmSelection;

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
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedCount != null) ...[
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    '✓ $selectedCount', // i18n-ignore : format, la valeur est déjà localisée par l'appelant
                    style: tt.bodySmall?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3, duration: 200.ms),
          ),

        // ── Bouton principal ────────────────────────────────────────────────
        DonyButton(
          label: hasSelection ? effectiveConfirmedLabel : effectiveDefaultLabel,
          onPressed: onConfirm,
          isLoading: isLoading,
        ),
      ],
    );
  }
}
