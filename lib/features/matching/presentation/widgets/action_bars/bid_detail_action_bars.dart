import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_dispatch.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => _showRejectDialog(context),
              icon: DonyIcon('x', size: 20, color: cs.error),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(l.bidDetailDeclineRequestButton, maxLines: 1),
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
                  : () => dispatchBidAccept(context, bid),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DonyColors.white,
                      ),
                    )
                  : const DonyIcon('check', color: DonyColors.white),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(l.bidDetailAcceptRequestButton, maxLines: 1),
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
    // DonyBottomSheet (useRootNavigator: true + contenu scrollable inset-aware) :
    // un showModalBottomSheet brut avec un TextField autofocus gérait mal le
    // clavier et figeait la feuille sur device réel. Bouton dans stickyBottom
    // (règle CLAUDE.md). Le refus est dispatché sur le BidBloc du détail via le
    // [context] capturé (la feuille root-navigator n'a pas le provider).
    final l = context.l10n;
    final reasonNotifier = ValueNotifier<String>('');
    DonyBottomSheet.show<void>(
      context,
      title: l.bidDetailDeclineRequestTitle,
      subtitle: l.bidDetailDeclineRequestSubtitle,
      isDanger: true,
      stickyBottom: DonyButton(
        label: l.bidDetailConfirmDecline,
        variant: DonyButtonVariant.destructive,
        onPressed: () {
          final reason = reasonNotifier.value.trim();
          context.pop();
          context.read<BidBloc>().add(
            BidRejectRequested(bid.id, reason: reason.isEmpty ? null : reason),
          );
        },
      ),
      child: _RejectReasonField(onChanged: (v) => reasonNotifier.value = v),
    ).whenComplete(reasonNotifier.dispose);
  }
}

// ── Reject reason field ───────────────────────────────────────────────────────

/// Champ de saisie de la raison de refus. StatefulWidget pour posséder le
/// `TextEditingController` (disposé proprement à son retrait) au lieu d'un
/// controller créé dans la closure du sheet, qui levait
/// « used after being disposed » pendant l'animation de fermeture.
class _RejectReasonField extends StatefulWidget {
  const _RejectReasonField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_RejectReasonField> createState() => _RejectReasonFieldState();
}

class _RejectReasonFieldState extends State<_RejectReasonField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextField(
      controller: _controller,
      maxLines: 3,
      autofocus: true,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: context.l10n.bidDetailReasonHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        hintStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

  /// Whether the sender pays Yadony online (escrow). Only [BidPaymentMethod.stripe]
  /// involves an in-app sender payment. Cash / Wave / Orange Money are settled in
  /// person with the traveler — Yadony already collects its commission from the
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
              child: DonyIcon('ellipsis', size: 22, color: cs.onSurfaceVariant),
            ),
          ),
          if (bid.status == 'PENDING' || bid.status == 'ACCEPTED') ...[
            const SizedBox(width: DonySpacing.md),
            Expanded(
              // Cash / Wave / Orange Money: paid in person, Yadony's commission
              // is collected from the traveler server-side — never show an
              // online sender payment button or its loading placeholder.
              child: bid.paymentMethod == BidPaymentMethod.mobileMoney
                  ? const _MobileMoneyBadge()
                  : !_hasOnlineSenderPayment
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
                      icon: const DonyIcon(
                        'lock',
                        size: 18,
                        color: DonyColors.white,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          context.l10n.bidDetailPayMyShipment,
                          maxLines: 1,
                        ),
                      ),
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
        label: context.l10n.bidDetailDeleteRequest,
        iconAsset: 'trash-2',
        variant: DonyButtonVariant.destructive,
        onPressed: isLoading ? null : () => _showDeleteDialog(context),
        isLoading: isLoading,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text(l.bidDetailDeleteRequest, style: tt.headlineMedium),
        content: Text(
          l.bidDetailDeleteRejectedBody,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              l.commonCancel,
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
            child: Text(l.commonDelete, style: tt.labelLarge),
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
    final (String icon, Color color, String label) = _resolve(context.l10n, cs);

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
          DonyIcon(icon, color: color, size: 18),
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

  (String, Color, String) _resolve(AppLocalizations l, ColorScheme cs) {
    final amount = formatPriceIn(payment.amount, payment.currency);
    return switch (payment.status) {
      PaymentStatus.released => (
        'circle-check',
        cs.success,
        l.bidDetailEscrowReleasedLabel(amount),
      ),
      PaymentStatus.refunded => (
        'refresh-cw',
        cs.onSurfaceVariant,
        l.bidDetailEscrowRefundedLabel(amount),
      ),
      PaymentStatus.failed => (
        'circle-alert',
        cs.error,
        l.bidDetailEscrowFailedLabel,
      ),
      _ when bidStatus == 'PENDING' => (
        'clock',
        cs.warning,
        l.bidDetailEscrowSecuredPendingLabel,
      ),
      _ when bidStatus == 'ACCEPTED' => (
        'lock',
        cs.success,
        l.bidDetailEscrowSecuredLabel(amount),
      ),
      _ => ('lock', cs.success, l.bidDetailEscrowSecuredLabel(amount)),
    };
  }
}

/// Informational pill shown to the sender when the deal is settled in person
/// (cash / Wave / Orange Money). There is no online sender payment: Yadony's
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
          DonyIcon('banknote', color: color, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Flexible(
            child: Text(
              context.l10n.bidDetailCashAtDropoffLabel,
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

/// Informational pill shown to the sender when the deal is settled via
/// mobile money (pawaPay). Same shape as [_CashBadge], but with the primary
/// accent to signal an online (escrowed) settlement rather than a plain
/// in-person cash exchange.
class _MobileMoneyBadge extends StatelessWidget {
  const _MobileMoneyBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

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
          DonyIcon('smartphone', color: color, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Flexible(
            child: Text(
              context.l10n.bidDetailMobileMoneyPaymentLabel,
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
          if (bid.canCancelBeforeHandover) ...[
            _OptionTile(
              iconAsset: 'ban',
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: l.bidDetailCancelRequestLabel,
              subtitle: l.bidDetailCancelRefundAutoSubtitle,
              onTap: () {
                context.pop();
                _showCancelDialog(outerContext);
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
          if (bid.status == 'COMPLETED' ||
              bid.status == 'REJECTED' ||
              bid.status == 'CANCELLED') ...[
            _OptionTile(
              iconAsset: 'trash-2',
              iconColor: cs.error,
              iconBg: cs.errorLight,
              label: l.bidDetailDeleteRequest,
              subtitle: l.bidDetailRemoveFromHistorySubtitle,
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

  void _showCancelDialog(BuildContext context) {
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
              context.read<BidBloc>().add(BidCancelRequested(bid.id));
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

  void _showDeleteDialog(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text(l.bidDetailDeleteRequest, style: tt.headlineMedium),
        content: Text(
          l.bidDetailDeleteConfirmBody,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              l.commonCancel,
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
            child: Text(l.commonDelete, style: tt.labelLarge),
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
