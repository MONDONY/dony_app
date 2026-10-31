import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

// Textes et icônes des actions « À traiter » de l'écran du trajet vu par son
// voyageur (grosse carte « Prochaine action », file, sheets, pied collant) :
// une seule source, la grosse carte et le pied disent toujours la même chose.
// Les libellés existants de l'app sont repris au mot près (« Je pars »,
// « Arrivé à destination », « Confirmer ma présence »...).

/// Sous ce délai, l'échéance se lit en durée (« Expire dans 5 h ») ; au-delà,
/// en heure (« Avant 19:00 », « Avant le 14 nov. à 14:00 »).
const kTripTodoRelativeDueWindow = Duration(hours: 6);

/// Icône de l'action [kind] (`assets/icons/<nom>.svg`).
String tripTodoIcon(TripTodoKind kind) => switch (kind) {
  TripTodoKind.requests => 'inbox',
  TripTodoKind.presence => 'circle-check',
  TripTodoKind.scan => 'scan-line',
  TripTodoKind.amendment => 'pencil',
  TripTodoKind.supplement => 'credit-card',
  TripTodoKind.senderAbsence => 'user-x',
  TripTodoKind.returnParcel => 'refresh-cw',
  TripTodoKind.depart => 'plane',
  TripTodoKind.arrive => 'plane-landing',
  TripTodoKind.deliver => 'package',
  TripTodoKind.notify => 'message-circle',
  TripTodoKind.recipientDeclined => 'contact',
  TripTodoKind.instructions => 'map-pin',
  TripTodoKind.rate => 'star',
  TripTodoKind.publish => 'send',
  TripTodoKind.addCard => 'credit-card',
};

/// Destinataires à prévenir de [item] (`notify` : ses colis), sinon son
/// nombre d'actions.
int _countOf(TripTodoItem item) =>
    item.kind == TripTodoKind.notify ? item.bidIds.length : item.count;

/// Titre de l'action [item] (carte, ligne de la file, titre de son sheet).
/// [cardReady] : compte de paiement par carte prêt, qui change le geste de
/// [TripTodoKind.addCard].
String tripTodoTitle(
  AppLocalizations l,
  TripTodoItem item, {
  required bool cardReady,
}) {
  final n = _countOf(item);
  return switch (item.kind) {
    TripTodoKind.requests => l.tripTodoRequestsTitle,
    TripTodoKind.presence => l.tripTodoPresenceTitle,
    TripTodoKind.scan => l.tripTodoScanTitle(n),
    TripTodoKind.amendment => l.tripTodoAmendmentTitle(n),
    TripTodoKind.supplement => l.tripTodoSupplementTitle(n),
    TripTodoKind.senderAbsence => l.bidDetailTravelerReportNoShowButton,
    TripTodoKind.returnParcel => l.tripTodoReturnTitle(n),
    TripTodoKind.depart => l.tripDepartButton,
    TripTodoKind.arrive => l.tripOwnerMarkArrivedButton,
    TripTodoKind.deliver => l.tripTodoDeliverTitle(n),
    TripTodoKind.notify => l.tripTodoNotifyTitle(n),
    TripTodoKind.recipientDeclined => l.tripTodoRecipientDeclinedTitle(n),
    TripTodoKind.instructions => l.tripOwnerArrivalEditingTitle,
    TripTodoKind.rate => l.tripTodoRateTitle(n),
    TripTodoKind.publish => l.tripTodoPublishTitle,
    TripTodoKind.addCard =>
      cardReady
          ? l.listingEnableCardOnTripButton
          : l.listingActivateCardPaymentsButton,
  };
}

/// Ce qui est attendu, en une phrase courte, sous le titre.
String tripTodoSubtitle(
  AppLocalizations l,
  TripTodoItem item, {
  required bool cardReady,
}) {
  final n = _countOf(item);
  return switch (item.kind) {
    TripTodoKind.requests => l.tripTodoRequestsSummary(n),
    TripTodoKind.presence => l.tripTodoPresenceSubtitle(n),
    TripTodoKind.scan => l.tripTodoScanSubtitle,
    TripTodoKind.amendment => l.tripTodoAmendmentSubtitle,
    TripTodoKind.supplement => l.tripTodoSupplementSubtitle,
    TripTodoKind.senderAbsence => l.tripTodoSenderAbsenceSubtitle,
    TripTodoKind.returnParcel => l.tripTodoReturnSubtitle,
    TripTodoKind.depart => l.tripTodoDepartSummary,
    TripTodoKind.arrive => l.tripTodoArriveSubtitle,
    TripTodoKind.deliver => l.tripTodoDeliverSubtitle,
    TripTodoKind.notify => l.tripTodoNotifySubtitle,
    TripTodoKind.recipientDeclined => l.tripTodoRecipientDeclinedSubtitle,
    TripTodoKind.instructions => l.tripTodoInstructionsSubtitle,
    TripTodoKind.rate => l.tripTodoRateSubtitle,
    TripTodoKind.publish => l.tripTodoPublishSubtitle,
    TripTodoKind.addCard =>
      cardReady ? l.tripTodoCardReadySummary : l.tripTodoCardActivateSummary,
  };
}

/// Libellé du bouton de l'action [item] : bouton de la grosse carte, et
/// bouton principal du pied collant quand [item] est en tête de la file.
String tripTodoButton(
  AppLocalizations l,
  TripTodoItem item, {
  required bool cardReady,
}) {
  final n = _countOf(item);
  return switch (item.kind) {
    TripTodoKind.requests => l.listingSeeRequestsButton(n),
    TripTodoKind.presence => l.bidDetailConfirmPresence,
    TripTodoKind.scan => l.bidDetailScanParcelQr,
    TripTodoKind.amendment => l.tripTodoAmendmentButton(n),
    TripTodoKind.supplement => l.supplementCommissionConfirm,
    TripTodoKind.senderAbsence => l.tripTodoSenderAbsenceButton,
    TripTodoKind.returnParcel => l.tripTodoReturnButton,
    TripTodoKind.depart => l.tripDepartButton,
    TripTodoKind.arrive => l.tripOwnerMarkArrivedButton,
    TripTodoKind.deliver => l.bidDetailConfirmHandover,
    TripTodoKind.notify => l.notifyRecipientsButton(n),
    TripTodoKind.recipientDeclined => l.tripTodoRecipientDeclinedButton,
    TripTodoKind.instructions => l.tripTodoInstructionsButton,
    TripTodoKind.rate => l.tripTodoRateButton(n),
    TripTodoKind.publish => l.tripOwnerPublishTile,
    TripTodoKind.addCard =>
      cardReady
          ? l.listingEnableCardOnTripButton
          : l.listingActivateCardPaymentsButton,
  };
}

/// Étiquette de la grosse carte : « Urgent » ou « Prochaine action ».
String tripTodoUrgencyLabel(AppLocalizations l, TripTodoUrgency urgency) =>
    switch (urgency) {
      TripTodoUrgency.urgent => l.tripTodoUrgentLabel,
      TripTodoUrgency.important => l.tripTodoNextLabel,
    };

/// « Avant 19:00 » (même jour, dans le fuseau du trajet) ou « Avant le
/// 14 nov. à 14:00 » ; la ville est nommée quand le fuseau du trajet n'est
/// pas celui de l'appareil ([formatTripTime]).
String _before(
  AppLocalizations l,
  DateTime due,
  DateTime now,
  AnnouncementModel trip,
) {
  final wall = tripWallTime(due, trip.departureTimezone);
  final today = tripWallTime(now, trip.departureTimezone).wallClock;
  final time = formatTripTime(l, wall, city: trip.departureCity);
  final d = wall.wallClock;
  final sameDay =
      d.year == today.year && d.month == today.month && d.day == today.day;
  if (sameDay) return l.tripTodoDueBeforeTime(time);
  return l.tripTodoDueBeforeDate(DateFormat.MMMd(l.localeName).format(d), time);
}

/// Échéance courte de [due] (carte, ligne, ligne d'un colis), `null` sans
/// échéance : « Délai dépassé », « Expire dans 40 min », « Expire dans
/// 5 h » sous [kTripTodoRelativeDueWindow], sinon « Avant 19:00 » ou
/// « Avant le 14 nov. à 14:00 ».
String? tripTodoDueLabel(
  AppLocalizations l,
  DateTime? due, {
  required DateTime now,
  required AnnouncementModel trip,
}) {
  if (due == null) return null;
  final left = due.difference(now);
  if (left <= Duration.zero) return l.tripTodoDuePassed;
  if (left < const Duration(hours: 1)) {
    return l.tripTodoDueInMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
  }
  if (left < kTripTodoRelativeDueWindow) {
    return l.tripTodoDueInHours(left.inHours);
  }
  return _before(l, due, now, trip);
}

/// Ce qui arrive si le voyageur ne fait rien avant l'échéance (inventaire du
/// 31/10), pour les seules actions qui en ont une.
String? _consequence(AppLocalizations l, TripTodoKind kind) => switch (kind) {
  TripTodoKind.presence => l.tripTodoConsequencePresence,
  TripTodoKind.scan => l.tripTodoConsequenceScan,
  TripTodoKind.amendment => l.tripTodoConsequenceAmendment,
  TripTodoKind.supplement => l.tripTodoConsequenceSupplement,
  TripTodoKind.senderAbsence => l.tripTodoConsequenceSenderAbsence,
  TripTodoKind.returnParcel => l.tripTodoConsequenceReturn,
  _ => null,
};

/// Bandeau d'échéance du sheet d'une action par colis : « Avant 19:00,
/// sinon vous êtes déclaré absent. » ; « Délai dépassé. » une fois passée ;
/// `null` sans échéance ([TripTodoItem.dueAt]) ou sans conséquence connue.
String? tripTodoDueBanner(
  AppLocalizations l,
  TripTodoItem item, {
  required DateTime now,
  required AnnouncementModel trip,
}) {
  final due = item.dueAt;
  final consequence = _consequence(l, item.kind);
  if (due == null || consequence == null) return null;
  if (!due.isAfter(now)) return l.tripTodoDuePassedBanner;
  return l.tripTodoDueBanner(_before(l, due, now, trip), consequence);
}
