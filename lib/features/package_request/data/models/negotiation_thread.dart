import 'package:dony/features/package_request/data/models/negotiation_message.dart';
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
    this.paymentIntentClientSecret,
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
  final String? paymentIntentClientSecret;

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
        paymentIntentClientSecret: json['paymentIntentClientSecret'] as String?,
      );

  @override
  List<Object?> get props => [
        id, packageRequestId, travelerId, travelerAnnouncementId,
        travelerTravelDate, travelerAvailableKg,
        status, currentPriceEur, roundsCount, lastActivityAt, createdAt,
        messages, paymentIntentClientSecret,
      ];
}
