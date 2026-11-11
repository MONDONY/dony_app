/// Corps du `PUT /travelers/me/tax-info` de la collecte ciblée (yadony-back
/// #730) : tous les champs sont facultatifs, l'écran n'envoie que ce qu'il a
/// demandé ou que le voyageur a modifié.
///
/// Ne recopie jamais une valeur dans un `toString` : seuls les noms des
/// champs présents en sortent ([fieldCodes]).
class TaxInfoUpdate {
  const TaxInfoUpdate({
    this.taxIdentificationNumber,
    this.taxCountry,
    this.vatNumber,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.birthPlace,
    this.address,
  });

  /// Envoyé avec [taxCountry] (obligatoire) ; [vatNumber] absent l'efface.
  final String? taxIdentificationNumber;
  final String? taxCountry;
  final String? vatNumber;
  final String? firstName;
  final String? lastName;

  /// Jour seul, envoyé en `AAAA-MM-JJ`.
  final DateTime? birthDate;

  /// Seulement sans numéro fiscal.
  final String? birthPlace;
  final TaxInfoAddressInput? address;

  bool get isEmpty =>
      taxIdentificationNumber == null &&
      vatNumber == null &&
      firstName == null &&
      birthDate == null &&
      birthPlace == null &&
      address == null;

  /// Codes des champs envoyés (analytique), jamais leurs valeurs.
  List<String> get fieldCodes => [
    if (taxIdentificationNumber != null) 'TAX_IDENTIFICATION_NUMBER',
    if (vatNumber != null) 'VAT_NUMBER',
    if (firstName != null || lastName != null) 'NAME',
    if (birthDate != null) 'BIRTH_DATE',
    if (birthPlace != null) 'BIRTH_PLACE',
    if (address != null) 'ADDRESS',
  ];

  Map<String, dynamic> toJson() {
    final vat = vatNumber?.trim();
    final nif = taxIdentificationNumber?.trim();
    final day = birthDate;
    return {
      'taxIdentificationNumber': ?nif,
      if (nif != null && taxCountry != null) 'taxCountry': taxCountry,
      // Avec le numéro : TVA vide = absente (le back l'efface, comme l'ancien
      // contrat). Seule : envoyée telle quelle, `""` l'efface.
      if (vat != null && (nif == null || vat.isNotEmpty)) 'vatNumber': vat,
      if (firstName != null) 'firstName': firstName!.trim(),
      if (lastName != null) 'lastName': lastName!.trim(),
      if (day != null) 'birthDate': formatBirthDate(day),
      if (birthPlace != null) 'birthPlace': birthPlace!.trim(),
      if (address != null) 'address': address!.toJson(),
    };
  }

  /// `AAAA-MM-JJ`, sans heure ni fuseau.
  static String formatBirthDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  String toString() => 'TaxInfoUpdate(${fieldCodes.join(', ')})';
}

/// Adresse saisie : rue, code postal et ville obligatoires, complément
/// facultatif (vide = absent).
class TaxInfoAddressInput {
  const TaxInfoAddressInput({
    required this.street,
    required this.postalCode,
    required this.city,
    this.line2,
  });

  final String street;
  final String? line2;
  final String postalCode;
  final String city;

  Map<String, dynamic> toJson() {
    final extra = line2?.trim();
    return {
      'street': street.trim(),
      if (extra != null && extra.isNotEmpty) 'line2': extra,
      'postalCode': postalCode.trim(),
      'city': city.trim(),
    };
  }

  @override
  String toString() => 'TaxInfoAddressInput(****)';
}
