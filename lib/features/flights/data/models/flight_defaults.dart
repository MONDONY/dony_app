import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:equatable/equatable.dart';

/// Trajet proposé d'office dans le formulaire (`GET /flights/defaults`) : la
/// dernière recherche de billets, sinon le corridor le plus récent.
class FlightDefaults extends Equatable {
  const FlightDefaults({required this.source, this.origin, this.destination});

  factory FlightDefaults.fromJson(Map<String, dynamic> json) => FlightDefaults(
    source: json['source'] as String? ?? 'none',
    origin: json['origin'] is Map<String, dynamic>
        ? FlightPlace.fromJson(json['origin'] as Map<String, dynamic>)
        : null,
    destination: json['destination'] is Map<String, dynamic>
        ? FlightPlace.fromJson(json['destination'] as Map<String, dynamic>)
        : null,
  );

  static const none = FlightDefaults(source: 'none');

  /// `search`, `corridor` ou `none`.
  final String source;
  final FlightPlace? origin;
  final FlightPlace? destination;

  @override
  List<Object?> get props => [source, origin, destination];
}
