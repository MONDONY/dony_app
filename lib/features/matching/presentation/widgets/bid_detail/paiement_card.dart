import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/money_breakdown_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Carte « Paiement » (vue expéditeur).
///
/// Affiche l'état du paiement selon la méthode ([BidPaymentMethod]) et le
/// statut du bid.
///
/// — Stripe (le statut du colis prime sur celui du paiement) :
///   • COMPLETED / DELIVERED → montant libéré au voyageur (check vert)
///   • CANCELLED / REJECTED / NO_SHOW / EXPIRED / PARCEL_REFUSED → remboursé
///   • paiement [PaymentStatus.failed] → « Paiement échoué » (rouge)
///   • AWAITING_PAYMENT → montant à régler (rien n'est encore payé)
///   • sinon → séquestré, libéré à la livraison (lock)
///
/// — Mobile Money (pawaPay) : séquestré par Yadony jusqu'à la livraison,
///   comme Stripe, mais avec un badge dédié (pas de détail par statut) ;
///   « à régler » tant que le colis est en AWAITING_PAYMENT.
///
/// [existingPayment] : paiement lu par l'écran (null tant qu'il n'est pas lu
/// ou absent) ; sans lui, la carte se fonde sur le seul statut du colis.
///
/// — Cash / Wave / Orange Money : paiement en personne à la remise.
///
/// — Payé au dépôt (bateau, [PayoutTrigger.deposit]), carte ou mobile money :
///   pas de séquestre jusqu'à la livraison. Avant le dépôt, le montant payé
///   sera versé au transporteur au dépôt ; une fois déposé, il l'est, avec la
///   date du dépôt quand l'étape est lue. Un colis en espèces, annulé, à
///   régler ou dont le paiement a échoué garde son texte habituel. Sans
///   `payoutTrigger` (back antérieur), le colis vaut [PayoutTrigger.delivery].
class PaiementCard extends StatelessWidget {
  final BidModel bid;
  final PaymentModel? existingPayment;

  const PaiementCard({super.key, required this.bid, this.existingPayment});

  static const _terminalStatuses = {'COMPLETED', 'DELIVERED'};

  static const _cancelledStatuses = {
    'CANCELLED',
    'REJECTED',
    'NO_SHOW',
    'EXPIRED',
    'PARCEL_REFUSED',
  };

  static const _awaitingPaymentStatus = 'AWAITING_PAYMENT';

  /// Statuts d'un colis déposé à l'entrepôt (dépôt scanné).
  static const _depositedStatuses = {
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
    'COMPLETED',
    'DELIVERED',
  };

  /// Le transporteur est payé au dépôt du colis : carte ou mobile money (les
  /// espèces ne passent jamais par Yadony), ni annulé, ni à régler, ni en
  /// échec de paiement.
  bool get _paidAtDeposit =>
      bid.payoutTrigger == PayoutTrigger.deposit &&
      (bid.paymentMethod == BidPaymentMethod.stripe ||
          bid.paymentMethod == BidPaymentMethod.mobileMoney) &&
      !_cancelledStatuses.contains(bid.status) &&
      bid.status != _awaitingPaymentStatus &&
      existingPayment?.status != PaymentStatus.failed;

  @override
  Widget build(BuildContext context) {
    // Colis modifié : le serveur additionne les transactions.
    if (bid.moneyBreakdown != null) {
      return MoneyBreakdownCard(bid: bid, isSender: true);
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    // senderLabel : ce que paie l'expéditeur (brut séquestré/remboursé, ou net
    // en cash), supplément payé compris. On n'affiche jamais le net du
    // voyageur à l'expéditeur.
    final senderLabel = _fmt(
      bid.totalSenderAmountWithSupplementEur ??
          bid.totalSenderAmountEur ??
          bid.totalAmountEur,
      bid.currency,
    );

    Widget body;

    if (_paidAtDeposit) {
      body = _depositedStatuses.contains(bid.status)
          ? _DepositPaidRow(bid: bid, amount: senderLabel)
          : _PaymentRow(
              key: const Key('paiement-deposit-pending'),
              icon: 'package',
              color: cs.primary,
              text: l.bidDetailDepositPendingLabel(senderLabel),
            );
    } else if (bid.paymentMethod == BidPaymentMethod.stripe) {
      body = _stripeBody(context, cs, tt, senderLabel);
    } else if (bid.paymentMethod == BidPaymentMethod.mobileMoney) {
      // Mobile money (pawaPay) — séquestré par Yadony comme Stripe, mais
      // sans le détail par statut (pas de distinction libéré/remboursé).
      body = Row(
        children: [
          DonyIcon('smartphone', color: cs.primary, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              bid.status == _awaitingPaymentStatus
                  ? l.bidDetailPaymentToPayLabel(senderLabel)
                  : l.bidDetailMobileMoneySecuredLabel(senderLabel),
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          DonyBadge(label: l.bidDetailMobileMoneyBadge),
        ],
      );
    } else {
      // Cash / Wave / Orange Money — règlement en personne (net voyageur)
      body = Row(
        children: [
          DonyIcon('banknote', color: cs.warning, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.bidDetailCashAtDropoffAmountLabel(senderLabel),
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          DonyBadge(label: l.bidDetailCashBadge, type: DonyBadgeType.warning),
        ],
      );
    }

    return DetailCard(title: l.bidDetailPaymentCardTitle, child: body);
  }

  Widget _stripeBody(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    String senderLabel,
  ) {
    final status = bid.status;
    final l = context.l10n;

    if (_terminalStatuses.contains(status)) {
      // Affiché à l'expéditeur : son paiement (brut) a été libéré. On ne
      // montre jamais le net que touche le voyageur.
      return Row(
        children: [
          DonyIcon('circle-check', color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.bidDetailPaymentReleasedLabel,
              style: tt.bodySmall?.copyWith(color: cs.success),
            ),
          ),
        ],
      );
    }

    if (_cancelledStatuses.contains(status)) {
      // L'expéditeur récupère ce qu'il a payé = net + commission.
      return Row(
        children: [
          DonyIcon('refresh-cw', color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.bidDetailAmountRefundedLabel(senderLabel),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    // Colis encore en cours mais paiement refusé : on ne rassure pas à tort.
    if (existingPayment?.status == PaymentStatus.failed) {
      return Row(
        children: [
          DonyIcon('circle-alert', color: cs.error, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.bidDetailPaymentFailedLabel,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      );
    }

    // Rien n'est payé : le montant est à régler, pas séquestré.
    // Sinon — en séquestre : montant payé par l'expéditeur (net + commission).
    return Row(
      children: [
        DonyIcon('lock', color: cs.primary, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            status == _awaitingPaymentStatus
                ? l.bidDetailPaymentToPayLabel(senderLabel)
                : l.bidDetailEscrowedUntilDeliveryLabel(senderLabel),
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  static String _fmt(double? v, String currency) =>
      v != null ? formatPriceIn(v, currency) : '-';
}

/// Icône et texte d'une ligne de la carte Paiement.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final String icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon(icon, color: color, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(text, style: tt.bodySmall?.copyWith(color: cs.onSurface)),
        ),
      ],
    );
  }
}

/// Colis payé au dépôt et déposé : « 60,00 € versé au transporteur au dépôt
/// du colis, le 26 nov. ». La date est `BidModel.depositedAt` quand le back la
/// sert, sinon celle de l'étape `DEPART`, lue une fois à l'affichage de la carte ; tant qu'elle n'est pas lue (ou si la
/// lecture échoue), la phrase s'affiche sans date.
class _DepositPaidRow extends StatelessWidget {
  const _DepositPaidRow({required this.bid, required this.amount});

  final BidModel bid;
  final String amount;

  /// Heure du dépôt scanné, `null` tant que les étapes ne sont pas lues.
  static DateTime? _depositedAt(TrackingState state) {
    if (state is! TrackingEventsLoaded) return null;
    DateTime? at;
    for (final event in state.events) {
      if (event.eventType == 'DEPART') at = event.scannedAt;
    }
    return at;
  }

  Widget _row(BuildContext context, DateTime? depositedAt) {
    final l = context.l10n;
    return _PaymentRow(
      key: const Key('paiement-deposit-paid'),
      icon: 'circle-check',
      color: Theme.of(context).colorScheme.success,
      text: depositedAt == null
          ? l.bidDetailDepositPaidNoDateLabel(amount)
          : l.bidDetailDepositPaidLabel(
              amount,
              DateFormat.MMMd(l.localeName).format(depositedAt.toLocal()),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Date servie par le colis : aucune lecture des étapes nécessaire.
    final served = bid.depositedAt;
    if (served != null) return _row(context, served);
    // Lecture propre à la carte : le TrackingBloc de l'écran sert au talon.
    if (!getIt.isRegistered<TrackingBloc>()) return _row(context, null);
    return BlocProvider<TrackingBloc>(
      create: (_) =>
          getIt<TrackingBloc>()..add(TrackingEventsRequested(bid.id)),
      child: BlocBuilder<TrackingBloc, TrackingState>(
        builder: (context, state) => _row(context, _depositedAt(state)),
      ),
    );
  }
}
