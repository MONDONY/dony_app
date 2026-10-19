import 'package:equatable/equatable.dart';

/// Façon dont l'opérateur fait valider un paiement mobile money à son
/// client. Pilote le texte d'attente affiché pendant la recharge.
enum MobileMoneyValidationHint {
  /// Lien reçu par SMS à ouvrir pour confirmer (Orange Money CI).
  smsLink,

  /// Invite de saisie du code secret directement sur le téléphone.
  pinPrompt,

  /// Consigne neutre : valeur absente (back ancien) ou inconnue.
  generic;

  /// Lit la valeur du back (`SMS_LINK`, `PIN_PROMPT`, `GENERIC`). Toute
  /// autre valeur, y compris `null`, retombe sur [generic] : un back plus
  /// récent peut ajouter des valeurs sans casser l'app.
  static MobileMoneyValidationHint fromWire(String? value) {
    switch (value) {
      case 'SMS_LINK':
        return MobileMoneyValidationHint.smsLink;
      case 'PIN_PROMPT':
        return MobileMoneyValidationHint.pinPrompt;
      default:
        return MobileMoneyValidationHint.generic;
    }
  }
}

/// Un opérateur mobile money d'un pays, tel que renvoyé par
/// `GET /payments/mobile-money/countries`.
class MobileMoneyOperator extends Equatable {
  const MobileMoneyOperator({
    required this.code,
    required this.label,
    required this.brand,
    this.validationHint = MobileMoneyValidationHint.generic,
    this.minAmount,
    this.maxAmount,
  });

  /// Code pawaPay (`ORANGE_CIV`, `WAVE_SEN`...).
  final String code;

  /// Libellé lisible (« Orange Money », « Wave »).
  final String label;

  /// Marque (`ORANGE`, `WAVE`...) : pilote la pastille.
  final String brand;

  final MobileMoneyValidationHint validationHint;

  /// Montants limites de l'opérateur dans la devise du pays ; `null` quand
  /// le back n'en publie pas.
  final double? minAmount;
  final double? maxAmount;

  factory MobileMoneyOperator.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final brandWire = json['brand'] as String?;
    return MobileMoneyOperator(
      code: code,
      label: json['label'] as String? ?? code,
      brand: brandWire ?? _brandFromCode(code),
      validationHint: MobileMoneyValidationHint.fromWire(
        json['validationHint'] as String?,
      ),
      minAmount: (json['minAmount'] as num?)?.toDouble(),
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
    );
  }

  static String _brandFromCode(String code) {
    final i = code.indexOf('_');
    return (i < 0 ? code : code.substring(0, i)).toUpperCase();
  }

  @override
  List<Object?> get props => [
    code,
    label,
    brand,
    validationHint,
    minAmount,
    maxAmount,
  ];
}

/// Un pays où le mobile money est servi, avec sa devise et ses opérateurs.
class MobileMoneyCountry extends Equatable {
  const MobileMoneyCountry({
    required this.country,
    required this.currency,
    this.operators = const [],
  });

  /// Code ISO 3166-1 alpha-2 (`CI`, `SN`...).
  final String country;
  final String currency;
  final List<MobileMoneyOperator> operators;

  factory MobileMoneyCountry.fromJson(Map<String, dynamic> json) =>
      MobileMoneyCountry(
        country: json['country'] as String,
        currency: json['currency'] as String,
        operators: (json['operators'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MobileMoneyOperator.fromJson)
            .toList(),
      );

  @override
  List<Object?> get props => [country, currency, operators];
}

/// Catalogue des pays mobile money : ceux servis ([available]) et ceux
/// annoncés comme bientôt disponibles ([upcoming], codes ISO alpha-2).
class MobileMoneyCountries extends Equatable {
  const MobileMoneyCountries({
    this.available = const [],
    this.upcoming = const [],
  });

  final List<MobileMoneyCountry> available;
  final List<String> upcoming;

  factory MobileMoneyCountries.fromJson(Map<String, dynamic> json) =>
      MobileMoneyCountries(
        available: (json['available'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MobileMoneyCountry.fromJson)
            .toList(),
        upcoming: (json['upcoming'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );

  /// Pays servi pour [code] (insensible à la casse), sinon `null`.
  MobileMoneyCountry? byCode(String code) {
    final wanted = code.toUpperCase();
    for (final c in available) {
      if (c.country.toUpperCase() == wanted) return c;
    }
    return null;
  }

  /// Le pays [code] (insensible à la casse) est-il annoncé comme à venir ?
  bool isUpcoming(String code) {
    final wanted = code.toUpperCase();
    return upcoming.any((c) => c.toUpperCase() == wanted);
  }

  @override
  List<Object?> get props => [available, upcoming];
}
