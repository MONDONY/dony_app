import 'package:dony/core/currency/supported_currency.dart';

enum CountryZone {
  europe('Europe'), // i18n-ignore
  ameriqueDuNord('Amérique du Nord'), // i18n-ignore
  afriqueOuest('Afrique de l\'Ouest'), // i18n-ignore
  afriqueCentrale('Afrique centrale'); // i18n-ignore

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

/// Une zone et les pays qu'elle contient, prêts à être affichés en section.
class CountryZoneGroup {
  const CountryZoneGroup(this.zone, this.countries);

  final CountryZone zone;
  final List<Country> countries;
}

/// Miroir de `CountryCatalog.java`. Les deux surfaces doivent lister exactement
/// les mêmes pays : un pays proposé ici mais absent du backend produirait un 422
/// au moment de l'enregistrement.
class CountryCatalog {
  const CountryCatalog._();

  static const all = <Country>[
    // Europe (EUR sauf Suisse et Royaume-Uni)
    Country(
      'DE',
      'Allemagne', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'AT',
      'Autriche', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'BE',
      'Belgique', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'CY',
      'Chypre', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'HR',
      'Croatie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'ES',
      'Espagne', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'EE',
      'Estonie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'FI',
      'Finlande', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'FR',
      'France', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'GR',
      'Grèce', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'IE',
      'Irlande', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'IT',
      'Italie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'LV',
      'Lettonie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'LT',
      'Lituanie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'LU',
      'Luxembourg', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'MT',
      'Malte', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'NL',
      'Pays-Bas', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'PT',
      'Portugal', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'GB',
      'Royaume-Uni', // i18n-ignore
      SupportedCurrency.gbp,
      CountryZone.europe,
    ),
    Country(
      'SK',
      'Slovaquie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'SI',
      'Slovénie', // i18n-ignore
      SupportedCurrency.eur,
      CountryZone.europe,
    ),
    Country(
      'CH',
      'Suisse', // i18n-ignore
      SupportedCurrency.chf,
      CountryZone.europe,
    ),
    // Amérique du Nord
    Country(
      'CA',
      'Canada', // i18n-ignore
      SupportedCurrency.cad,
      CountryZone.ameriqueDuNord,
    ),
    Country(
      'US',
      'États-Unis', // i18n-ignore
      SupportedCurrency.usd,
      CountryZone.ameriqueDuNord,
    ),
    // Afrique de l'Ouest (XOF)
    Country(
      'BJ',
      'Bénin', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'BF',
      'Burkina Faso', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'CI',
      'Côte d\'Ivoire', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'GW',
      'Guinée-Bissau', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'ML',
      'Mali', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'NE',
      'Niger', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'SN',
      'Sénégal', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    Country(
      'TG',
      'Togo', // i18n-ignore
      SupportedCurrency.xof,
      CountryZone.afriqueOuest,
    ),
    // Afrique centrale (XAF)
    Country(
      'CM',
      'Cameroun', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'CF',
      'Centrafrique', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'CG',
      'Congo', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'GA',
      'Gabon', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'GQ',
      'Guinée équatoriale', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
    Country(
      'TD',
      'Tchad', // i18n-ignore
      SupportedCurrency.xaf,
      CountryZone.afriqueCentrale,
    ),
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

  /// Résultats de [search] groupés par zone, dans l'ordre de déclaration du
  /// catalogue. Une zone sans résultat n'apparaît pas : la liste filtrée ne
  /// doit pas laisser d'en-tête orpheline.
  ///
  /// C'est cette forme, pas [search], que les deux sélecteurs de pays
  /// affichent : 38 entrées à plat sont illisibles, et la zone porte
  /// l'information utile (« ma devise dépend de ma zone »).
  static List<CountryZoneGroup> groupedSearch(String query) {
    final matches = search(query);
    final groups = <CountryZoneGroup>[];
    for (final zone in CountryZone.values) {
      final countries = matches.where((c) => c.zone == zone).toList();
      if (countries.isNotEmpty) {
        groups.add(CountryZoneGroup(zone, countries));
      }
    }
    return groups;
  }

  /// Recherche insensible à la casse et aux accents : « senegal » trouve
  /// Sénégal. [localizedName] ajoute le nom affiché dans la langue de l'app
  /// (ex. « Germany ») : un pays est trouvé par l'un ou l'autre nom.
  static List<Country> search(
    String query, {
    String Function(Country c)? localizedName,
  }) {
    final needle = _fold(query);
    if (needle.isEmpty) {
      return all;
    }
    return all.where((c) {
      if (_fold(c.name).contains(needle)) return true;
      final local = localizedName?.call(c);
      return local != null && _fold(local).contains(needle);
    }).toList();
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
