/// Devise utilisable pour un paiement Stripe côté client.
///
/// Le backend reste la source de vérité : ce catalogue sert à parser sa
/// réponse et à formater les montants déjà résolus côté serveur.
class SupportedCurrency {
  final String code;
  final String symbol;
  final int minorUnit;
  final String locale;
  final String displayName;
  final double unitsPerEur;

  const SupportedCurrency._({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.locale,
    required this.displayName,
    required this.unitsPerEur,
  });

  static const eur = SupportedCurrency._(
    code: 'EUR',
    symbol: '€',
    minorUnit: 2,
    locale: 'fr_FR',
    displayName: 'Euro',
    unitsPerEur: 1,
  );
  static const usd = SupportedCurrency._(
    code: 'USD',
    symbol: r'$',
    minorUnit: 2,
    locale: 'en_US',
    displayName: 'Dollar américain',
    unitsPerEur: 1.08,
  );
  static const cad = SupportedCurrency._(
    code: 'CAD',
    symbol: r'CA$',
    minorUnit: 2,
    locale: 'en_CA',
    displayName: 'Dollar canadien',
    unitsPerEur: 1.47,
  );
  static const gbp = SupportedCurrency._(
    code: 'GBP',
    symbol: '£',
    minorUnit: 2,
    locale: 'en_GB',
    displayName: 'Livre sterling',
    unitsPerEur: 0.86,
  );
  static const chf = SupportedCurrency._(
    code: 'CHF',
    symbol: 'CHF',
    minorUnit: 2,
    locale: 'de_CH',
    displayName: 'Franc suisse',
    unitsPerEur: 0.95,
  );
  static const xof = SupportedCurrency._(
    code: 'XOF',
    symbol: 'F CFA',
    minorUnit: 0,
    locale: 'fr_SN',
    displayName: 'Franc CFA Ouest',
    unitsPerEur: 655.957,
  );
  static const xaf = SupportedCurrency._(
    code: 'XAF',
    symbol: 'FCFA',
    minorUnit: 0,
    locale: 'fr_CM',
    displayName: 'Franc CFA Centre',
    unitsPerEur: 655.957,
  );

  static const values = <SupportedCurrency>[eur, usd, cad, gbp, chf, xof, xaf];

  static SupportedCurrency? fromCode(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toUpperCase();
    for (final currency in values) {
      if (currency.code == normalized) {
        return currency;
      }
    }
    return null;
  }

  /// Repli EUR quand le code est absent ou hors catalogue. Politique de repli
  /// unique : ne jamais réécrire `fromCode(x) ?? eur` sur les sites d'appel.
  static SupportedCurrency fromCodeOrDefault(String? value) =>
      fromCode(value) ?? eur;

  /// Symbole d'un code ISO, repli EUR — pour les libellés courts (suffixe de
  /// champ, message de validation) où formater un montant complet n'a pas
  /// de sens.
  static String symbolOf(String? value) => fromCodeOrDefault(value).symbol;

  @override
  bool operator ==(Object other) =>
      other is SupportedCurrency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
