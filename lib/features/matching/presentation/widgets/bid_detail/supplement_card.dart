import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_refusal_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Encart « Supplément de prix » de la vue voyageur : demande en attente
/// (échéance, « Retirer la demande »), paiement en cours, payé ou versé,
/// refusé ou expiré (lien vers « Le colis ne correspond pas »), remboursé.
/// Le voyageur voit son net, la commission et le total de l'expéditeur.
class SupplementTravelerCard extends StatelessWidget {
  const SupplementTravelerCard({super.key, required this.bid});

  final BidModel bid;

  /// Une demande retirée ou annulée ne laisse rien à dire au voyageur.
  static bool shouldShow(BidModel bid) => switch (bid.supplement?.status) {
    null ||
    BidSupplementStatus.withdrawn ||
    BidSupplementStatus.cancelled ||
    BidSupplementStatus.unknown => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) =>
      _SupplementCard(bid: bid, isSender: false);
}

/// Encart « Supplément de prix » de la vue expéditeur : motif, photo, TOTAL
/// à payer seulement (jamais le net du voyageur ni la commission),
/// échéance et « Refuser le supplément ». Le paiement arrive avec les rails
/// (PR A2 à A4) : d'ici là, le back ne crée aucune demande payable.
class SupplementSenderCard extends StatelessWidget {
  const SupplementSenderCard({super.key, required this.bid});

  final BidModel bid;

  /// La commission espèces en cours de prélèvement au voyageur n'est pas
  /// encore une demande pour l'expéditeur ; une demande retirée est déjà
  /// annoncée par sa notification.
  static bool shouldShow(BidModel bid) => switch (bid.supplement?.status) {
    null ||
    BidSupplementStatus.commissionPending ||
    BidSupplementStatus.withdrawn ||
    BidSupplementStatus.cancelled ||
    BidSupplementStatus.unknown => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) =>
      _SupplementCard(bid: bid, isSender: true);
}

class _SupplementCard extends StatelessWidget {
  const _SupplementCard({required this.bid, required this.isSender});

  final BidModel bid;
  final bool isSender;

  BidSupplement get _supplement => bid.supplement!;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SupplementActionCubit>()
            ..viewed(isSender: isSender, status: _supplement.status),
      child: BlocListener<SupplementActionCubit, SupplementActionState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onActionState,
        child: DetailCard(
          title: context.l10n.supplementCardTitle,
          child: isSender
              ? _SenderContent(bid: bid, supplement: _supplement)
              : _TravelerContent(bid: bid, supplement: _supplement),
        ),
      ),
    );
  }

  void _onActionState(BuildContext context, SupplementActionState state) {
    switch (state.status) {
      case SupplementActionStatus.done:
        _reloadBid(context);
        DonySnackbar.show(
          context,
          message: isSender
              ? context.l10n.supplementDeclined
              : context.l10n.supplementWithdrawn,
          type: DonySnackbarType.success,
        );
      case SupplementActionStatus.failure:
        ErrorPresenter.show(context, state.error);
        // Demande déjà traitée ou expirée entre-temps : la fiche se met à
        // jour pour montrer le vrai état.
        _reloadBid(context);
      case SupplementActionStatus.idle || SupplementActionStatus.busy:
        break;
    }
  }

  void _reloadBid(BuildContext context) {
    try {
      context.read<BidBloc>().add(BidDetailRequested(bid.id));
    } on ProviderNotFoundException {
      // Encart hors de l'écran de détail (tests) : rien à relire.
    }
  }
}

class _TravelerContent extends StatelessWidget {
  const _TravelerContent({required this.bid, required this.supplement});

  final BidModel bid;
  final BidSupplement supplement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final s = supplement;
    final net = s.netAmount;
    final commission = s.commissionAmount;
    final recap = net != null && commission != null
        ? SupplementAmountsRecap(
            net: net,
            commission: commission,
            gross: s.grossAmount,
            currency: s.currency,
          )
        : null;
    final netLabel = formatSupplementAmount(net ?? s.grossAmount, s.currency);

    final children = <Widget>[
      switch (s.status) {
        BidSupplementStatus.commissionPending ||
        BidSupplementStatus.proposed => _StatusLine(
          iconAsset: 'timer',
          color: cs.warning,
          text: l.supplementTravelerPending,
        ),
        BidSupplementStatus.paymentPending => _StatusLine(
          iconAsset: 'credit-card',
          color: cs.warning,
          text: l.supplementTravelerPaymentPending,
        ),
        BidSupplementStatus.paid ||
        BidSupplementStatus.payoutPending => _StatusLine(
          iconAsset: 'circle-check',
          color: cs.success,
          text: l.supplementTravelerPaid(netLabel),
        ),
        BidSupplementStatus.paidOut => _StatusLine(
          iconAsset: 'banknote',
          color: cs.success,
          text: l.supplementTravelerPaidOut(netLabel),
        ),
        BidSupplementStatus.declined => _StatusLine(
          iconAsset: 'circle-x',
          color: cs.error,
          text: l.supplementTravelerDeclined,
        ),
        BidSupplementStatus.expired => _StatusLine(
          iconAsset: 'timer-off',
          color: cs.onSurfaceVariant,
          text: l.supplementTravelerExpired,
        ),
        _ => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementRefunded,
        ),
      },
      if (s.status.isOpen) ...[
        if (s.expiresAt != null) _DeadlineLine(expiresAt: s.expiresAt!),
        ?recap,
        _ReasonLine(supplement: s),
        _HelpText(l.supplementTravelerPendingNotice),
      ],
      if (s.status == BidSupplementStatus.paid ||
          s.status == BidSupplementStatus.payoutPending)
        _HelpText(l.supplementTravelerPaidHelp),
      if (s.status == BidSupplementStatus.declined ||
          s.status == BidSupplementStatus.expired)
        _HelpText(l.supplementTravelerClosedHelp),
    ];

    final canWithdraw =
        s.status == BidSupplementStatus.proposed ||
        s.status == BidSupplementStatus.commissionPending;
    final canRefuseParcel =
        (s.status == BidSupplementStatus.declined ||
            s.status == BidSupplementStatus.expired) &&
        (bid.status == 'ACCEPTED' || bid.canCancelAfterHandover);

    return BlocBuilder<SupplementActionCubit, SupplementActionState>(
      builder: (context, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._spaced(children),
          if (canWithdraw) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('supplement-withdraw-btn'),
              label: l.supplementWithdraw,
              variant: DonyButtonVariant.destructiveGhost,
              isLoading: action.isBusy,
              onPressed: action.isBusy ? null : () => _withdraw(context),
            ),
          ],
          if (canRefuseParcel) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('supplement-refuse-parcel-btn'),
              label: l.bidDetailRefuseParcelLabel,
              iconAsset: 'triangle-alert',
              variant: DonyButtonVariant.ghost,
              onPressed: () => openParcelRefusalSheet(context, bid),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<SupplementActionCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.supplementWithdrawConfirmTitle,
      message: l.supplementWithdrawConfirmMessage,
      confirmLabel: l.supplementWithdraw,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed != true) return;
    await cubit.withdraw(bid, supplement);
  }
}

class _SenderContent extends StatelessWidget {
  const _SenderContent({required this.bid, required this.supplement});

  final BidModel bid;
  final BidSupplement supplement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = supplement;
    final gross = formatSupplementAmount(s.grossAmount, s.currency);
    final open =
        s.status == BidSupplementStatus.proposed ||
        s.status == BidSupplementStatus.paymentPending;

    final children = <Widget>[
      switch (s.status) {
        BidSupplementStatus.proposed => _StatusLine(
          iconAsset: 'credit-card',
          color: cs.warning,
          text: l.supplementSenderPendingTitle,
        ),
        BidSupplementStatus.paymentPending => _StatusLine(
          iconAsset: 'credit-card',
          color: cs.warning,
          text: l.supplementSenderPaymentPending,
        ),
        BidSupplementStatus.paid ||
        BidSupplementStatus.payoutPending ||
        BidSupplementStatus.paidOut => _StatusLine(
          iconAsset: 'circle-check',
          color: cs.success,
          text: l.supplementSenderPaid(gross),
        ),
        BidSupplementStatus.declined => _StatusLine(
          iconAsset: 'circle-x',
          color: cs.onSurfaceVariant,
          text: l.supplementSenderDeclined,
        ),
        BidSupplementStatus.expired => _StatusLine(
          iconAsset: 'timer-off',
          color: cs.onSurfaceVariant,
          text: l.supplementSenderExpired,
        ),
        _ => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementSenderRefunded,
        ),
      },
      if (open) ...[
        Text(
          l.supplementSenderAmount(gross),
          style: tt.headlineSmall?.copyWith(
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (s.expiresAt != null) _DeadlineLine(expiresAt: s.expiresAt!),
        _ReasonLine(supplement: s),
        if (s.photoUrl case final url? when url.isNotEmpty)
          Semantics(
            label: l.supplementPhotoSemantics,
            image: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DonyImage(
                url: url,
                width: 120,
                height: 120,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
            ),
          ),
        _HelpText(l.supplementSenderPendingHelp),
      ],
    ];

    return BlocBuilder<SupplementActionCubit, SupplementActionState>(
      builder: (context, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._spaced(children),
          if (open) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('supplement-decline-btn'),
              label: l.supplementDecline,
              variant: DonyButtonVariant.destructiveGhost,
              isLoading: action.isBusy,
              onPressed: action.isBusy ? null : () => _decline(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<SupplementActionCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.supplementDeclineConfirmTitle,
      message: l.supplementDeclineConfirmMessage,
      confirmLabel: l.supplementDecline,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed != true) return;
    await cubit.decline(bid, supplement);
  }
}

List<Widget> _spaced(List<Widget> children) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) const SizedBox(height: DonySpacing.sm),
    children[i],
  ],
];

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.iconAsset,
    required this.color,
    required this.text,
  });

  final String iconAsset;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon(iconAsset, color: color, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            text,
            style: tt.titleSmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

/// « Réponse attendue avant 14:30 », en heure locale.
class _DeadlineLine extends StatelessWidget {
  const _DeadlineLine({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final time = DateFormat.Hm(l.localeName).format(expiresAt.toLocal());
    return Text(
      l.supplementDeadline(time),
      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}

/// Motif (« Article : Téléphone », « Poids supérieur… ») et précisions.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.supplement});

  final BidSupplement supplement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = supplement.gridItemLabel?.trim();
    final reason = switch (supplement.reason) {
      BidSupplementReason.gridItem when label != null && label.isNotEmpty =>
        l.supplementReasonWithItem(label),
      BidSupplementReason.gridItem => l.supplementReasonGridItem,
      BidSupplementReason.extraWeight => l.supplementReasonExtraWeight,
      BidSupplementReason.other || null => null,
    };
    final text = supplement.reasonText?.trim();
    if (reason == null && (text == null || text.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reason != null)
          Text(reason, style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
        if (text != null && text.isNotEmpty)
          Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _HelpText extends StatelessWidget {
  const _HelpText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}
