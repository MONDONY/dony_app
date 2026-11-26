/// Rôle de la personne vis-à-vis d'un colis (enum `ParcelRole` du back), pour
/// cibler un modal d'étape.
enum ParcelRole {
  sender('SENDER'),
  traveler('TRAVELER'),
  recipient('RECIPIENT');

  const ParcelRole(this.wire);

  final String wire;

  /// Valeur inconnue ou absente : `null` (le rôle est ignoré).
  static ParcelRole? fromWire(Object? value) {
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}
