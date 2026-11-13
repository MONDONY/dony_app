/// Unité de vente d'un trajet bateau : le volume (m³, groupage en
/// conteneur) ou le kilo. Un trajet au m³ n'a aucun kilo (ni capacité ni
/// prix au kilo) ; le choix est figé côté serveur dès qu'un colis existe
/// (409 `pricing-unit-locked`).
enum BoatPriceUnit {
  m3,
  kg;

  /// Valeur figée du brouillon local (clé `boatPriceUnit`).
  String get wire => switch (this) {
    BoatPriceUnit.m3 => 'M3',
    BoatPriceUnit.kg => 'KG',
  };

  /// Valeur relue d'un brouillon ; absente ou inconnue : `null`.
  static BoatPriceUnit? fromWire(Object? wire) => switch (wire) {
    'M3' => BoatPriceUnit.m3,
    'KG' => BoatPriceUnit.kg,
    _ => null,
  };
}
