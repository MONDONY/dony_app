/// Comment une étape a été validée : QR du colis lu, ou numéro saisi.
///
/// [wire] est la valeur échangée avec le back (`scanMethod`), [name] sert
/// de propriété analytics.
enum ScanMethod {
  qr('QR'),
  manual('MANUAL');

  const ScanMethod(this.wire);

  final String wire;

  /// `null` quand la provenance est absente (ancien back, ancienne étape)
  /// ou inconnue (valeur ajoutée plus tard côté back) : jamais d'exception.
  static ScanMethod? fromWire(Object? value) {
    for (final method in values) {
      if (method.wire == value) return method;
    }
    return null;
  }
}
