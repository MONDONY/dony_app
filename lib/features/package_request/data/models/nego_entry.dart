import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';

/// Source d'une entrée de « Discussions de prix ».
enum NegoEntryKind { request, trip }

/// Adaptateur commun aux deux négociations de l'app.
///
/// L'écran « Discussions de prix » mélange deux objets qui n'ont ni le même
/// contrat ni le même vocabulaire : un fil sur une demande d'envoi, et un fil
/// sur le prix d'un trajet. Les filtres, le tri et les compteurs ne travaillent
/// que sur cette interface, ce qui évite de les écrire deux fois, et donc de
/// les faire diverger.
sealed class NegoEntry {
  const NegoEntry();

  static NegoEntry fromRequest(NegotiationThread thread) =>
      RequestNegoEntry(thread);

  static NegoEntry fromTrip(BidNegotiationSummary summary) =>
      TripNegoEntry(summary);

  NegoEntryKind get kind;

  /// Identifiant de l'entrée dans sa propre source.
  String get id;

  /// La négociation attend encore quelque chose de quelqu'un.
  bool get isActive;

  /// C'est au viewer de jouer.
  bool get isMyTurn;

  bool get hasUnread;

  /// Dernière activité, seule base du tri de la liste fusionnée.
  DateTime get updatedAt;

  String? get counterpartyName;
  String? get departureCity;
  String? get arrivalCity;
}

class RequestNegoEntry extends NegoEntry {
  const RequestNegoEntry(this.thread);

  final NegotiationThread thread;

  @override
  NegoEntryKind get kind => NegoEntryKind.request;

  @override
  String get id => thread.id;

  @override
  bool get isActive => thread.status.isActive;

  @override
  bool get isMyTurn => thread.isMyTurn;

  @override
  bool get hasUnread => thread.hasUnread;

  @override
  DateTime get updatedAt => thread.lastActivityAt;

  /// Selon le rôle du viewer, le backend ne renseigne que l'un des deux noms.
  @override
  String? get counterpartyName => thread.travelerName ?? thread.senderName;

  @override
  String? get departureCity => thread.departureCity;

  @override
  String? get arrivalCity => thread.arrivalCity;
}

class TripNegoEntry extends NegoEntry {
  const TripNegoEntry(this.summary);

  final BidNegotiationSummary summary;

  @override
  NegoEntryKind get kind => NegoEntryKind.trip;

  @override
  String get id => summary.bidId;

  @override
  bool get isActive => !summary.isClosed;

  @override
  bool get isMyTurn => summary.myTurn;

  @override
  bool get hasUnread => summary.hasUnread;

  /// Un résumé sans date passe en fin de liste plutôt que de remonter en tête
  /// par accident.
  @override
  DateTime get updatedAt => summary.updatedAt ?? DateTime.utc(2000);

  @override
  String? get counterpartyName => summary.counterpartyName;

  @override
  String? get departureCity => summary.departureCity;

  @override
  String? get arrivalCity => summary.arrivalCity;
}
