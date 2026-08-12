/// Discriminateur de direction d'une alerte corridor.
/// Détermine si l'alerte cible des colis (voyageur) ou des trajets (expéditeur).
enum AlertDirection {
  travelerWantsPackages,
  senderWantsTrips;

  String get wire => switch (this) {
        AlertDirection.travelerWantsPackages => 'TRAVELER_WANTS_PACKAGES',
        AlertDirection.senderWantsTrips => 'SENDER_WANTS_TRIPS',
      };

  static AlertDirection fromWire(String? value) => switch (value) {
        'SENDER_WANTS_TRIPS' => AlertDirection.senderWantsTrips,
        _ => AlertDirection.travelerWantsPackages,
      };
}
