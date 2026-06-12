import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/cancellation_dialog.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Statuses for which the traveler can cancel the trip.
const _cancellableStatuses = {'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT'};

/// Statuses for which the traveler can dismiss/delete the bid record.
const _dismissableStatuses = {'REJECTED', 'CANCELLED'};

/// Opens the ⋮ options bottom sheet for the TRAVELER view of a bid.
void showTravelerOptionsSheet(BuildContext context, BidModel bid) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TravelerOptionsSheet(bid: bid, outerContext: context),
  );
}

class _TravelerOptionsSheet extends StatelessWidget {
  final BidModel bid;
  final BuildContext outerContext;

  const _TravelerOptionsSheet({required this.bid, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final h = DonyLayout.hPadding(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(h, 0, h, bottomPad + DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Options', style: tt.headlineMedium),
            const SizedBox(height: DonySpacing.base),

            // ── Contacter l'expéditeur (always) ────────────────────────────
            _OptionTile(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: cs.primary,
              iconBg: cs.primaryContainer,
              label: "Contacter l'expéditeur",
              subtitle: 'Envoyer un message à l\'expéditeur',
              onTap: () {
                context.pop();
                outerContext.read<ConversationOpenBloc>().add(
                      ConversationOpenRequested(bid.id),
                    );
              },
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Détails du colis (always) ───────────────────────────────────
            _OptionTile(
              icon: Icons.inventory_2_outlined,
              iconColor: cs.primary,
              iconBg: cs.primaryContainer,
              label: 'Détails du colis',
              subtitle: 'Voir les informations du colis et du destinataire',
              onTap: () {
                context.pop();
                _showColisSheet(outerContext, bid);
              },
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Partager le suivi (only if trackingToken available) ─────────
            if (bid.trackingToken != null) ...[
              _OptionTile(
                icon: Icons.share_rounded,
                iconColor: cs.primary,
                iconBg: cs.primaryContainer,
                label: 'Partager le suivi',
                subtitle: 'Envoyer le lien de suivi à l\'expéditeur',
                onTap: () {
                  context.pop();
                  shareTrackingLink(bid);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],

            // ── Signaler l'expéditeur (always) ──────────────────────────────
            _OptionTile(
              icon: Icons.flag_outlined,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: "Signaler l'expéditeur",
              subtitle: 'Signaler un problème au support Dony',
              onTap: () {
                context.pop();
                _showReportSheet(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),

            // ── Annuler le trajet (ACCEPTED / HANDED_OVER / IN_TRANSIT) ────
            if (_cancellableStatuses.contains(bid.status)) ...[
              _OptionTile(
                icon: Icons.block_rounded,
                iconColor: cs.error,
                iconBg: cs.errorLight,
                label: 'Annuler le trajet',
                subtitle: 'L\'expéditeur sera remboursé automatiquement',
                onTap: () {
                  context.pop();
                  _showCancelDialog(outerContext, bid);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],

            // ── Supprimer cette demande (REJECTED / CANCELLED) ──────────────
            if (_dismissableStatuses.contains(bid.status)) ...[
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: cs.error,
                iconBg: cs.errorLight,
                label: 'Supprimer cette demande',
                subtitle: 'Retirer définitivement de votre historique',
                onTap: () {
                  context.pop();
                  outerContext
                      .read<BidBloc>()
                      .add(BidTravelerDismissRequested(bid.id));
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sub-sheets ────────────────────────────────────────────────────────────

  void _showColisSheet(BuildContext context, BidModel bid) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          bottomPad + DonySpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Détails du colis', style: tt.headlineMedium),
            const SizedBox(height: DonySpacing.base),
            ColisDestinataireCard(bid: bid),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasons = [
      'Comportement inapproprié',
      'Informations fausses',
      'Tentative d\'arnaque',
      'Non-respect des délais',
      'Autre',
    ];
    String? selected;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DonyRadius.sheet),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            0,
            DonySpacing.lg,
            MediaQuery.of(ctx).padding.bottom + DonySpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text("Signaler l'expéditeur", style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Votre signalement sera traité par l\'équipe Dony.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.base),
              ...reasons.map(
                (r) => RadioListTile<String>(
                  value: r,
                  groupValue: selected,
                  onChanged: (v) => setSheetState(() => selected = v),
                  title: Text(r, style: tt.bodyMedium),
                  activeColor: cs.primary,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyButton(
                label: 'Envoyer le signalement',
                variant: DonyButtonVariant.destructive,
                onPressed: selected == null
                    ? null
                    : () {
                        ctx.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Signalement envoyé. Merci !',
                              style: tt.bodyMedium?.copyWith(
                                color: DonyColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: cs.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DonyRadius.sm),
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(BuildContext context, BidModel bid) async {
    final isInTransit = bid.status == 'IN_TRANSIT';
    final reason = await CancellationDialog.show(
      context,
      isInTransit: isInTransit,
    );
    if (reason != null && context.mounted) {
      context.read<BidBloc>().add(
            BidCancelRequested(
              bid.id,
              reason: reason.isEmpty ? null : reason,
            ),
          );
    }
  }
}

// ── Shared tile widget ────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
