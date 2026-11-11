import 'package:equatable/equatable.dart';

/// Faut-il demander ses informations fiscales à ce voyageur ? Miroir de
/// `solicitation` côté back (`TaxInfoResponse`, lot 3a DAC7).
///
/// Seul [solliciter] ouvre une bannière. Une valeur inconnue ou absente (back
/// plus récent) tombe sur [nePasSolliciter] : dans le doute, on ne demande rien.
enum TaxInfoSolicitation {
  solliciter('SOLLICITER'),
  dejaFourni('DEJA_FOURNI'),
  nePasSolliciter('NE_PAS_SOLLICITER');

  const TaxInfoSolicitation(this.wire);

  final String wire;

  static TaxInfoSolicitation fromWire(String? value) =>
      TaxInfoSolicitation.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => TaxInfoSolicitation.nePasSolliciter,
      );
}

/// Statut de collecte ciblée (yadony-back #730) : ce que l'écran doit
/// demander. Absent d'un back plus ancien ou DAC7 éteint : `null`, l'écran
/// garde l'ancien comportement (lot 3d, piloté par [TaxInfoSolicitation]).
enum TaxInfoCollectionStatus {
  /// Pays connu hors périmètre (Côte d'Ivoire, Sénégal…) : rien à demander,
  /// l'écran n'est jamais proposé.
  nePasSolliciter('NE_PAS_SOLLICITER'),

  /// Pays de résidence inconnu : on ne demande que le pays.
  residenceInconnue('RESIDENCE_INCONNUE'),

  /// Résident de l'Union, informations incomplètes : seulement les champs
  /// manquants.
  infoRequired('INFO_REQUIRED'),

  /// Résident de l'Union, tout est présent : rien à demander.
  complete('COMPLETE');

  const TaxInfoCollectionStatus(this.wire);

  final String wire;

  /// Valeur absente ou inconnue (statut ajouté plus tard côté back) : `null`,
  /// donc l'ancien comportement, plutôt qu'une supposition.
  static TaxInfoCollectionStatus? fromWire(Object? value) {
    for (final s in TaxInfoCollectionStatus.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Champ d'une collecte ciblée (`missingFields`, `readOnlyFields`), dans
/// l'ordre d'affichage du back.
enum TaxInfoField {
  residenceCountry('RESIDENCE_COUNTRY'),
  name('NAME'),
  birthDate('BIRTH_DATE'),
  address('ADDRESS'),
  taxIdentificationNumber('TAX_IDENTIFICATION_NUMBER'),

  /// Identité d'entreprise d'un professionnel : non saisissable dans l'app,
  /// l'équipe Yadony reprend contact.
  businessIdentity('BUSINESS_IDENTITY'),

  /// Identité à revoir par l'équipe : non saisissable dans l'app.
  identityReview('IDENTITY_REVIEW');

  const TaxInfoField(this.wire);

  final String wire;

  /// Le voyageur peut-il le renseigner lui-même dans l'écran ?
  bool get enterable =>
      this != TaxInfoField.businessIdentity &&
      this != TaxInfoField.identityReview;

  static TaxInfoField? fromWire(Object? value) {
    for (final f in TaxInfoField.values) {
      if (f.wire == value) return f;
    }
    return null;
  }

  /// Liste du back, valeurs inconnues ignorées, sans doublon, ordre gardé.
  static List<TaxInfoField> listFromJson(Object? value) {
    if (value is! List) return const [];
    final out = <TaxInfoField>[];
    for (final raw in value) {
      final field = fromWire(raw);
      if (field != null && !out.contains(field)) out.add(field);
    }
    return List.unmodifiable(out);
  }
}

/// Origine d'une valeur d'identité : la pièce vérifiée (lecture seule) ou le
/// profil.
enum TaxInfoSource {
  didit('DIDIT'),
  profile('PROFILE');

  const TaxInfoSource(this.wire);

  final String wire;

  static TaxInfoSource? fromWire(Object? value) {
    for (final s in TaxInfoSource.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Adresse principale (`identity.address`) ; `country` = pays de résidence.
class TaxInfoAddress extends Equatable {
  const TaxInfoAddress({
    required this.street,
    required this.postalCode,
    required this.city,
    this.line2,
    this.country,
  });

  static TaxInfoAddress? fromJson(Object? json) {
    if (json is! Map) return null;
    final street = TaxInfo._text(json['street']);
    final postalCode = TaxInfo._text(json['postalCode']);
    final city = TaxInfo._text(json['city']);
    if (street == null && postalCode == null && city == null) return null;
    return TaxInfoAddress(
      street: street ?? '',
      line2: TaxInfo._text(json['line2']),
      postalCode: postalCode ?? '',
      city: city ?? '',
      country: TaxInfo._text(json['country']),
    );
  }

  final String street;
  final String? line2;
  final String postalCode;
  final String city;
  final String? country;

  /// Ne recopie jamais l'adresse dans un journal.
  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [street, line2, postalCode, city, country];
}

/// Identité connue d'un particulier résident de l'Union (`identity`), avec
/// l'origine de chaque valeur. Le lieu de naissance n'est jamais renvoyé en
/// clair ([birthPlaceProvided] seulement).
class TaxInfoIdentity extends Equatable {
  const TaxInfoIdentity({
    this.firstName,
    this.lastName,
    this.nameSource,
    this.birthDate,
    this.birthDateSource,
    this.address,
    this.addressSource,
    this.addressReplaceable = false,
    this.birthPlaceProvided = false,
    this.identityCheckUnavailable = false,
  });

  static TaxInfoIdentity? fromJson(Object? json) {
    if (json is! Map) return null;
    final birth = TaxInfo._text(json['birthDate']);
    return TaxInfoIdentity(
      firstName: TaxInfo._text(json['firstName']),
      lastName: TaxInfo._text(json['lastName']),
      nameSource: TaxInfoSource.fromWire(json['nameSource']),
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      birthDateSource: TaxInfoSource.fromWire(json['birthDateSource']),
      address: TaxInfoAddress.fromJson(json['address']),
      addressSource: TaxInfoSource.fromWire(json['addressSource']),
      addressReplaceable: json['addressReplaceable'] == true,
      birthPlaceProvided: json['birthPlaceProvided'] == true,
      identityCheckUnavailable: json['identityCheckUnavailable'] == true,
    );
  }

  final String? firstName;
  final String? lastName;
  final TaxInfoSource? nameSource;

  /// Jour seul (`AAAA-MM-JJ`).
  final DateTime? birthDate;
  final TaxInfoSource? birthDateSource;
  final TaxInfoAddress? address;
  final TaxInfoSource? addressSource;

  /// L'adresse vient de la pièce : lien « Ce n'est plus mon adresse ».
  final bool addressReplaceable;
  final bool birthPlaceProvided;

  /// Vérification d'identité injoignable : seules les valeurs du profil sont
  /// montrées.
  final bool identityCheckUnavailable;

  /// Nom et prénom réunis, ou `null` si l'un manque.
  String? get fullName {
    final first = firstName;
    final last = lastName;
    if (first == null || last == null) return null;
    return '$first $last';
  }

  /// Aucune donnée d'identité dans un `toString` de débogage.
  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    nameSource,
    birthDate,
    birthDateSource,
    address,
    addressSource,
    addressReplaceable,
    birthPlaceProvided,
    identityCheckUnavailable,
  ];
}

/// Réponse de `GET` et `PUT /travelers/me/tax-info`.
///
/// Le numéro fiscal et la TVA ne reviennent jamais en clair : seules leurs
/// formes masquées (« ****1234 ») sont affichables.
///
/// Les champs de la collecte ciblée ([collectionStatus], [missingFields],
/// [readOnlyFields], [actionRequired], [requestedAt], [identity]) sont tous
/// facultatifs : un back antérieur à yadony-back #730 ne les envoie pas, et
/// [usesCollectionContract] vaut alors `false`.
class TaxInfo extends Equatable {
  const TaxInfo({
    required this.provided,
    required this.solicitation,
    this.maskedTaxIdentificationNumber,
    this.taxCountry,
    this.vatNumberProvided = false,
    this.maskedVatNumber,
    this.providedAt,
    this.residenceCountry,
    this.dac7Status,
    this.collectionStatus,
    this.missingFields = const [],
    this.readOnlyFields = const [],
    this.actionRequired = false,
    this.requestedAt,
    this.identity,
    this.residenceCountryChoices = const [],
  });

  factory TaxInfo.fromJson(Map<String, dynamic> json) => TaxInfo(
    provided: json['provided'] == true,
    maskedTaxIdentificationNumber: _text(json['maskedTaxIdentificationNumber']),
    taxCountry: _text(json['taxCountry']),
    vatNumberProvided: json['vatNumberProvided'] == true,
    maskedVatNumber: _text(json['maskedVatNumber']),
    providedAt: DateTime.tryParse(json['providedAt'] as String? ?? ''),
    residenceCountry: _text(json['residenceCountry']),
    dac7Status: _text(json['dac7Status']),
    solicitation: TaxInfoSolicitation.fromWire(json['solicitation'] as String?),
    collectionStatus: TaxInfoCollectionStatus.fromWire(
      json['collectionStatus'],
    ),
    missingFields: TaxInfoField.listFromJson(json['missingFields']),
    readOnlyFields: TaxInfoField.listFromJson(json['readOnlyFields']),
    actionRequired: json['actionRequired'] == true,
    requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
    identity: TaxInfoIdentity.fromJson(json['identity']),
    residenceCountryChoices: _codes(json['residenceCountryChoices']),
  );

  final bool provided;
  final String? maskedTaxIdentificationNumber;

  /// Pays d'émission du numéro (ISO 3166-1 alpha-2).
  final String? taxCountry;
  final bool vatNumberProvided;
  final String? maskedVatNumber;
  final DateTime? providedAt;
  final String? residenceCountry;

  /// `DECLARABLE`, `NON_DECLARABLE` ou `RESIDENCE_INCONNUE` ; non interprété
  /// par l'app, l'écran ne s'en sert pas.
  final String? dac7Status;
  final TaxInfoSolicitation solicitation;

  /// `null` : ancien back, ou statut inconnu (ancien comportement).
  final TaxInfoCollectionStatus? collectionStatus;

  /// Champs à demander, dans l'ordre d'affichage.
  final List<TaxInfoField> missingFields;

  /// Champs repris de la pièce vérifiée, non modifiables (l'adresse reste
  /// remplaçable, voir [TaxInfoIdentity.addressReplaceable]).
  final List<TaxInfoField> readOnlyFields;

  /// Invite non bloquante : quelque chose manque.
  final bool actionRequired;

  /// Première demande (acceptation ou rappels).
  final DateTime? requestedAt;
  final TaxInfoIdentity? identity;

  /// Pays proposés pour la résidence (codes ISO triés), seulement pour
  /// `RESIDENCE_INCONNUE`. Inclut des pays de l'Union absents du catalogue
  /// des devises (BG, CZ, DK, HU, PL, RO, SE).
  final List<String> residenceCountryChoices;

  /// Le back parle le contrat de collecte ciblée.
  bool get usesCollectionContract => collectionStatus != null;

  bool isMissing(TaxInfoField field) => missingFields.contains(field);

  /// Il manque quelque chose que seule l'équipe peut compléter.
  bool get needsTeamFollowUp => missingFields.any((f) => !f.enterable);

  /// Professionnel (identité d'entreprise attendue) : pas de lieu de
  /// naissance à la place du numéro.
  bool get isBusiness => isMissing(TaxInfoField.businessIdentity);

  static List<String> _codes(Object? value) {
    if (value is! List) return const [];
    final out = <String>[];
    for (final raw in value) {
      if (raw is! String) continue;
      final code = raw.trim().toUpperCase();
      if (code.length == 2 && !out.contains(code)) out.add(code);
    }
    return List.unmodifiable(out);
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    provided,
    maskedTaxIdentificationNumber,
    taxCountry,
    vatNumberProvided,
    maskedVatNumber,
    providedAt,
    residenceCountry,
    dac7Status,
    solicitation,
    collectionStatus,
    missingFields,
    readOnlyFields,
    actionRequired,
    requestedAt,
    identity,
    residenceCountryChoices,
  ];
}
