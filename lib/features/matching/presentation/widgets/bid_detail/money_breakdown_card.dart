import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte d'argent d'un colis modifié : les transactions du colis (initiale,
/// modification, supplément) additionnées, puis où va l'argent.
///
/// Tous les montants viennent de [BidModel.moneyBreakdown], calculé par le
/// serveur : l'app ne les additionne ni ne les recalcule. Expéditeur : des
/// bruts, jamais de net ni de commission. Voyageur : des nets, sauf les
/// espèces (brut remis en main propre).
class MoneyBreakdownCard extends StatelessWidget {
  const MoneyBreakdownCard({
    super.key,
    required this.bid,
    required this.isSender,
  });

  final BidModel bid;
  final bool isSender;

  /// Colis pas encore remis au voyageur : les espèces sont à récupérer avant
  /// de scanner la remise.
  bool get _beforeHandover => bid.status == 'ACCEPTED';

  @override
  Widget build(BuildContext context) {
    final breakdown = bid.moneyBreakdown;
    if (breakdown == null) return const SizedBox.shrink();
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;

    final destinations = isSender
        ? _senderDestinations(context, breakdown)
        : _travelerDestinations(context, breakdown);

    return DetailCard(
      title: isSender ? l.amendmentPaymentTitle : l.amendmentGainTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in breakdown.lines)
            _LineRow(
              icon: _iconOf(line),
              label: _labelOf(l, line),
              amount: _fmt(line.amount),
              pending: !line.isSecured,
            ),
          const _Separator(),
          _TotalRow(
            label: isSender ? l.amendmentPaymentTotal : l.amendmentGainTotal,
            amount: _fmt(breakdown.total),
            color: isSender ? cs.onSurface : cs.success,
          ),
          if (destinations.isNotEmpty) ...[const _Separator(), ...destinations],
        ],
      ),
    );
  }

  List<Widget> _senderDestinations(BuildContext context, BidMoneyBreakdown b) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // « par carte » seulement si toutes les lignes en ligne acquises le sont.
    final online = b.lines.where(
      (m) => m.isSecured && m.paymentMethod != BidPaymentMethod.cash,
    );
    final cardHeld =
        online.isNotEmpty &&
        online.every((m) => m.paymentMethod == BidPaymentMethod.stripe);
    return [
      if (b.onlineAmount > 0)
        _DestinationRow(
          icon: 'lock',
          color: cs.primary,
          label: cardHeld
              ? l.amendmentPaymentHeldByCard
              : l.amendmentPaymentHeldOnline,
          amount: _fmt(b.onlineAmount),
        ),
      if (b.cashAmount > 0)
        _DestinationRow(
          icon: 'banknote',
          color: cs.warning,
          label: l.amendmentPaymentCashToHand(
            bid.travelerName ?? l.bidDetailSenderTravelerFallback,
          ),
          amount: _fmt(b.cashAmount),
        ),
    ];
  }

  List<Widget> _travelerDestinations(
    BuildContext context,
    BidMoneyBreakdown b,
  ) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final commission = b.cashCommissionPaid;
    final senderName = bid.senderName ?? l.bidSenderFallbackName;
    return [
      if (b.onlineAmount > 0)
        _DestinationRow(
          icon: 'landmark',
          color: cs.primary,
          label: l.amendmentGainPaidOut,
          amount: _fmt(b.onlineAmount),
        ),
      if (b.cashAmount > 0) ...[
        _DestinationRow(
          icon: 'banknote',
          color: cs.warning,
          label: l.amendmentGainCashDue(
            _elides(senderName) ? 'yes' : 'no',
            senderName,
          ),
          amount: _fmt(b.cashAmount),
        ),
        if (commission != null && commission > 0)
          Padding(
            padding: const EdgeInsets.only(
              left: _iconColumn,
              bottom: DonySpacing.sm,
            ),
            child: Text(
              l.amendmentGainCommissionNote(_fmt(commission)),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        if (_beforeHandover)
          Container(
            margin: const EdgeInsets.only(top: DonySpacing.xs),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.infoLight,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('info', color: cs.info, size: 18),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.amendmentGainHandoverNote(_fmt(b.cashAmount)),
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
      ],
    ];
  }

  String _fmt(double v) => formatBreakdownAmount(v, bid.currency);

  /// « d'Aïcha » devant une voyelle ou un h, « de Moussa » sinon.
  static bool _elides(String name) => RegExp(
    '^[aeiouyh\u00e0\u00e2\u00e4\u00e9\u00e8\u00ea\u00eb\u00ee\u00ef\u00f4\u00f6\u00f9\u00fb\u00fc\u0153]',
    caseSensitive: false,
  ).hasMatch(name.trim());

  String _iconOf(MoneyLine line) => switch (line.paymentMethod) {
    BidPaymentMethod.stripe => 'credit-card',
    BidPaymentMethod.mobileMoney => 'smartphone',
    BidPaymentMethod.cash => 'banknote',
    _ => 'wallet',
  };

  String _labelOf(AppLocalizations l, MoneyLine line) {
    final method = switch (line.paymentMethod) {
      BidPaymentMethod.stripe => l.amendmentLineMethodCard,
      BidPaymentMethod.mobileMoney => l.amendmentLineMethodMobileMoney,
      BidPaymentMethod.cash => l.amendmentLineMethodCash,
      _ => l.amendmentLineMethodUnknown,
    };
    return switch (line.kind) {
      MoneyLineKind.principal =>
        isSender
            ? l.amendmentPaymentInitial(method)
            : l.amendmentGainInitial(method),
      MoneyLineKind.amendment =>
        isSender
            ? l.amendmentPaymentAmendment(method)
            : l.amendmentGainAmendment(method),
      MoneyLineKind.supplement => l.amendmentLineSupplement(method),
      MoneyLineKind.unknown => method,
    };
  }
}

/// Montant d'une carte d'argent : décimales fixes (« 61,00 € »), sans
/// compactage, pour que les colonnes restent alignées.
String formatBreakdownAmount(double v, String? currency) =>
    CurrencyFormatter.format(v, SupportedCurrency.fromCodeOrDefault(currency));

/// Largeur de la colonne d'icône (icône 20 + espace 8), pour aligner les notes.
const double _iconColumn = 28;

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.pending,
  });

  final String icon;
  final String label;
  final String amount;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = pending ? cs.onSurfaceVariant : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        children: [
          DonyIcon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(label, style: tt.bodyMedium?.copyWith(color: color)),
          ),
          if (pending) ...[
            DonyBadge(
              label: context.l10n.amendmentPaymentPendingBadge,
              type: DonyBadgeType.warning,
            ),
            const SizedBox(width: DonySpacing.sm),
          ],
          Text(
            amount,
            style: tt.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          amount,
          style: tt.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });

  final String icon;
  final Color color;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon(icon, color: color, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Text(
            amount,
            style: tt.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
    child: Divider(height: 1, color: Theme.of(context).colorScheme.outline),
  );
}
