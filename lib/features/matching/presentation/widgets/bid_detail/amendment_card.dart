import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Modification en cours ou dernière modification close sans avoir été
/// acquise. Le serveur ne sert que les modifications acquises et la dernière
/// non acquise récente (moins de 7 jours) : pas de filtre de date ici.
BidAmendment? _openOf(BidModel bid) =>
    bid.amendments.where((a) => a.status.isOpen).lastOrNull;

BidAmendment? _closedOf(BidModel bid) =>
    bid.amendments.where((a) => a.status.isClosedUnaccepted).lastOrNull;

/// Acquises, de la plus ancienne à la plus récente (le serveur trie ainsi).
List<BidAmendment> _securedOf(BidModel bid) =>
    bid.amendments.where((a) => a.status.isSecured).toList();

/// Encart « Modification du colis » de la vue expéditeur : la demande en
/// attente (brut, échéance, « Annuler ma demande ») ou sa fin (refusée,
/// expirée, annulée, paiement échoué). Jamais le net ni la commission du
/// voyageur. Une modification acceptée se lit dans la carte Paiement.
class AmendmentSenderCard extends StatelessWidget {
  const AmendmentSenderCard({super.key, required this.bid});

  final BidModel bid;

  /// La demande ouverte d'abord. Tant que le colis est `ACCEPTED`, une
  /// modification acquise passe avant une close : la fin d'une autre demande
  /// ne doit pas la masquer (elle se lit dans la carte Paiement). Sinon la
  /// plus récente des closes.
  static BidAmendment? _current(BidModel bid) =>
      _openOf(bid) ??
      (bid.status == 'ACCEPTED' && _securedOf(bid).isNotEmpty
          ? null
          : _closedOf(bid));

  static bool shouldShow(BidModel bid) => _current(bid) != null;

  /// Une demande est encore ouverte (l'expéditeur peut l'annuler ou la régler) :
  /// seul cas où la carte relève de « À traiter ». Une demande close (refusée,
  /// expirée, annulée, paiement échoué) ne fait que renseigner.
  static bool needsReply(BidModel bid) => _openOf(bid) != null;

  @override
  Widget build(BuildContext context) {
    final amendment = _current(bid);
    if (amendment == null) return const SizedBox.shrink();
    return _AmendmentCardShell(
      bid: bid,
      amendment: amendment,
      isSender: true,
      child: _SenderContent(bid: bid, amendment: amendment),
    );
  }
}

/// Encart « Modification du colis » de la vue voyageur : invitation à
/// répondre (net, commission, kilos), modification acceptée avec « Les kilos
/// en plus ne sont pas là » avant la remise, ou fin de la demande.
class AmendmentTravelerCard extends StatelessWidget {
  const AmendmentTravelerCard({super.key, required this.bid, this.authorize});

  final BidModel bid;

  /// Vérification locale avant d'accepter en espèces (la commission est
  /// prélevée) ; `null` en usage réel (`requirePaymentAuth`).
  final SupplementRequestAuthorizer? authorize;

  /// Demande ouverte, puis une section par modification acquise tant que le
  /// colis est `ACCEPTED` (une « Les kilos en plus ne sont pas là » chacune),
  /// sinon la dernière close.
  static List<BidAmendment> _sections(BidModel bid) {
    final open = _openOf(bid);
    final secured = bid.status == 'ACCEPTED'
        ? _securedOf(bid)
        : const <BidAmendment>[];
    final closed = _closedOf(bid);
    return [?open, ...secured, if (open == null && secured.isEmpty) ?closed];
  }

  static bool shouldShow(BidModel bid) => _sections(bid).isNotEmpty;

  /// Une section de la carte attend une réponse du voyageur : seul cas où la
  /// carte relève de « À traiter ». C'est le cas d'une demande proposée
  /// (« Accepter » / « Refuser ») et d'une commission à finaliser (« Finaliser
  /// la commission », sa propre 3DS). Une modification acquise (« Les kilos en
  /// plus ne sont pas là », geste facultatif), l'autorisation carte et le
  /// paiement (qui attendent l'expéditeur) et une demande close ne font que
  /// renseigner.
  static bool needsReply(BidModel bid) => _sections(bid).any(
    (a) =>
        a.status == BidAmendmentStatus.proposed ||
        a.status == BidAmendmentStatus.commissionPending,
  );

  @override
  Widget build(BuildContext context) {
    final sections = _sections(bid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.base),
          _AmendmentCardShell(
            key: ValueKey(sections[i].id),
            bid: bid,
            amendment: sections[i],
            isSender: false,
            child: _TravelerContent(
              bid: bid,
              amendment: sections[i],
              authorize: authorize ?? defaultSupplementAuthorize,
            ),
          ),
        ],
      ],
    );
  }
}

/// Fournit le cubit d'actions, trace l'affichage et relit le colis après une
/// action (le `BidBloc` de l'écran, s'il est là).
class _AmendmentCardShell extends StatelessWidget {
  const _AmendmentCardShell({
    super.key,
    required this.bid,
    required this.amendment,
    required this.isSender,
    required this.child,
  });

  final BidModel bid;
  final BidAmendment amendment;
  final bool isSender;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocProvider(
      create: (_) =>
          getIt<AmendmentActionCubit>()
            ..viewed(isSender: isSender, status: amendment.status),
      child: BlocListener<AmendmentActionCubit, AmendmentActionState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          switch (state.status) {
            case AmendmentActionStatus.done:
              _reloadBid(context, bid.id);
              DonySnackbar.show(
                context,
                message: isSender
                    ? l.amendmentCancelledSnackbar
                    : amendment.status.isSecured
                    ? l.amendmentNotBroughtSnackbar
                    : l.amendmentDeclinedSnackbar,
                type: DonySnackbarType.success,
              );
            case AmendmentActionStatus.failure:
              ErrorPresenter.show(context, state.error);
              // Déjà traitée ou expirée entre-temps : la fiche montre le vrai état.
              _reloadBid(context, bid.id);
            case AmendmentActionStatus.idle || AmendmentActionStatus.busy:
              break;
          }
        },
        child: DetailCard(title: l.amendmentSenderTitle, child: child),
      ),
    );
  }
}

void _reloadBid(BuildContext context, String bidId) {
  try {
    context.read<BidBloc>().add(BidDetailRequested(bidId));
  } on ProviderNotFoundException {
    // Encart hors de l'écran de détail (tests) : rien à relire.
  }
}

String _money(double amount, String currency, {bool signed = false}) =>
    '${signed ? '+' : ''}${formatSupplementAmount(amount, currency)}';

String _kg(double kg) =>
    '${kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString()} kg';

/// « 25 oct. à 14:30 » en heure locale.
String _deadlineLabel(BuildContext context, DateTime at) {
  final l = context.l10n;
  final local = at.toLocal();
  return l.amendmentDeadlineFormat(
    DateFormat.MMMd(l.localeName).format(local),
    DateFormat.Hm(l.localeName).format(local),
  );
}

int _hoursLeft(DateTime at) {
  final minutes = at.difference(DateTime.now()).inMinutes;
  return minutes <= 0 ? 0 : (minutes / 60).ceil();
}

/// Lignes de la modification : les kilos puis les articles. Le montant des
/// kilos est le total moins celui des articles (la modification ne porte que
/// le total et les articles).
List<_Line> _lines(BuildContext context, BidAmendment a, {required bool net}) {
  final l = context.l10n;
  double amountOf(BidAmendmentItem i) =>
      net ? (i.netAmount ?? 0) : i.grossAmount;
  final total = net ? (a.netAmount ?? 0) : a.grossAmount;
  final itemsTotal = a.items.fold<double>(0, (sum, i) => sum + amountOf(i));
  return [
    if (a.addedWeightKg > 0)
      _Line(
        l.amendmentSheetKgValue(_kg(a.addedWeightKg).replaceAll(' kg', '')),
        _money(total - itemsTotal, a.currency, signed: net),
      ),
    for (final i in a.items)
      _Line(
        i.quantity > 1 ? '${i.label} × ${i.quantity}' : i.label,
        _money(amountOf(i), a.currency, signed: net),
      ),
  ];
}

class _Line {
  const _Line(this.label, this.amount);

  final String label;
  final String amount;
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines});

  final List<_Line> lines;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
                Text(
                  line.amount,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.amount, this.color});

  final String label;
  final String amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: DonySpacing.base, color: cs.outline),
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.titleMedium?.copyWith(color: cs.onSurface),
              ),
            ),
            Text(
              amount,
              style: tt.titleMedium?.copyWith(
                color: color ?? cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon(iconAsset, color: color, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(text, style: tt.titleSmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
    );
  }
}

List<Widget> _spaced(List<Widget> children) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) const SizedBox(height: DonySpacing.sm),
    children[i],
  ],
];

// ── Expéditeur ───────────────────────────────────────────────────────────────

class _SenderContent extends StatelessWidget {
  const _SenderContent({required this.bid, required this.amendment});

  final BidModel bid;
  final BidAmendment amendment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final a = amendment;
    final name = bid.travelerName ?? l.bidDetailSenderTravelerFallback;
    final kg = _kg(bid.totalWeightKg ?? bid.weightKg ?? 0);
    final canCancel =
        a.status == BidAmendmentStatus.proposed ||
        a.status == BidAmendmentStatus.authorizationPending;

    if (!a.status.isOpen) {
      final held = a.rail == BidAmendment.railStripe;
      final refund =
          a.status == BidAmendmentStatus.refundPending ||
          a.status == BidAmendmentStatus.refunded;
      final captureFailed = a.closedReason == 'CAPTURE_FAILED';
      final String statusText;
      final String body;
      if (a.status == BidAmendmentStatus.refundPending) {
        statusText = l.amendmentSenderRefundPendingStatus;
      } else if (a.closedReason == 'NOT_BROUGHT') {
        statusText = l.amendmentSenderNotBroughtStatus(name);
      } else if (refund) {
        statusText = l.amendmentSenderRefundedStatus;
      } else if (captureFailed) {
        statusText = l.amendmentSenderCaptureFailedStatus;
      } else if (a.status == BidAmendmentStatus.declined) {
        statusText = l.amendmentSenderRefusedStatus(name);
      } else if (a.status == BidAmendmentStatus.expired) {
        statusText = l.amendmentSenderExpiredStatus(name);
      } else {
        statusText = l.amendmentSenderCancelledStatus;
      }
      // Cash : rien n'a été payé. Carte : le montant bloqué est libéré, ou
      // remboursé si la modification avait été acquise. Mobile money : seul
      // un dépôt déjà fait se rembourse.
      if (refund || a.closedReason == 'NOT_BROUGHT') {
        body = a.isCash
            ? l.amendmentSenderRefusedBody(kg)
            : l.amendmentSenderRefundBody(kg);
      } else {
        body = held
            ? l.amendmentSenderBodyCardReleased(kg)
            : l.amendmentSenderRefusedBody(kg);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced([
          _StatusLine(
            iconAsset: a.status == BidAmendmentStatus.expired
                ? 'timer-off'
                : 'circle-x',
            color: captureFailed ? cs.error : cs.onSurfaceVariant,
            text: statusText,
          ),
          _Note(body),
        ]),
      );
    }

    final accepted = a.status == BidAmendmentStatus.paymentPending;
    final deadline = a.expiresAt;
    return BlocBuilder<AmendmentActionCubit, AmendmentActionState>(
      builder: (context, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._spaced([
            _StatusLine(
              iconAsset: accepted ? 'smartphone' : 'timer',
              color: cs.warning,
              text: accepted
                  ? l.amendmentSenderAcceptedStatus(name)
                  : l.amendmentSenderPendingStatus(name),
            ),
            _LinesTable(lines: _lines(context, a, net: false)),
          ]),
          _TotalRow(
            label: a.isCash
                ? l.amendmentSenderPendingLine
                : a.isMobileMoney
                ? l.amendmentSenderPendingLineMobileMoney
                : l.amendmentSenderPendingLineCard,
            amount: _money(a.grossAmount, a.currency),
          ),
          const SizedBox(height: DonySpacing.sm),
          if (accepted && a.isMobileMoney)
            _Note(l.amendmentSenderPayNow)
          else if (deadline != null)
            _Note(
              l.amendmentSenderPendingDeadline(
                _deadlineLabel(context, deadline),
                _hoursLeft(deadline).toString(),
                kg,
              ),
            ),
          if (canCancel) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('amendment-cancel-btn'),
              label: l.amendmentCancelButton,
              variant: DonyButtonVariant.destructiveGhost,
              isLoading: action.isBusy,
              onPressed: action.isBusy ? null : () => _cancel(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<AmendmentActionCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.amendmentCancelConfirmTitle,
      message: l.amendmentCancelConfirmMessage,
      confirmLabel: l.amendmentCancelButton,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed != true) return;
    await cubit.cancel(bid, amendment);
  }
}

// ── Voyageur ─────────────────────────────────────────────────────────────────

class _TravelerContent extends StatefulWidget {
  const _TravelerContent({
    required this.bid,
    required this.amendment,
    required this.authorize,
  });

  final BidModel bid;
  final BidAmendment amendment;
  final SupplementRequestAuthorizer authorize;

  @override
  State<_TravelerContent> createState() => _TravelerContentState();
}

/// D'où prélever la commission (espèces) : choisi par le voyageur après un
/// « solde insuffisant ».
typedef _CommissionChoice = ({
  SupplementCommissionSource source,
  String? funding,
});

class _TravelerContentState extends State<_TravelerContent> {
  final _choice = ValueNotifier<_CommissionChoice>((
    source: SupplementCommissionSource.wallet,
    funding: null,
  ));

  @override
  void dispose() {
    _choice.dispose();
    super.dispose();
  }

  BidModel get bid => widget.bid;
  BidAmendment get a => widget.amendment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final name = bid.senderName ?? l.bidSenderFallbackName;

    switch (a.status) {
      case BidAmendmentStatus.proposed:
        return _proposed(context, name);
      case BidAmendmentStatus.commissionPending:
        return _commissionPending(context);
      case BidAmendmentStatus.paymentPending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced([
            _StatusLine(
              iconAsset: 'smartphone',
              color: cs.warning,
              text: l.amendmentTravelerWaitingPayment(name),
            ),
            _Note(l.amendmentTravelerAcceptedBody),
          ]),
        );
      case BidAmendmentStatus.accepted ||
          BidAmendmentStatus.payoutPending ||
          BidAmendmentStatus.paidOut:
        return _accepted(context);
      default:
        return _StatusLine(
          iconAsset: 'circle-x',
          color: cs.onSurfaceVariant,
          text: switch (a.status) {
            BidAmendmentStatus.declined => l.amendmentTravelerDeclinedStatus,
            BidAmendmentStatus.expired => l.amendmentTravelerExpiredStatus,
            BidAmendmentStatus.cancelled => l.amendmentTravelerCancelledStatus(
              name,
            ),
            _ => l.amendmentTravelerClosedStatus,
          },
        );
    }
  }

  Widget _proposed(BuildContext context, String name) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final net = a.netAmount ?? 0;
    final commission = a.commissionAmount;
    final deadline = a.expiresAt;
    final before = bid.totalWeightKg ?? bid.weightKg;
    return BlocProvider(
      create: (_) => getIt<AmendmentAcceptCubit>(),
      child: BlocConsumer<AmendmentAcceptCubit, AmendmentAcceptState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onAcceptState,
        builder: (context, accept) {
          final action = context.watch<AmendmentActionCubit>().state;
          final busy = accept.isBusy || action.isBusy;
          final unfunded = accept.status == AmendmentAcceptStatus.unfunded
              ? accept.unfunded
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._spaced([
                _StatusLine(
                  iconAsset: 'package',
                  color: cs.primary,
                  text: l.amendmentTravelerInviteStatus(name),
                ),
                if (deadline != null)
                  Text(
                    l.amendmentTravelerDeadline(
                      _deadlineLabel(context, deadline),
                      _hoursLeft(deadline).toString(),
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: cs.warning),
                  ),
                _LinesTable(lines: _lines(context, a, net: true)),
              ]),
              _TotalRow(
                label: l.amendmentTravelerForYou,
                amount: _money(net, a.currency, signed: true),
                color: cs.success,
              ),
              const SizedBox(height: DonySpacing.sm),
              if (before != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.amendmentTravelerParcelWeight,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      l.amendmentTravelerParcelWeightValue(
                        _kg(before).replaceAll(' kg', ''),
                        _kg(before + a.addedWeightKg).replaceAll(' kg', ''),
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              const SizedBox(height: DonySpacing.sm),
              _Note(
                a.isCash && commission == null
                    ? l.amendmentTravelerCashNoteNoCommission(
                        name,
                        _money(a.grossAmount, a.currency),
                      )
                    : a.isCash
                    ? l.amendmentTravelerCashNote(
                        name,
                        _money(a.grossAmount, a.currency),
                        _money(commission!, a.currency),
                      )
                    : a.isMobileMoney
                    ? l.amendmentTravelerMobileMoneyNote(
                        name,
                        _money(a.grossAmount, a.currency),
                      )
                    : l.amendmentTravelerCardNote(
                        name,
                        _money(a.grossAmount, a.currency),
                      ),
              ),
              if (a.isCash && unfunded != null) ...[
                const SizedBox(height: DonySpacing.md),
                DonyStatusBanner(
                  type: DonyStatusBannerType.warning,
                  message: CommissionSourceRadios.unfundedMessage(l, unfunded),
                ),
                const SizedBox(height: DonySpacing.sm),
                ValueListenableBuilder<_CommissionChoice>(
                  valueListenable: _choice,
                  builder: (context, choice, _) => CommissionSourceRadios(
                    source: choice.source,
                    fundingCurrency: choice.funding,
                    unfunded: unfunded,
                    locked: busy,
                    onSelected: (source, {fundingCurrency}) => _choice.value = (
                      source: source,
                      funding: fundingCurrency,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                key: const Key('amendment-accept-btn'),
                label: l.amendmentAccept(_money(net, a.currency, signed: true)),
                variant: DonyButtonVariant.success,
                isLoading: accept.isBusy,
                onPressed: busy ? null : () => _accept(context),
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('amendment-decline-btn'),
                label: l.amendmentDecline,
                variant: DonyButtonVariant.ghost,
                onPressed: busy ? null : () => _decline(context),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 3DS abandonnée : l'acceptation n'est pas finalisée. « Finaliser la
  /// commission » passe par `…/commission/confirm`, jamais un nouvel accept.
  Widget _commissionPending(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => getIt<AmendmentAcceptCubit>(),
      child: BlocConsumer<AmendmentAcceptCubit, AmendmentAcceptState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onAcceptState,
        builder: (context, accept) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._spaced([
              _StatusLine(
                iconAsset: 'credit-card',
                color: cs.warning,
                text: l.amendmentTravelerCommissionPending,
              ),
              _Note(l.amendmentTravelerCommissionPendingHelp),
            ]),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('amendment-finalize-commission-btn'),
              label: l.amendmentCommissionFinalize,
              iconAsset: 'credit-card',
              isLoading: accept.isBusy,
              onPressed: accept.isBusy ? null : () => _finalize(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalize(BuildContext context) async {
    final cubit = context.read<AmendmentAcceptCubit>();
    final authenticated = await widget.authorize(context);
    if (!context.mounted) return;
    if (!authenticated) {
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
      return;
    }
    await cubit.resume(bid, a);
  }

  Widget _accepted(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<AmendmentActionCubit, AmendmentActionState>(
      builder: (context, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._spaced([
            _StatusLine(
              iconAsset: 'circle-check',
              color: cs.success,
              text: l.amendmentTravelerAcceptedStatus,
            ),
            _Note(l.amendmentTravelerAcceptedBody),
          ]),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('amendment-not-brought-btn'),
            label: l.amendmentNotBrought,
            variant: DonyButtonVariant.destructiveGhost,
            isLoading: action.isBusy,
            onPressed: action.isBusy ? null : () => _notBrought(context),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final cubit = context.read<AmendmentAcceptCubit>();
    if (a.isCash) {
      final authenticated = await widget.authorize(context);
      if (!context.mounted) return;
      if (!authenticated) {
        DonySnackbar.show(
          context,
          message: context.l10n.paymentNotConfirmedSnackbar,
          type: DonySnackbarType.error,
        );
        return;
      }
    }
    final choice = _choice.value;
    await cubit.accept(
      bid,
      a,
      source: a.isCash ? choice.source : null,
      fundingCurrency: choice.funding,
    );
  }

  void _onAcceptState(BuildContext context, AmendmentAcceptState state) {
    final l = context.l10n;
    switch (state.status) {
      case AmendmentAcceptStatus.accepted:
        _reloadBid(context, bid.id);
        DonySnackbar.show(
          context,
          message: l.amendmentAcceptedSnackbar,
          type: DonySnackbarType.success,
        );
      case AmendmentAcceptStatus.failure:
        if (state.error == null) {
          DonySnackbar.show(
            context,
            message: l.amendmentCommissionAuthInterrupted,
            type: DonySnackbarType.error,
          );
        } else {
          ErrorPresenter.show(context, state.error);
        }
        // Capture refusée, expirée entre-temps : la fiche montre le vrai état.
        _reloadBid(context, bid.id);
      case AmendmentAcceptStatus.pending:
        _reloadBid(context, bid.id);
        DonySnackbar.show(
          context,
          message: l.amendmentCommissionProcessingSnackbar,
        );
      case AmendmentAcceptStatus.unfunded ||
          AmendmentAcceptStatus.idle ||
          AmendmentAcceptStatus.accepting ||
          AmendmentAcceptStatus.commissionAuth:
        break;
    }
  }

  Future<void> _decline(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<AmendmentActionCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.amendmentDeclineConfirmTitle,
      message: l.amendmentDeclineConfirmMessage,
      confirmLabel: l.amendmentDecline,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed != true) return;
    await cubit.decline(bid, a);
  }

  Future<void> _notBrought(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<AmendmentActionCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.amendmentNotBroughtConfirmTitle,
      message: l.amendmentNotBroughtConfirmMessage,
      confirmLabel: l.amendmentNotBrought,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed != true) return;
    await cubit.notBrought(bid, a);
  }
}
