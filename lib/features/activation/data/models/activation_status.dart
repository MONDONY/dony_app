import 'package:equatable/equatable.dart';

/// Ce que l'utilisateur est venu faire sur Yadony (guidage après KYC).
enum UserIntent {
  sender('SENDER'),
  traveler('TRAVELER'),
  both('BOTH');

  const UserIntent(this.wire);
  final String wire;

  static UserIntent? fromWire(String? raw) {
    for (final v in values) {
      if (v.wire == raw) return v;
    }
    return null;
  }
}

/// Où l'intention a été déclarée (INFERRED est réservée au serveur).
enum IntentSource {
  signup('SIGNUP'),
  prompt('PROMPT'),
  settings('SETTINGS');

  const IntentSource(this.wire);
  final String wire;
}

enum OpportunityKind { trips, packages, none }

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;
DateTime _toDate(Object? v) =>
    DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

class ActivationTrip extends Equatable {
  const ActivationTrip({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    this.availableKg,
    this.pricePerKg,
    this.currency,
  });

  factory ActivationTrip.fromJson(Map<String, dynamic> json) => ActivationTrip(
    id: json['id'] as String,
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    departureDate: _toDate(json['departureDate']),
    availableKg: _toDouble(json['availableKg']),
    pricePerKg: _toDouble(json['pricePerKg']),
    currency: json['currency'] as String?,
  );

  final String id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double? availableKg;
  final double? pricePerKg;
  final String? currency;

  @override
  List<Object?> get props => [
    id,
    departureCity,
    arrivalCity,
    departureDate,
    availableKg,
    pricePerKg,
    currency,
  ];
}

class ActivationPackage extends Equatable {
  const ActivationPackage({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    this.weightKg,
  });

  factory ActivationPackage.fromJson(Map<String, dynamic> json) =>
      ActivationPackage(
        id: json['id'] as String,
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        desiredDate: _toDate(json['desiredDate']),
        weightKg: _toDouble(json['weightKg']),
      );

  final String id;
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final double? weightKg;

  @override
  List<Object?> get props => [
    id,
    departureCity,
    arrivalCity,
    desiredDate,
    weightKg,
  ];
}

/// Réponse de `GET /users/me/activation`.
class ActivationStatus extends Equatable {
  const ActivationStatus({
    this.intent,
    this.destinationCountry,
    this.kycVerified = false,
    this.firstActionDone = true,
    this.kind = OpportunityKind.none,
    this.total = 0,
    this.trips = const [],
    this.packages = const [],
  });

  factory ActivationStatus.fromJson(Map<String, dynamic> json) {
    final opp = json['opportunities'] as Map<String, dynamic>? ?? const {};
    final kind = switch (opp['kind']) {
      'TRIPS' => OpportunityKind.trips,
      'PACKAGES' => OpportunityKind.packages,
      _ => OpportunityKind.none,
    };
    return ActivationStatus(
      intent: UserIntent.fromWire(json['intent'] as String?),
      destinationCountry: json['destinationCountry'] as String?,
      kycVerified: json['kycVerified'] as bool? ?? false,
      // Absent = on ne guide pas (pas de carte, pas d'écran personnalisé).
      firstActionDone: json['firstActionDone'] as bool? ?? true,
      kind: kind,
      total: (opp['total'] as num?)?.toInt() ?? 0,
      trips: [
        for (final t in (opp['trips'] as List? ?? const <Object>[]))
          ActivationTrip.fromJson(t as Map<String, dynamic>),
      ],
      packages: [
        for (final p in (opp['packages'] as List? ?? const <Object>[]))
          ActivationPackage.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  final UserIntent? intent;
  final String? destinationCountry;
  final bool kycVerified;
  final bool firstActionDone;
  final OpportunityKind kind;
  final int total;
  final List<ActivationTrip> trips;
  final List<ActivationPackage> packages;

  @override
  List<Object?> get props => [
    intent,
    destinationCountry,
    kycVerified,
    firstActionDone,
    kind,
    total,
    trips,
    packages,
  ];
}
