import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// État d'un segment de la frise de libération (maquette B, FLUTTER-HV).
enum TimelineSegment {
  /// Étape franchie (vert).
  done,

  /// Étape où en est le colis (bleu).
  current,

  /// Étape bloquée par un litige ou une vérification (orange).
  attention,

  /// Étape à venir (gris).
  todo,
}

/// Étapes de la frise, dans l'ordre : Payé → Remis → Livré → Versé.
const int kTimelineSteps = 4;

/// Avancement du colis sur la frise d'après son statut brut : 0 payé,
/// 1 remis (ou en route), 2 arrivé, 3 livré.
int _progress(String? bidStatus) => switch (bidStatus) {
  'HANDED_OVER' || 'IN_TRANSIT' => 1, // i18n-ignore : codes serveur
  'ARRIVED' => 2, // i18n-ignore : code serveur
  'COMPLETED' => 3, // i18n-ignore : code serveur
  _ => 0,
};

List<TimelineSegment> _upTo(int index, TimelineSegment at) => [
  for (var i = 0; i < kTimelineSteps; i++)
    i < index
        ? TimelineSegment.done
        : i == index
        ? at
        : TimelineSegment.todo,
];

/// Frise d'un montant, ou `null` quand elle n'a pas de sens (espèces,
/// remboursement, état inconnu) : la carte s'affiche alors en version
/// compacte.
///
/// | État | Frise |
/// |---|---|
/// | ESCROWED | Payé en cours |
/// | AWAITING_DELIVERY_CONFIRMATION | Remis (remis / en route) ou Livré (arrivé) en cours |
/// | RELEASE_SCHEDULED | Payé, Remis, Livré franchis ; Versé à venir |
/// | IN_DISPUTE, ON_HOLD | étape du colis en orange |
/// | PAYOUT_IN_PROGRESS | Versé en cours |
/// | RELEASED_RECENTLY | tout franchi |
List<TimelineSegment>? timelineFor(MoneyItemModel item) {
  switch (item.state) {
    case MoneyState.escrowed:
      return _upTo(0, TimelineSegment.current);
    case MoneyState.awaitingDeliveryConfirmation:
      return _upTo(
        _progress(item.bidStatus).clamp(1, 2),
        TimelineSegment.current,
      );
    case MoneyState.releaseScheduled:
      return _upTo(3, TimelineSegment.todo);
    case MoneyState.inDispute:
    case MoneyState.onHold:
      return _upTo(_progress(item.bidStatus), TimelineSegment.attention);
    case MoneyState.payoutInProgress:
      return _upTo(3, TimelineSegment.current);
    case MoneyState.releasedRecently:
      return List.filled(kTimelineSteps, TimelineSegment.done);
    case MoneyState.refundPending:
    case MoneyState.refundedRecently:
    case MoneyState.cash:
    case MoneyState.unknown:
      return null;
  }
}

/// Libellés des étapes, dans l'ordre de la frise.
List<String> timelineLabels(AppLocalizations l) => [
  l.moneyStepPaid,
  l.moneyStepHandedOver,
  l.moneyStepDelivered,
  l.moneyStepPaidOut,
];

/// Ton de la phrase de condition.
enum ConditionTone { neutral, positive, attention }

/// Phrase de condition ou de date de libération, et son ton.
({String text, ConditionTone tone}) conditionFor(
  MoneyItemModel item,
  AppLocalizations l,
) {
  String date(DateTime d) => DateFormat.MMMd(l.localeName).format(d);
  final traveler = item.role == MoneyRole.traveler;
  switch (item.state) {
    case MoneyState.escrowed:
    case MoneyState.awaitingDeliveryConfirmation:
      return (
        text: traveler ? l.moneyReleaseOnDelivery : l.moneySenderOnDelivery,
        tone: ConditionTone.neutral,
      );
    case MoneyState.releaseScheduled:
      final at = item.releaseAt;
      if (at == null) {
        return (
          text: traveler ? l.moneyReleaseOnDelivery : l.moneySenderOnDelivery,
          tone: ConditionTone.neutral,
        );
      }
      return (
        text: traveler
            ? l.moneyReleaseAuto(date(at))
            : l.moneySenderAuto(date(at)),
        tone: ConditionTone.positive,
      );
    case MoneyState.inDispute:
      return (
        text: traveler ? l.moneyReleaseDispute : l.moneySenderDispute,
        tone: ConditionTone.attention,
      );
    case MoneyState.onHold:
      return (
        text: traveler ? l.moneyReleaseReview : l.moneySenderReview,
        tone: ConditionTone.attention,
      );
    case MoneyState.payoutInProgress:
      return (
        text: traveler ? l.moneyReleaseProcessing : l.moneySenderProcessing,
        tone: ConditionTone.positive,
      );
    case MoneyState.releasedRecently:
      final at = item.settledAt;
      return (
        text: at == null ? l.moneyReleasedNoDate : l.moneyReleased(date(at)),
        tone: ConditionTone.positive,
      );
    case MoneyState.refundPending:
      return (
        text: traveler ? l.moneyRefundToSender : l.moneySenderRefundPending,
        tone: ConditionTone.neutral,
      );
    case MoneyState.refundedRecently:
      final at = item.settledAt;
      return (
        text: at == null
            ? l.moneySenderRefundedNoDate
            : l.moneySenderRefunded(date(at)),
        tone: ConditionTone.neutral,
      );
    case MoneyState.cash:
      final base = traveler ? l.moneyCashTraveler : l.moneyCashSender;
      final commission = switch (item.cashCommissionStatus) {
        'CHARGED' => l.moneyCashCommissionSettled, // i18n-ignore : code serveur
        'REFUNDED' => l.moneyCashCommissionRefunded, // i18n-ignore
        null => null,
        _ => l.moneyCashCommissionPending,
      };
      // La commission ne concerne que le voyageur, qui la règle à Yadony.
      return (
        text: traveler && commission != null ? '$base · $commission' : base,
        tone: ConditionTone.neutral,
      );
    case MoneyState.unknown:
      return (text: l.moneyUnknownState, tone: ConditionTone.neutral);
  }
}

/// Montant formaté dans sa devise (sans décimales inutiles).
String formatMoney(double amount, String? currency) => CurrencyFormatter.format(
  amount,
  SupportedCurrency.fromCodeOrDefault(currency),
  compact: true,
);
