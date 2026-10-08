import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xl,
        vertical: DonySpacing.huge,
      ),
      // Le contenu défile et les boutons restent épinglés en bas : clavier
      // ouvert sur un petit écran, le Dialog rétrécit (il soustrait déjà
      // viewInsets) et seule la zone texte se replie (Sentry FLUTTER-FJ).
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const Key('cancellation_dialog_scroll'),
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.xl,
                DonySpacing.xl,
                DonySpacing.xl,
                DonySpacing.base,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Titre ──────────────────────────────────────────────
                  Text(l.bidCancelDialogTitle, style: tt.headlineSmall),
                  const SizedBox(height: DonySpacing.sm),

                  // ── Sous-titre (cas accepted) ──────────────────────────
                  if (!widget._isAfterHandover) ...[
                    Text(
                      l.bidCancelAcceptedSubtitle,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
                          DonyIcon('triangle-alert', color: cs.error, size: 18),
                          const SizedBox(width: DonySpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.bidCancelWarningMessage,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.error,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: DonySpacing.sm),
                                Text(
                                  l.bidCancelWarningRefundNote,
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
                          ? l.bidCancelReasonRequiredHint
                          : l.bidCancelReasonOptionalHint,
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
                          color: _showReasonError ? cs.error : cs.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        borderSide: BorderSide(
                          color: _showReasonError ? cs.error : cs.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        borderSide: BorderSide(color: cs.error),
                      ),
                      errorText: _showReasonError
                          ? l.bidCancelReasonRequiredError
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Boutons (pleine largeur, libellé centré sur une ligne) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xl,
              0,
              DonySpacing.xl,
              DonySpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Annuler la demande" — confirm, destructive
                FilledButton(
                  key: const Key('cancellation_dialog_confirm'),
                  onPressed: _onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.lg),
                    ),
                  ),
                  child: _OneLineLabel(
                    l.bidCancelConfirmButton,
                    style: tt.labelLarge?.copyWith(color: cs.onError),
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                // "Garder" — dismiss
                OutlinedButton(
                  key: const Key('cancellation_dialog_keep'),
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outline),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.lg),
                    ),
                  ),
                  child: _OneLineLabel(
                    l.bidCancelKeepButton,
                    style: tt.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Libellé de bouton tenu sur une ligne et centré : réduit plutôt que de
/// passer à la ligne quand la police système est agrandie.
class _OneLineLabel extends StatelessWidget {
  const _OneLineLabel(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }
}
