import 'package:equatable/equatable.dart';

/// Résumé d'une étape d'un voyage (`GET /announcements/{id}/trip-legs`).
class TripLegSummary extends Equatable {
  const TripLegSummary({
    required this.id,
    required this.legIndex,
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    required this.departureDate,
    this.arrivalDate,
    required this.status,
  });

  factory TripLegSummary.fromJson(Map<String, dynamic> json) => TripLegSummary(
    id: json['id'] as String,
    legIndex: (json['legIndex'] as num?)?.toInt() ?? 0,
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    departureCountryCode: json['departureCountryCode'] as String?,
    arrivalCountryCode: json['arrivalCountryCode'] as String?,
    departureDate: DateTime.parse(json['departureDate'] as String),
    arrivalDate: json['arrivalDate'] != null
        ? DateTime.parse(json['arrivalDate'] as String)
        : null,
    status: json['status'] as String? ?? 'ACTIVE',
  );

  final String id;
  final int legIndex;
  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime departureDate;
  final DateTime? arrivalDate;
  final String status;

  /// Étape encore annulable par le voyageur.
  bool get isOpen => status != 'CANCELLED' && status != 'COMPLETED';

  @override
  List<Object?> get props => [id, legIndex, status, departureDate];
}

/// Étapes du voyage d'une annonce. [legs] est vide pour un trajet isolé.
class TripLegsInfo extends Equatable {
  const TripLegsInfo({
    this.tripGroupId,
    this.legCount = 0,
    this.legs = const [],
  });

  factory TripLegsInfo.fromJson(Map<String, dynamic> json) => TripLegsInfo(
    tripGroupId: json['tripGroupId'] as String?,
    legCount: (json['legCount'] as num?)?.toInt() ?? 0,
    legs: ((json['legs'] as List?) ?? const [])
        .map((e) => TripLegSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const none = TripLegsInfo();

  final String? tripGroupId;

  /// Nombre total d'étapes du voyage, même celles cachées au lecteur.
  final int legCount;
  final List<TripLegSummary> legs;

  bool get isTrip => tripGroupId != null && legs.isNotEmpty;

  /// Étape d'identifiant [id] dans la liste, ou `null`.
  TripLegSummary? legOf(String id) {
    for (final l in legs) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Étapes qui suivent celle d'identifiant [id] et restent annulables.
  List<TripLegSummary> openLegsAfter(String id) {
    final current = legOf(id);
    if (current == null) return const [];
    return legs
        .where((l) => l.legIndex > current.legIndex && l.isOpen)
        .toList();
  }

  @override
  List<Object?> get props => [tripGroupId, legCount, legs];
}
