import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/my_negotiation_summary.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Puce « Votre tour » / « Proposition en attente » posée sur une carte de
/// demande d'envoi quand le voyageur connecté la négocie déjà (FLUTTER-NZ).
///
/// `myTurn` vrai : couleur d'action, c'est à lui de répondre. Faux : ton
/// neutre, il attend l'expéditeur. Un appui ouvre le fil de négociation
/// (`/negotiations/{threadId}`) plutôt que la fiche de la demande.
class MyNegotiationChip extends StatelessWidget {
  const MyNegotiationChip({
    super.key,
    required this.negotiation,
    this.onTap,
    this.onImage = false,
  });

  final MyNegotiationSummary negotiation;

  /// Remplace l'ouverture du fil (tests, écrans hors GoRouter).
  final VoidCallback? onTap;

  /// Variante posée sur une photo (carrousel) : fond opaque pour rester
  /// lisible sur n'importe quelle image.
  final bool onImage;

  void _open(BuildContext context) {
    final tap = onTap;
    if (tap != null) {
      tap();
      return;
    }
    if (GoRouter.maybeOf(context) == null) return;
    context.push('/negotiations/${negotiation.threadId}');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final myTurn = negotiation.myTurn;
    final label = myTurn
        ? l.requestMyNegotiationYourTurn
        : l.requestMyNegotiationPending;
    final foreground = myTurn
        ? (onImage ? cs.onPrimary : cs.primary)
        : cs.onSurfaceVariant;
    final background = myTurn
        ? (onImage ? cs.primary : cs.primaryContainer)
        : (onImage ? cs.surface : cs.surfaceContainerHighest);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('my-negotiation-chip'),
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        // Zone de toucher élargie verticalement (44 pt) sans grossir la puce.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  myTurn ? Icons.reply_rounded : Icons.hourglass_top_rounded,
                  size: 14,
                  color: foreground,
                ),
                const SizedBox(width: DonySpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
