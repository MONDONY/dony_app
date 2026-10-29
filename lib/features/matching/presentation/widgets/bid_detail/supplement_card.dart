import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_refusal_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_pay_button.dart';
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
///
/// Colis payé en espèces (PR A4) : commission à valider, complément remis en
/// main propre, commission rendue quand la demande n'aboutit pas.
///
/// Commission à valider ([needsReply]) : la carte n'est plus montée dans le
/// corps de la fiche, c'est la tuile « Supplément de prix » de « À traiter ».
/// Son sheet montre ce contenu sans cadre (`framed: false`, sans bouton ni
/// mesure d'affichage) et porte « Valider le paiement » / « Retirer la
/// demande » dans son pied ([SupplementCommissionButtons]).
class SupplementTravelerCard extends StatelessWidget {
  const SupplementTravelerCard({
    super.key,
    required this.bid,
    this.framed = true,
  });

  final BidModel bid;

  /// `false` : contenu seul, pour le sheet de la tuile (ni cadre, ni titre, ni
  /// bouton, ni cubit, ni mesure `bid_supplement_viewed`, émise à l'affichage
  /// de la tuile).
  final bool framed;

  /// Une demande retirée ou annulée ne laisse rien à dire au voyageur, sauf
  /// en espèces : une demande annulée (commission jamais validée, colis
  /// terminé) ou retirée après le prélèvement de sa commission dit ce
  /// qu'il advient de la commission.
  static bool shouldShow(BidModel bid) {
    final s = bid.supplement;
    return switch (s?.status) {
      null || BidSupplementStatus.unknown => false,
      BidSupplementStatus.cancelled => s!.isCash,
      BidSupplementStatus.withdrawn => s!.isCash && _commissionTaken(s),
      _ => true,
    };
  }

  /// La commission espèces attend la validation du voyageur (« Valider le
  /// paiement », 3DS possible) : seul cas où la carte relève de « À traiter ».
  /// Une demande proposée attend l'expéditeur (« Retirer la demande » reste un
  /// geste facultatif) ; refusée ou expirée, le colis part au prix prévu et
  /// « Le colis ne correspond pas » reste un choix, pas une réponse attendue.
  static bool needsReply(BidModel bid) =>
      bid.supplement?.status == BidSupplementStatus.commissionPending;

  @override
  Widget build(BuildContext context) => framed
      ? _SupplementCard(bid: bid, isSender: false)
      : _TravelerContent(
          bid: bid,
          supplement: bid.supplement!,
          withActions: false,
        );
}

/// Commission du supplément prélevée au voyageur (rendue ou à rendre).
bool _commissionTaken(BidSupplement s) =>
    s.commissionCharged ||
    s.commissionRefunded ||
    s.commissionStatus == SupplementCommissionStatus.refundFailed;

/// Encart « Supplément de prix » de la vue expéditeur : motif, photo, TOTAL
/// à payer seulement (jamais le net du voyageur ni la commission),
/// échéance et « Refuser le supplément ». « Payer » (carte, mobile money)
/// ou « Accepter » (espèces) est dans la barre du bas
/// ([SupplementPayButton]).
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

  /// Le supplément attend une réponse de l'expéditeur (accepter et payer, ou
  /// refuser) : seul cas où la carte relève de « À traiter ». Payé, versé,
  /// refusé ou expiré, elle ne fait que renseigner.
  static bool needsReply(BidModel bid) => switch (bid.supplement?.status) {
    BidSupplementStatus.proposed || BidSupplementStatus.paymentPending => true,
    _ => false,
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

  void _reloadBid(BuildContext context) => _reloadBidOf(context, bid.id);
}

/// Encart hors de l'écran de détail (tests) : rien à relire.
void _reloadBidOf(BuildContext context, String bidId) =>
    _bidBlocOf(context)?.add(BidDetailRequested(bidId));

class _TravelerContent extends StatelessWidget {
  const _TravelerContent({
    required this.bid,
    required this.supplement,
    this.withActions = true,
  });

  final BidModel bid;
  final BidSupplement supplement;

  /// Boutons de la carte d'information (« Retirer la demande » d'une demande
  /// proposée, « Le colis ne correspond pas »). `false` dans le sheet de la
  /// tuile, dont le pied porte les boutons.
  final bool withActions;

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
            cash: s.isCash,
          )
        : null;
    final netLabel = formatSupplementAmount(net ?? s.grossAmount, s.currency);
    final grossLabel = formatSupplementAmount(s.grossAmount, s.currency);
    final paid =
        s.status == BidSupplementStatus.paid ||
        s.status == BidSupplementStatus.payoutPending;
    final closedUnpaid = switch (s.status) {
      BidSupplementStatus.declined ||
      BidSupplementStatus.expired ||
      BidSupplementStatus.withdrawn ||
      BidSupplementStatus.cancelled ||
      BidSupplementStatus.refunded => true,
      _ => false,
    };

    final children = <Widget>[
      switch (s.status) {
        BidSupplementStatus.commissionPending => _StatusLine(
          iconAsset: 'credit-card',
          color: cs.warning,
          text: l.supplementTravelerCommissionPending,
        ),
        BidSupplementStatus.proposed => _StatusLine(
          iconAsset: 'timer',
          color: cs.warning,
          text: l.supplementTravelerPending,
        ),
        BidSupplementStatus.paymentPending => _StatusLine(
          iconAsset: _isMobileMoney(bid) ? 'smartphone' : 'credit-card',
          color: cs.warning,
          text: l.supplementTravelerPaymentPending,
        ),
        BidSupplementStatus.paid ||
        BidSupplementStatus.payoutPending when s.isCash => _StatusLine(
          iconAsset: 'banknote',
          color: cs.success,
          text: l.supplementTravelerCashPaid(grossLabel),
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
        BidSupplementStatus.withdrawn => _StatusLine(
          iconAsset: 'circle-x',
          color: cs.onSurfaceVariant,
          text: l.supplementWithdrawn,
        ),
        BidSupplementStatus.cancelled => _StatusLine(
          iconAsset: 'circle-x',
          color: cs.onSurfaceVariant,
          text: l.supplementTravelerCancelled,
        ),
        BidSupplementStatus.refundPending => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementTravelerRefundPending,
        ),
        _ when s.isCash => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementTravelerCashRefunded,
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
        if (s.status == BidSupplementStatus.commissionPending)
          _HelpText(l.supplementTravelerCommissionPendingHelp)
        else if (s.isCash && s.commissionCharged)
          _HelpText(l.supplementTravelerCashCommissionHelp),
        _HelpText(l.supplementTravelerPendingNotice),
      ],
      if (paid)
        _HelpText(
          s.isCash
              ? l.supplementTravelerCashPaidHelp
              : l.supplementTravelerPaidHelp,
        ),
      if (s.status == BidSupplementStatus.declined ||
          s.status == BidSupplementStatus.expired)
        _HelpText(l.supplementTravelerClosedHelp),
      if (s.isCash && closedUnpaid) ?_cashCommissionHelp(l, s),
    ];

    if (!withActions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced(children),
      );
    }

    // La commission à valider n'est pas une carte d'information : ses
    // boutons sont dans le pied du sheet de la tuile.
    final canWithdraw = s.status == BidSupplementStatus.proposed;
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
              onPressed: action.isBusy
                  ? null
                  : () => _confirmWithdraw(context, bid, s),
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
}

/// « Retirer la demande » : confirmation destructive, puis
/// [SupplementActionCubit.withdraw] (le cubit de la carte, ou celui du sheet
/// de la tuile). Rien n'est envoyé si le bouton a disparu pendant la
/// confirmation (colis relu entre-temps, demande déjà traitée). Bouton
/// démonté pendant l'appel (sheet refermé de force) : son écouteur n'est plus
/// là, le colis est relu ici à la réponse.
Future<void> _confirmWithdraw(
  BuildContext context,
  BidModel bid,
  BidSupplement supplement,
) async {
  final l = context.l10n;
  final cubit = context.read<SupplementActionCubit>();
  final bidBloc = _bidBlocOf(context);
  final confirmed = await DonyDialog.show(
    context,
    title: l.supplementWithdrawConfirmTitle,
    message: l.supplementWithdrawConfirmMessage,
    confirmLabel: l.supplementWithdraw,
    cancelLabel: l.commonCancel,
    variant: DonyDialogVariant.destructive,
  );
  if (confirmed != true || !context.mounted) return;
  await cubit.withdraw(bid, supplement);
  if (!context.mounted) bidBloc?.add(BidDetailRequested(bid.id));
}

BidBloc? _bidBlocOf(BuildContext context) {
  try {
    return context.read<BidBloc>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Espèces, demande close : ce qu'il advient de la commission du
/// supplément. `null` quand il n'y a rien à dire (demande déjà remboursée
/// à l'expéditeur après paiement : la ligne d'état suffit).
Widget? _cashCommissionHelp(AppLocalizations l, BidSupplement s) {
  if (s.commissionRefunded) {
    return _HelpText(l.supplementTravelerCommissionRefunded);
  }
  if (s.commissionCharged ||
      s.commissionStatus == SupplementCommissionStatus.refundFailed) {
    return _HelpText(l.supplementTravelerCommissionRefundPending);
  }
  if (s.status == BidSupplementStatus.cancelled) {
    return _HelpText(l.supplementTravelerCancelledNoCharge);
  }
  return null;
}

/// Pied du sheet de la tuile « Supplément de prix » (commission à valider,
/// colis payé en espèces), empilé en pleine largeur : « Valider le paiement »
/// en haut, « Retirer la demande » dessous.
///
/// Lit [SupplementCommissionCubit] et [SupplementActionCubit] dans le
/// contexte : ils sont créés par le `wrapper` du sheet, qui enveloppe aussi
/// son contenu. Les issues (fermeture, confirmation, erreurs, relecture du
/// colis) sont traitées par le contenu du sheet. Pendant un appel, les deux
/// boutons sont désactivés.
///
/// « Valider le paiement » : `requirePaymentAuth` ([authorize]), puis
/// `…/commission/confirm` et la 3DS si la carte la redemande. Jamais un
/// nouveau `POST`. Une vérification refusée est dite par-dessus le sheet.
class SupplementCommissionButtons extends StatelessWidget {
  const SupplementCommissionButtons({
    super.key,
    required this.bid,
    required this.supplement,
    this.authorize,
    this.enabled = true,
  });

  final BidModel bid;
  final BidSupplement supplement;

  /// `false` : derniers boutons connus, désactivés, gardés le temps que le
  /// sheet se referme quand la demande n'attend plus le voyageur.
  final bool enabled;

  /// Vérification locale ; `null` en usage réel (`requirePaymentAuth`).
  final SupplementRequestAuthorizer? authorize;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final commission = context.watch<SupplementCommissionCubit>().state;
    final action = context.watch<SupplementActionCubit>().state;
    final busy = !enabled || commission.isBusy || action.isBusy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyButton(
          key: const Key('supplement-commission-confirm-btn'),
          label: l.supplementCommissionConfirm,
          iconAsset: 'credit-card',
          isLoading: commission.isBusy,
          onPressed: busy ? null : () => _confirm(context),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('supplement-withdraw-btn'),
          label: l.supplementWithdraw,
          variant: DonyButtonVariant.destructiveGhost,
          isLoading: action.isBusy,
          onPressed: busy
              ? null
              : () => _confirmWithdraw(context, bid, supplement),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final cubit = context.read<SupplementCommissionCubit>();
    final bidBloc = _bidBlocOf(context);
    if (!cubit.beginAuthorization()) return;
    final authenticated = await (authorize ?? defaultSupplementAuthorize)(
      context,
    );
    if (!context.mounted) {
      cubit.authorizationDenied();
      return;
    }
    if (!authenticated) {
      cubit.authorizationDenied();
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
      return;
    }
    await cubit.resume(bid, supplement);
    // Sheet refermé de force pendant l'appel ou la 3DS : son écouteur n'est
    // plus là pour relire le colis, la tuile resterait jusqu'au relevé.
    if (!context.mounted) bidBloc?.add(BidDetailRequested(bid.id));
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
          iconAsset: s.isCash ? 'banknote' : 'credit-card',
          color: cs.warning,
          text: l.supplementSenderPendingTitle,
        ),
        BidSupplementStatus.paymentPending when _isMobileMoney(bid) =>
          _StatusLine(
            iconAsset: 'smartphone',
            color: cs.warning,
            text: l.supplementSenderMobileMoneyPending,
          ),
        BidSupplementStatus.paymentPending => _StatusLine(
          iconAsset: 'credit-card',
          color: cs.warning,
          text: l.supplementSenderPaymentPending,
        ),
        BidSupplementStatus.paid ||
        BidSupplementStatus.payoutPending ||
        BidSupplementStatus.paidOut when s.isCash => _StatusLine(
          iconAsset: 'banknote',
          color: cs.success,
          text: l.supplementSenderCashPaid(gross),
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
        BidSupplementStatus.refundPending => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementSenderRefundPending,
        ),
        _ when s.isCash => _StatusLine(
          iconAsset: 'refresh-cw',
          color: cs.onSurfaceVariant,
          text: l.supplementSenderCashRefunded,
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
        if (SupplementPayButton.canPay(bid))
          _HelpText(
            s.isCash ? l.supplementSenderCashHelp : l.supplementSenderPayHelp,
          ),
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

/// Supplément payé (ou à payer) en mobile money : rail du colis.
bool _isMobileMoney(BidModel bid) =>
    SupplementPayButton.railOf(bid) == SupplementCheckout.railPawapay;

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
