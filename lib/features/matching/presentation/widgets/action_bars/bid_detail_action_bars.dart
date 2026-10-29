import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_dispatch.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_entry.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/confirm_delete_bid.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/tracking_actions.dart';
import 'package:dony/features/matching/presentation/widgets/commission_allocation_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/reject_reason_sheet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le sheet d'options expéditeur (signaler / contacter / partager /
/// annuler / supprimer).
void showSenderOptionsSheet(BuildContext context, BidModel bid) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // Jusqu'à six entrées (signaler, contacter, partager, modifier le
    // destinataire, annuler, supprimer) : la hauteur par défaut (9/16 de
    // l'écran) ne suffit plus sur un petit téléphone, le contenu défile.
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SenderOptionsSheet(bid: bid, outerContext: context),
  );
}

/// Confirmation d'annulation d'une demande par l'expéditeur, avant remise du
/// colis (remboursement automatique). Partagée entre la feuille d'options et la
/// carte « fenêtre de remise dépassée ». `context` doit voir le [BidBloc] de
/// l'écran de détail.
void showSenderCancelBidDialog(BuildContext context, BidModel bid) {
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  final l = context.l10n;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
      ),
      title: Text(l.bidDetailCancelRequestLabel, style: tt.headlineMedium),
      content: Text(
        l.bidDetailCancelConfirmBody,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => ctx.pop(),
          child: Text(
            l.bidDetailNo,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () {
            ctx.pop();
            context.read<BidBloc>().add(
              BidCancelRequested(bid.id, actor: 'sender'),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: DonyColors.white,
            elevation: 0,
          ),
          child: Text(l.bidDetailConfirmCancelButton, style: tt.labelLarge),
        ),
      ],
    ),
  );
}

// ── Traveler PENDING bar ──────────────────────────────────────────────────────

class TravelerPendingBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;

  const TravelerPendingBar({
    super.key,
    required this.bid,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      // Refuser (1/3) | Accepter (2/3), deux DonyButton de 52 px sur une ligne.
      child: Row(
        children: [
          Expanded(
            child: DonyButton(
              label: l.bidDetailDeclineRequestButton,
              // Sans icône : à 360 dp, 1/3 de la ligne laisse 70 px au contenu
              // du bouton ; l'icône (22 px) forcerait « Refuser » / « Decline »
              // à rétrécir dans le FittedBox du DonyButton.
              variant: DonyButtonVariant.destructiveGhost,
              onPressed: isLoading ? null : () => _showRejectDialog(context),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            flex: 2,
            child: DonyButton(
              label: l.bidDetailAcceptRequestButton,
              iconAsset: 'check',
              variant: DonyButtonVariant.success,
              isLoading: isLoading,
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!await confirmCashCommissionAllocation(
                        context,
                        bid,
                      )) {
                        return;
                      }
                      if (context.mounted) dispatchBidAccept(context, bid);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    // La feuille vit sur le navigateur racine, sans le BidBloc du détail : le
    // refus est dispatché via le [context] capturé, une fois la feuille fermée.
    final reason = await RejectReasonSheet.show(context);
    if (reason == null || !context.mounted) return;
    context.read<BidBloc>().add(
      BidRejectRequested(bid.id, reason: reason.code),
    );
  }
}

// ── Confirm presence bar ──────────────────────────────────────────────────────

class ConfirmPresenceBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;

  const ConfirmPresenceBar({
    super.key,
    required this.bid,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: DonyButton(
        label: context.l10n.bidDetailConfirmPresence,
        iconAsset: 'map-pin',
        onPressed: isLoading
            ? null
            : () => context.read<BidBloc>().add(
                BidConfirmPresenceRequested(bid.id),
              ),
        isLoading: isLoading,
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _SenderOptionsSheet extends StatelessWidget {
  final BidModel bid;
  final BuildContext outerContext;

  const _SenderOptionsSheet({required this.bid, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final h = DonyLayout.hPadding(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(h, 0, h, bottomPad + DonySpacing.xl),
      child: SingleChildScrollView(
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
            Text(l.bidDetailOptionsTitle, style: tt.headlineMedium),
            const SizedBox(height: DonySpacing.base),
            _OptionTile(
              iconAsset: 'flag',
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: l.bidDetailReportTripLabel,
              subtitle: l.bidDetailReportSubtitle,
              onTap: () {
                context.pop();
                _showReportSheet(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
            _OptionTile(
              iconAsset: 'message-circle',
              iconColor: cs.primary,
              iconBg: cs.primaryContainer,
              label: l.bidDetailContactTravelerLabel,
              subtitle: l.bidDetailContactTravelerSubtitle,
              onTap: () {
                context.pop();
                outerContext.read<ConversationOpenBloc>().add(
                  ConversationOpenRequested(bid.id),
                );
              },
            ),
            const SizedBox(height: DonySpacing.sm),
            if (bid.trackingToken != null) ...[
              _OptionTile(
                iconAsset: 'share-2',
                iconColor: cs.primary,
                iconBg: cs.primaryContainer,
                label: l.bidDetailShareTracking,
                subtitle: l.bidDetailShareTrackingSubtitle,
                onTap: () {
                  final origin = sharePositionOriginFor(context);
                  context.pop();
                  shareTrackingLink(bid, sharePositionOrigin: origin);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (bid.canChangeRecipient) ...[
              _OptionTile(
                iconAsset: 'square-pen',
                iconColor: cs.primary,
                iconBg: cs.primaryContainer,
                label: l.recipientChangeTitle,
                subtitle: l.recipientChangeOptionSubtitle,
                onTap: () {
                  context.pop();
                  openRecipientChangeSheet(outerContext, bid);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (AmendmentEntry.shouldShow(bid)) ...[
              _OptionTile(
                iconAsset: 'plus',
                iconColor: cs.primary,
                iconBg: cs.primaryContainer,
                label: l.amendmentSheetTitle,
                subtitle: l.amendmentEntryButton,
                onTap: () {
                  context.pop();
                  unawaited(AmendmentEntry.open(outerContext, bid));
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (bid.canCancelBeforeHandover) ...[
              _OptionTile(
                iconAsset: 'ban',
                iconColor: cs.error,
                iconBg: cs.errorLight,
                label: l.bidDetailCancelRequestLabel,
                subtitle: l.bidDetailCancelRefundAutoSubtitle,
                onTap: () {
                  context.pop();
                  showSenderCancelBidDialog(outerContext, bid);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            // Annulation après remise (D5) — colis déjà chez le voyageur, avant le
            // départ. L'expéditeur récupère son colis via le code de retour.
            if (bid.canCancelAfterHandover) ...[
              _OptionTile(
                iconAsset: 'ban',
                iconColor: cs.error,
                iconBg: cs.errorLight,
                label: l.bidDetailCancelRequestLabel,
                subtitle: l.bidDetailCancelAfterHandoverOptionSubtitle,
                onTap: () {
                  context.pop();
                  _showAfterHandoverCancelDialog(outerContext);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            // « Supprimer cette demande » a quitté le footer : le menu la
            // propose pour tous les envois clos (COMPLETED, REJECTED,
            // CANCELLED, NO_SHOW, EXPIRED, PARCEL_REFUSED).
            if (kEnvoisPasses.contains(bid.status)) ...[
              _OptionTile(
                iconAsset: 'trash-2',
                iconColor: cs.error,
                iconBg: cs.errorLight,
                label: l.bidDetailDeleteRequest,
                subtitle: l.bidDetailRemoveFromHistorySubtitle,
                onTap: () {
                  context.pop();
                  confirmDeleteBid(outerContext, bid);
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  /// Signalement réel du trajet (bid) — délègue au flux existant
  /// (IncidentReportScreen) plutôt que de réimplémenter un formulaire
  /// parallèle qui n'appelait jamais l'API : voir profile_public_screen.dart
  /// pour le même patron sur le signalement d'un utilisateur.
  void _showReportSheet(BuildContext context) {
    context.push(
      '/settings/report-incident',
      extra: {'targetType': IncidentTargetType.bid, 'targetId': bid.id},
    );
  }

  void _showAfterHandoverCancelDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text(
          l.bidDetailCancelAfterHandoverTitle,
          style: tt.headlineMedium,
        ),
        content: Text(
          l.bidDetailCancelAfterHandoverBody,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              l.bidDetailNo,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<CancellationBloc>().add(
                CancelAfterHandoverRequested(bid.id, actor: 'sender'),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text(l.bidDetailConfirmCancelButton, style: tt.labelLarge),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String iconAsset;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.iconAsset,
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
              child: DonyIcon(iconAsset, color: iconColor, size: 18),
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
            DonyIcon('chevron-right', color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
