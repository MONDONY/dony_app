import 'package:dony/core/currency/supported_currency.dart';

enum CountryZone {
  europe('Europe'),
  ameriqueDuNord('Amérique du Nord'),
  afriqueOuest('Afrique de l\'Ouest'),
  afriqueCentrale('Afrique centrale');

  const CountryZone(this.label);
  final String label;
}

class Country {
  const Country(this.code, this.name, this.currency, this.zone);

  final String code;
  final String name;
  final SupportedCurrency currency;
  final CountryZone zone;
}

/// Miroir de `CountryCatalog.java`. Les deux surfaces doivent lister exactement
/// les mêmes pays : un pays proposé ici mais absent du backend produirait un 422
/// au moment de l'enregistrement.
class CountryCatalog {
  const CountryCatalog._();

  static const all = <Country>[
    // Europe (EUR sauf Suisse et Royaume-Uni)
    Country('DE', 'Allemagne', SupportedCurrency.eur, CountryZone.europe),
    Country('AT', 'Autriche', SupportedCurrency.eur, CountryZone.europe),
    Country('BE', 'Belgique', SupportedCurrency.eur, CountryZone.europe),
    Country('CY', 'Chypre', SupportedCurrency.eur, CountryZone.europe),
    Country('HR', 'Croatie', SupportedCurrency.eur, CountryZone.europe),
    Country('ES', 'Espagne', SupportedCurrency.eur, CountryZone.europe),
    Country('EE', 'Estonie', SupportedCurrency.eur, CountryZone.europe),
    Country('FI', 'Finlande', SupportedCurrency.eur, CountryZone.europe),
    Country('FR', 'France', SupportedCurrency.eur, CountryZone.europe),
    Country('GR', 'Grèce', SupportedCurrency.eur, CountryZone.europe),
    Country('IE', 'Irlande', SupportedCurrency.eur, CountryZone.europe),
    Country('IT', 'Italie', SupportedCurrency.eur, CountryZone.europe),
    Country('LV', 'Lettonie', SupportedCurrency.eur, CountryZone.europe),
    Country('LT', 'Lituanie', SupportedCurrency.eur, CountryZone.europe),
    Country('LU', 'Luxembourg', SupportedCurrency.eur, CountryZone.europe),
    Country('MT', 'Malte', SupportedCurrency.eur, CountryZone.europe),
    Country('NL', 'Pays-Bas', SupportedCurrency.eur, CountryZone.europe),
    Country('PT', 'Portugal', SupportedCurrency.eur, CountryZone.europe),
    Country('GB', 'Royaume-Uni', SupportedCurrency.gbp, CountryZone.europe),
    Country('SK', 'Slovaquie', SupportedCurrency.eur, CountryZone.europe),
    Country('SI', 'Slovénie', SupportedCurrency.eur, CountryZone.europe),
    Country('CH', 'Suisse', SupportedCurrency.chf, CountryZone.europe),
    // Amérique du Nord
    Country('CA', 'Canada', SupportedCurrency.cad, CountryZone.ameriqueDuNord),
    Country(
      'US',
      'États-Unis',
      SupportedCurrency.usd,
      CountryZone.ameriqueDuNord,
    ),
    // Afrique de l'Ouest (XOF)
    Country('BJ', 'Bénin', SupportedCurrency.xof, CountryZone.afriqueOuest),
    Country(
      'BF',
      'Burkina Faso',
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'CI',
      'Côte d\'Ivoire',
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'GW',
      'Guinée-Bissau',
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country('ML', 'Mali', SupportedCurrency.xof, CountryZone.afriqueOuest),
    Country('NE', 'Niger', SupportedCurrency.xof, CountryZone.afriqueOuest),
    Country('SN', 'Sénégal', SupportedCurrency.xof, CountryZone.afriqueOuest),
    Country('TG', 'Togo', SupportedCurrency.xof, CountryZone.afriqueOuest),
    // Afrique centrale (XAF)
    Country(
      'CM',
      'Cameroun',
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'CF',
      'Centrafrique',
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country('CG', 'Congo', SupportedCurrency.xaf, CountryZone.afriqueCentrale),
    Country('GA', 'Gabon', SupportedCurrency.xaf, CountryZone.afriqueCentrale),
    Country(
      'GQ',
      'Guinée équatoriale',
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country('TD', 'Tchad', SupportedCurrency.xaf, CountryZone.afriqueCentrale),
  ];

  static Country? byCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    final normalized = code.trim().toUpperCase();
    for (final country in all) {
      if (country.code == normalized) {
        return country;
      }
    }
    return null;
  }

  /// Recherche insensible à la casse et aux accents : « senegal » trouve Sénégal.
  static List<Country> search(String query) {
    final needle = _fold(query);
    if (needle.isEmpty) {
      return all;
    }
    return all.where((c) => _fold(c.name).contains(needle)).toList();
  }

  static String _fold(String value) {
    const from = 'àâäçéèêëîïôöùûü';
    const to = 'aaaceeeeiioouuu';
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString();
  }
}
