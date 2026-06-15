import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// DonyDialog retourne bool? — ce dialog retourne String? (le motif).
// On ne peut pas réutiliser DonyDialog sans modifier son contrat.

/// Nature de l'annulation côté voyageur.
///
/// - [accepted] : colis pas encore remis (status ACCEPTED). Motif optionnel,
///   remboursement automatique, pas d'obligation de retour.
/// - [afterHandover] : colis déjà remis (status HANDED_OVER), avant le départ
///   (D3). Motif obligatoire + avertissement : le voyageur doit restituer le
///   colis sous 3 jours via le code de retour détenu par l'expéditeur (D7).
enum CancellationKind { accepted, afterHandover }

/// Dialog de confirmation d'annulation pour le voyageur.
///
/// - [CancellationKind.accepted] : motif optionnel → confirme avec `""` ou `"raison"`.
/// - [CancellationKind.afterHandover] : motif obligatoire + warning retour →
///   confirme avec une String non vide.
///
/// Dans les deux cas, "Garder" → retourne `null`.
class CancellationDialog extends StatefulWidget {
  final CancellationKind kind;

  const CancellationDialog({super.key, required this.kind});

  bool get _isAfterHandover => kind == CancellationKind.afterHandover;

  /// Affiche le dialog et retourne le motif saisi, `""` si aucun motif
  /// (cas accepted), ou `null` si l'utilisateur a appuyé sur "Garder".
  static Future<String?> show(
    BuildContext context, {
    required CancellationKind kind,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: kind == CancellationKind.accepted,
      builder: (_) => CancellationDialog(kind: kind),
    );
  }

  @override
  State<CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<CancellationDialog> {
  final _reasonCtrl = TextEditingController();
  bool _showReasonError = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final reason = _reasonCtrl.text.trim();

    // Après remise : motif obligatoire.
    if (widget._isAfterHandover && reason.isEmpty) {
      setState(() => _showReasonError = true);
      return;
    }

    context.pop(reason); // "" ou raison non vide
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xl,
        vertical: DonySpacing.huge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Titre ──────────────────────────────────────────────
            Text(
              'Annuler cette demande ?',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Sous-titre (cas accepted) ──────────────────────────
            if (!widget._isAfterHandover) ...[
              Text(
                "L'expéditeur sera remboursé automatiquement.",
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.base),
            ],

            // ── Warning box (cas afterHandover) ────────────────────
            if (widget._isAfterHandover) ...[
              Container(
                padding: const EdgeInsets.all(DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DonyIcon(
                      'triangle-alert',
                      color: cs.error,
                      size: 18,
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Le colis a déjà été remis. Vous devrez le restituer à l\'expéditeur sous 3 jours en saisissant le code de retour qu\'il vous communiquera.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.error,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          Text(
                            "L'expéditeur sera intégralement remboursé. Si le paiement était en espèces, aucun mouvement d'argent n'a lieu.",
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.base),
            ],

            // ── Champ motif ────────────────────────────────────────
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_showReasonError) {
                  setState(() => _showReasonError = false);
                }
              },
              decoration: InputDecoration(
                hintText: widget._isAfterHandover
                    ? 'Motif de l\'annulation *'
                    : 'Motif (optionnel)',
                hintStyle: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  borderSide: BorderSide(
                    color: _showReasonError
                        ? cs.error
                        : cs.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  borderSide: BorderSide(
                    color: _showReasonError
                        ? cs.error
                        : cs.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  borderSide: BorderSide(color: cs.error),
                ),
                errorText: _showReasonError ? 'Motif requis' : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                  vertical: DonySpacing.md,
                ),
              ),
            ),

            const SizedBox(height: DonySpacing.xl),

            // ── Boutons ────────────────────────────────────────────
            Row(
              children: [
                // "Garder" — dismiss
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outline),
                      padding: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                    ),
                    child: Text(
                      'Garder',
                      style: tt.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                // "Annuler la demande" — confirm, destructive
                Expanded(
                  child: FilledButton(
                    onPressed: _onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                    ),
                    child: Text(
                      'Annuler la demande',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
