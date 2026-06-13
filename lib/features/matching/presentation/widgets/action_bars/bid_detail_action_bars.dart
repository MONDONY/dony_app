import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le sheet d'options expéditeur (signaler / contacter / partager /
/// annuler / supprimer).
void showSenderOptionsSheet(BuildContext context, BidModel bid) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SenderOptionsSheet(bid: bid, outerContext: context),
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
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => _showRejectDialog(context),
              icon: const Icon(Icons.close_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Refuser', maxLines: 1),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      if (bid.paymentMethod == BidPaymentMethod.cash) {
                        context.read<BidAcceptanceBloc>().add(
                          ace.BidAcceptRequested(bid.id),
                        );
                      } else {
                        context.read<BidBloc>().add(BidAcceptRequested(bid.id));
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DonyColors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Accepter', maxLines: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.success,
                foregroundColor: DonyColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasonCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DonyRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Text('Refuser la demande', style: tt.headlineMedium),
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Souhaitez-vous indiquer une raison à l\'expéditeur ?',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.md),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                decoration: InputDecoration(
                  hintText: 'Raison (optionnelle)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  hintStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ctx.pop(),
                    child: Text(
                      'Annuler',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  FilledButton(
                    onPressed: () {
                      ctx.pop();
                      context.read<BidBloc>().add(
                        BidRejectRequested(
                          bid.id,
                          reason: reasonCtrl.text.trim().isEmpty
                              ? null
                              : reasonCtrl.text.trim(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: DonyColors.white,
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirmer le refus',
                      style: tt.labelLarge?.copyWith(color: DonyColors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        label: 'Confirmer ma présence',
        icon: Icons.location_on_rounded,
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

// ── Sender action bar ─────────────────────────────────────────────────────────

class SenderActionBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  final PaymentModel? existingPayment;
  final bool paymentLoaded;

  const SenderActionBar({
    super.key,
    required this.bid,
    required this.isLoading,
    this.existingPayment,
    this.paymentLoaded = false,
  });

  void _openOptions(BuildContext context) =>
      showSenderOptionsSheet(context, bid);

  /// Whether the sender pays dony online (escrow). Only [BidPaymentMethod.stripe]
  /// involves an in-app sender payment. Cash / Wave / Orange Money are settled in
  /// person with the traveler — dony already collects its commission from the
  /// traveler server-side — so the sender must NOT see "Payer mon envoi".
  bool get _hasOnlineSenderPayment =>
      bid.paymentMethod == BidPaymentMethod.stripe;

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
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _openOptions(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: cs.outline),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 22),
            ),
          ),
          if (bid.status == 'PENDING' || bid.status == 'ACCEPTED') ...[
            const SizedBox(width: DonySpacing.md),
            Expanded(
              // Cash / Wave / Orange Money: paid in person, dony's commission
              // is collected from the traveler server-side — never show an
              // online sender payment button or its loading placeholder.
              child: !_hasOnlineSenderPayment
                  ? const _CashBadge()
                  : !paymentLoaded
                  ? Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : existingPayment != null
                  ? EscrowBadge(
                      payment: existingPayment!,
                      bidStatus: bid.status,
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          context.push('/payments/pay', extra: bid),
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: const Text('Payer mon envoi'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: DonyColors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.lg),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Traveler REJECTED bar ─────────────────────────────────────────────────────

class TravelerRejectedBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;

  const TravelerRejectedBar({
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
        label: 'Supprimer cette demande',
        icon: Icons.delete_outline_rounded,
        variant: DonyButtonVariant.destructive,
        onPressed: isLoading ? null : () => _showDeleteDialog(context),
        isLoading: isLoading,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande refusée sera retirée définitivement de votre liste.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Annuler',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidTravelerDismissRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Supprimer', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class EscrowBadge extends StatelessWidget {
  final PaymentModel payment;
  final String bidStatus;

  const EscrowBadge({
    super.key,
    required this.payment,
    required this.bidStatus,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String label) = _resolve(cs);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Flexible(
            child: Text(
              label,
              style: tt.titleSmall?.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _resolve(ColorScheme cs) {
    final amount = payment.amount.toStringAsFixed(2);
    return switch (payment.status) {
      PaymentStatus.released => (
        Icons.check_circle_rounded,
        cs.success,
        'Voyageur payé — $amount €',
      ),
      PaymentStatus.refunded => (
        Icons.replay_rounded,
        cs.onSurfaceVariant,
        'Remboursé — $amount €',
      ),
      PaymentStatus.failed => (
        Icons.error_outline_rounded,
        cs.error,
        'Paiement échoué',
      ),
      _ when bidStatus == 'PENDING' => (
        Icons.lock_clock_rounded,
        cs.warning,
        'Paiement sécurisé · En attente du voyageur',
      ),
      _ when bidStatus == 'ACCEPTED' => (
        Icons.lock_rounded,
        cs.success,
        'Paiement sécurisé — $amount €',
      ),
      _ => (Icons.lock_rounded, cs.success, 'Paiement sécurisé — $amount €'),
    };
  }
}

/// Informational pill shown to the sender when the deal is settled in person
/// (cash / Wave / Orange Money). There is no online sender payment: dony's
/// commission is collected from the traveler server-side. Styled like
/// [EscrowBadge] but with a warning tone.
class _CashBadge extends StatelessWidget {
  const _CashBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = cs.warning;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined, color: color, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Flexible(
            child: Text(
              'Paiement en espèces à la remise',
              style: tt.titleSmall?.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderOptionsSheet extends StatelessWidget {
  final BidModel bid;
  final BuildContext outerContext;

  const _SenderOptionsSheet({required this.bid, required this.outerContext});

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
          _OptionTile(
            icon: Icons.flag_outlined,
            iconColor: cs.error,
            iconBg: cs.errorLight,
            label: 'Signaler ce trajet',
            subtitle: 'Signaler un problème au support Dony',
            onTap: () {
              context.pop();
              _showReportSheet(outerContext);
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          _OptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: cs.primary,
            iconBg: cs.primaryContainer,
            label: 'Contacter le voyageur',
            subtitle: 'Envoyer un message au voyageur',
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
              icon: Icons.share_rounded,
              iconColor: cs.primary,
              iconBg: cs.primaryContainer,
              label: 'Partager le suivi',
              subtitle: 'Envoyer le lien de suivi au destinataire',
              onTap: () {
                context.pop();
                shareTrackingLink(bid);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (bid.status == 'PENDING') ...[
            _OptionTile(
              icon: Icons.block_rounded,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: 'Annuler la demande',
              subtitle: 'Votre paiement sera remboursé automatiquement',
              onTap: () {
                context.pop();
                _showCancelDialog(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          // Annulation après remise (D5) — colis déjà chez le voyageur, avant le
          // départ. L'expéditeur récupère son colis via le code de retour.
          if (bid.status == 'HANDED_OVER' && _canCancelAfterHandover(bid)) ...[
            _OptionTile(
              icon: Icons.block_rounded,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: 'Annuler la demande',
              subtitle: 'Remboursement intégral · vous récupérez votre colis',
              onTap: () {
                context.pop();
                _showAfterHandoverCancelDialog(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (bid.status == 'COMPLETED' ||
              bid.status == 'REJECTED' ||
              bid.status == 'CANCELLED') ...[
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: 'Supprimer cette demande',
              subtitle: 'Retirer définitivement de votre historique',
              onTap: () {
                context.pop();
                _showDeleteDialog(outerContext);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
        ],
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasons = [
      'Informations fausses sur le trajet',
      'Comportement inapproprié',
      'Tentative d\'arnaque',
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
              Text('Signaler ce trajet', style: tt.headlineMedium),
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: cs.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DonyRadius.sm,
                              ),
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

  void _showCancelDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Annuler la demande', style: tt.headlineMedium),
        content: Text(
          'Voulez-vous vraiment annuler votre demande d\'envoi ? Cette action est définitive.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Non',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidCancelRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Oui, annuler', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }

  /// Annulation après remise possible tant que le départ canonique n'est pas
  /// atteint (verrou D3 — le serveur renvoie 409 sinon).
  static bool _canCancelAfterHandover(BidModel bid) {
    final departure = bid.resolvedDepartureAt;
    return departure == null || DateTime.now().isBefore(departure);
  }

  void _showAfterHandoverCancelDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Annuler après remise ?', style: tt.headlineMedium),
        content: Text(
          'Le colis est déjà chez le voyageur. Vous serez intégralement remboursé '
          'et récupérerez votre colis : le voyageur confirmera la restitution en '
          'saisissant votre code de retour.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Non',
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
            child: Text('Oui, annuler', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text('Supprimer cette demande', style: tt.headlineMedium),
        content: Text(
          'Cette demande sera définitivement supprimée de votre historique.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Annuler',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<BidBloc>().add(BidDeleteRequested(bid.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text('Supprimer', style: tt.labelLarge),
          ),
        ],
      ),
    );
  }
}

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
