import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:equatable/equatable.dart';

enum NegotiationThreadStatus {
  open('OPEN'),
  awaitingTrip('AWAITING_TRIP'),
  awaitingPayment('AWAITING_PAYMENT'),
  accepted('ACCEPTED'),
  rejected('REJECTED'),
  autoRejected('AUTO_REJECTED'),
  expired('EXPIRED');

  final String wireName;
  const NegotiationThreadStatus(this.wireName);

  static NegotiationThreadStatus fromJson(String s) =>
      NegotiationThreadStatus.values.firstWhere((e) => e.wireName == s);
}

class NegotiationThread extends Equatable {
  const NegotiationThread({
    required this.id,
    required this.packageRequestId,
    required this.travelerId,
    this.travelerAnnouncementId,
    required this.travelerTravelDate,
    required this.travelerAvailableKg,
    required this.status,
    required this.currentPriceEur,
    required this.roundsCount,
    required this.lastActivityAt,
    required this.createdAt,
    required this.messages,
    this.grossPriceEur,
    this.paymentMethod,
    this.paymentIntentClientSecret,
    // Profil voyageur — inclus par le back-end dans certains endpoints
    this.travelerName,
    this.travelerRating,
    this.travelerTripsCount,
    this.travelerPhotoUrl,
    // Infos demande embedées — pour affichage dans les listes de négos
    this.departureCity,
    this.arrivalCity,
    this.weightKg,
    // Champs calculés côté serveur (NegotiationThreadResponse v2)
    this.senderName,
    this.isMyTurn = false,
    this.canAccept = false,
    this.canCounter = false,
    this.roundsRemaining = 0,
    this.linkedTrip,
  });

  final String id;
  final String packageRequestId;
  final String travelerId;
  final String? travelerAnnouncementId;
  final DateTime travelerTravelDate;
  final double travelerAvailableKg;
  final NegotiationThreadStatus status;
  final double currentPriceEur;
  final int roundsCount;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final List<NegotiationMessage> messages;
  final double? grossPriceEur;
  final PaymentMethod? paymentMethod;
  final String? paymentIntentClientSecret;

  // Optionnels — présents quand le back-end les embed
  final String? travelerName;
  final double? travelerRating;
  final int? travelerTripsCount;
  final String? travelerPhotoUrl;
  final String? departureCity;
  final String? arrivalCity;
  final double? weightKg;

  // Champs calculés côté serveur (NegotiationThreadResponse v2)
  final String? senderName;
  final bool isMyTurn;
  final bool canAccept;
  final bool canCounter;
  final int roundsRemaining;

  // Trajet lié — inclus quand le back-end embed le résumé du trajet voyageur
  final LinkedTripSummary? linkedTrip;

  factory NegotiationThread.fromJson(Map<String, dynamic> json) => NegotiationThread(
        id: json['id'] as String,
        packageRequestId: json['packageRequestId'] as String,
        travelerId: json['travelerId'] as String,
        travelerAnnouncementId: json['travelerAnnouncementId'] as String?,
        travelerTravelDate: DateTime.parse(json['travelerTravelDate'] as String),
        travelerAvailableKg: (json['travelerAvailableKg'] as num).toDouble(),
        status: NegotiationThreadStatus.fromJson(json['status'] as String),
        currentPriceEur: (json['currentPriceEur'] as num).toDouble(),
        roundsCount: json['roundsCount'] as int,
        lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        messages: (json['messages'] as List<dynamic>?)
                ?.map((e) => NegotiationMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        grossPriceEur: (json['grossPriceEur'] as num?)?.toDouble(),
        paymentMethod: json['paymentMethod'] != null
            ? PaymentMethod.fromWire(json['paymentMethod'] as String)
            : null,
        paymentIntentClientSecret: json['paymentIntentClientSecret'] as String?,
        travelerName: json['travelerName'] as String?,
        travelerRating: (json['travelerRating'] as num?)?.toDouble(),
        travelerTripsCount: json['travelerTripsCount'] as int?,
        travelerPhotoUrl: json['travelerPhotoUrl'] as String?,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        senderName: json['senderName'] as String?,
        isMyTurn: json['isMyTurn'] as bool? ?? false,
        canAccept: json['canAccept'] as bool? ?? false,
        canCounter: json['canCounter'] as bool? ?? false,
        roundsRemaining: json['roundsRemaining'] as int? ?? 0,
        linkedTrip: json['linkedTrip'] != null
            ? LinkedTripSummary.fromJson(json['linkedTrip'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [
        id, packageRequestId, travelerId, travelerAnnouncementId,
        travelerTravelDate, travelerAvailableKg,
        status, currentPriceEur, roundsCount, lastActivityAt, createdAt,
        messages, grossPriceEur, paymentMethod, paymentIntentClientSecret,
        travelerName, travelerRating, travelerTripsCount, travelerPhotoUrl,
        departureCity, arrivalCity, weightKg, senderName,
        isMyTurn, canAccept, canCounter, roundsRemaining,
        linkedTrip,
      ];
}
