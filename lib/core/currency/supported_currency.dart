/// Devise utilisable pour un paiement Stripe côté client.
///
/// Le backend reste la source de vérité : ce catalogue sert à parser sa
/// réponse et à formater les montants déjà résolus côté serveur.
class SupportedCurrency {
  final String code;
  final String symbol;
  final int minorUnit;
  final String locale;

  const SupportedCurrency._({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.locale,
  });

  static const eur = SupportedCurrency._(
    code: 'EUR',
    symbol: '€',
    minorUnit: 2,
    locale: 'fr_FR',
  );
  static const usd = SupportedCurrency._(
    code: 'USD',
    symbol: r'$',
    minorUnit: 2,
    locale: 'en_US',
  );
  static const cad = SupportedCurrency._(
    code: 'CAD',
    symbol: r'CA$',
    minorUnit: 2,
    locale: 'en_CA',
  );
  static const gbp = SupportedCurrency._(
    code: 'GBP',
    symbol: '£',
    minorUnit: 2,
    locale: 'en_GB',
  );
  static const chf = SupportedCurrency._(
    code: 'CHF',
    symbol: 'CHF',
    minorUnit: 2,
    locale: 'de_CH',
  );
  static const xof = SupportedCurrency._(
    code: 'XOF',
    symbol: 'F CFA',
    minorUnit: 0,
    locale: 'fr_SN',
  );
  static const xaf = SupportedCurrency._(
    code: 'XAF',
    symbol: 'FCFA',
    minorUnit: 0,
    locale: 'fr_CM',
  );

  static const values = <SupportedCurrency>[eur, usd, cad, gbp, chf, xof, xaf];

  static SupportedCurrency? fromCode(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toUpperCase();
    for (final currency in values) {
      if (currency.code == normalized) return currency;
    }
    return null;
  }

  static SupportedCurrency defaultForCountry(String? countryCode) {
    switch (countryCode?.trim().toUpperCase()) {
      case 'US':
        return usd;
      case 'CA':
        return cad;
      case 'GB':
        return gbp;
      case 'CH':
        return chf;
      case 'SN':
      case 'CI':
      case 'ML':
      case 'BF':
      case 'BJ':
      case 'TG':
      case 'NE':
      case 'GW':
        return xof;
      case 'CM':
      case 'GA':
      case 'CG':
      case 'TD':
      case 'CF':
      case 'GQ':
        return xaf;
      default:
        return eur;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SupportedCurrency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
