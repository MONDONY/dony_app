import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';
import 'package:equatable/equatable.dart';

/// Bornes alignées sur le back (`TaxInfoRequest`, 4 à 40 caractères : lettres,
/// chiffres, espace, point, tiret, barre oblique). Le serveur reste juge : ces
/// contrôles évitent seulement un aller-retour pour une faute évidente.
const int kTaxNumberMinLength = 4;
const int kTaxNumberMaxLength = 40;
const int kVatNumberMaxLength = 40;

/// Même règle que le back (`TravelerTaxInfoService`) pour le numéro fiscal et
/// la TVA : lettres et chiffres ASCII, séparateurs (espace, point, tiret, barre
/// oblique) seulement au milieu. Le back met en majuscules avant de contrôler :
/// les minuscules passent.
final RegExp kTaxNumberPattern = RegExp(
  r'^[A-Za-z0-9](?:[A-Za-z0-9 ./-]*[A-Za-z0-9])?$',
);

/// Bornes du back (`TravelerTaxInfoService`, yadony-back #730).
const int kTaxNameMaxLength = 100;
const int kTaxStreetMaxLength = 255;
const int kTaxLine2MaxLength = 100;
const int kTaxPostalCodeMaxLength = 20;
const int kTaxCityMaxLength = 100;
const int kTaxBirthPlaceMaxLength = 120;

/// Date de naissance la plus ancienne acceptée par le back.
final DateTime kTaxOldestBirthDate = DateTime(1900);

/// NIF français : exactement 13 chiffres, espaces ignorés (règle du back).
final RegExp kFrenchTaxNumberPattern = RegExp(r'^\d{13}$');

/// Code d'erreur du back pour un numéro refusé (422).
const String kTaxInfoInvalidCode = 'tax-info-invalid';

/// Valeur reprise de la pièce vérifiée, non modifiable (422).
const String kTaxInfoReadOnlyCode = 'tax-info-read-only';

/// Champs désignés par la propriété `field` du 422.
const String kTaxFieldNumber = 'taxIdentificationNumber';
const String kTaxFieldCountry = 'taxCountry';
const String kTaxFieldVat = 'vatNumber';
const String kTaxFieldFirstName = 'firstName';
const String kTaxFieldLastName = 'lastName';
const String kTaxFieldBirthDate = 'birthDate';
const String kTaxFieldBirthPlace = 'birthPlace';
const String kTaxFieldStreet = 'address.street';
const String kTaxFieldLine2 = 'address.line2';
const String kTaxFieldPostalCode = 'address.postalCode';
const String kTaxFieldCity = 'address.city';

/// Champs dont un refus du serveur s'affiche sous le champ lui-même (sinon,
/// message global).
const Set<String> kTaxInlineFields = {
  kTaxFieldNumber,
  kTaxFieldCountry,
  kTaxFieldVat,
  kTaxFieldFirstName,
  kTaxFieldLastName,
  kTaxFieldBirthDate,
  kTaxFieldBirthPlace,
  kTaxFieldStreet,
  kTaxFieldLine2,
  kTaxFieldPostalCode,
  kTaxFieldCity,
};

/// Ce qui manque pour activer « Enregistrer », dans l'ordre de l'écran.
enum TaxInfoMissingInput {
  residence,
  name,
  birthDate,
  address,
  taxNumber,
  birthPlace,
  vat,
  taxCountry,
}

/// Chargement de l'écran.
///
/// [unavailable] : rien à demander ou fonction absente (404, 403, 401, ancien
/// back, ou voyageur non concerné) ; [failure] : réseau ou erreur serveur.
enum TaxInfoLoadStatus { loading, ready, unavailable, failure }

/// État de l'écran « Informations fiscales ».
///
/// Les valeurs saisies ([taxNumber], [vatNumber]) ne servent qu'au formulaire :
/// elles sont vidées dès l'enregistrement, l'écran n'affiche ensuite que les
/// formes masquées de la réponse. Elles ne sortent jamais vers l'analytique ni
/// les journaux.
class TaxInfoState extends Equatable {
  const TaxInfoState({
    this.load = TaxInfoLoadStatus.loading,
    this.info,
    this.editing = false,
    this.taxNumber = '',
    this.taxCountry,
    this.vatNumber = '',
    this.submitting = false,
    this.saved = false,
    this.errorCode,
    this.errorField,
    this.residenceCountry,
    this.residenceSaves = 0,
    this.firstName = '',
    this.lastName = '',
    this.birthDate,
    this.street = '',
    this.line2 = '',
    this.postalCode = '',
    this.city = '',
    this.replacingAddress = false,
    this.noTaxNumber = false,
    this.birthPlace = '',
  });

  final TaxInfoLoadStatus load;
  final TaxInfo? info;

  /// Le voyageur a déjà fourni ses informations et touche « Modifier ».
  final bool editing;
  final String taxNumber;

  /// Pays d'émission du numéro (ISO 3166-1 alpha-2).
  final String? taxCountry;
  final String vatNumber;
  final bool submitting;

  /// Enregistrement réussi : l'écran le dit puis se ferme.
  final bool saved;

  /// Dernière erreur d'envoi : `tax-info-invalid`, `network`, `unknown`.
  final String? errorCode;

  /// Champ désigné par le 422 (`taxIdentificationNumber` ou `vatNumber`), sinon
  /// nul (l'erreur se rattache alors au numéro fiscal).
  final String? errorField;

  /// Pays de résidence choisi (statut `RESIDENCE_INCONNUE`).
  final String? residenceCountry;

  /// Nombre de pays de résidence enregistrés depuis l'écran : l'écran le dit,
  /// puis se ferme ou montre ce qui manque encore.
  final int residenceSaves;

  final String firstName;
  final String lastName;

  /// Jour seul.
  final DateTime? birthDate;
  final String street;
  final String line2;
  final String postalCode;
  final String city;

  /// « Ce n'est plus mon adresse » touché : l'adresse reprise de la pièce
  /// cède la place aux champs de saisie.
  final bool replacingAddress;

  /// « Je n'ai pas de numéro fiscal » : le lieu de naissance le remplace.
  final bool noTaxNumber;
  final String birthPlace;

  // ── Contrat ───────────────────────────────────────────────────────────

  /// Le back parle le contrat de collecte ciblée (yadony-back #730).
  bool get isTargeted => info?.usesCollectionContract ?? false;

  TaxInfoCollectionStatus? get collection => info?.collectionStatus;

  bool _missing(TaxInfoField f) => isTargeted && info!.isMissing(f);

  // ── Ce que l'écran demande ────────────────────────────────────────────

  /// Pays inconnu : seul le pays est demandé.
  bool get asksResidence =>
      collection == TaxInfoCollectionStatus.residenceInconnue;

  bool get asksName =>
      !asksResidence && !editing && _missing(TaxInfoField.name);

  bool get asksBirthDate =>
      !asksResidence && !editing && _missing(TaxInfoField.birthDate);

  /// Adresse manquante, ou adresse de la pièce remplacée.
  bool get asksAddress =>
      !asksResidence &&
      !editing &&
      (_missing(TaxInfoField.address) || replacingAddress);

  /// Bloc « numéro fiscal » : toujours dans l'ancien contrat et en
  /// modification ; sinon seulement si le numéro manque.
  bool get asksTaxNumber {
    if (asksResidence) return false;
    if (!isTargeted || editing) return true;
    return info!.isMissing(TaxInfoField.taxIdentificationNumber);
  }

  /// Le voyageur peut dire qu'il n'a pas de numéro (collecte ciblée, numéro
  /// manquant, hors modification).
  bool get offersNoTaxNumber =>
      isTargeted &&
      !editing &&
      info!.isMissing(TaxInfoField.taxIdentificationNumber);

  /// Champs numéro, pays d'émission et TVA visibles.
  bool get showsTaxNumberFields =>
      asksTaxNumber && !(offersNoTaxNumber && noTaxNumber);

  /// Lieu de naissance, seulement sans numéro fiscal.
  bool get asksBirthPlace => offersNoTaxNumber && noTaxNumber;

  /// L'écran montre la fiche (forme masquée) plutôt que le formulaire.
  ///
  /// Collecte ciblée : seulement quand tout est à jour (`COMPLETE`).
  bool get showsSummary {
    if (editing) return false;
    if (isTargeted) return collection == TaxInfoCollectionStatus.complete;
    return info?.provided ?? false;
  }

  /// Au moins une valeur reprise de la pièce d'identité.
  bool get hasPrefilledFromId {
    final identity = info?.identity;
    if ((info?.readOnlyFields ?? const []).isNotEmpty) return true;
    return identity != null &&
        (identity.nameSource == TaxInfoSource.didit ||
            identity.birthDateSource == TaxInfoSource.didit ||
            identity.addressSource == TaxInfoSource.didit);
  }

  // ── Validation ────────────────────────────────────────────────────────

  /// Règle française (13 chiffres exacts) : collecte ciblée et pays
  /// d'émission France. L'ancien contrat garde la règle générale.
  bool get usesFrenchTaxNumberRule => isTargeted && taxCountry == 'FR';

  bool get isTaxNumberValid {
    final number = taxNumber.trim();
    final general =
        number.length >= kTaxNumberMinLength &&
        number.length <= kTaxNumberMaxLength &&
        kTaxNumberPattern.hasMatch(number);
    if (!general) return false;
    if (!usesFrenchTaxNumberRule) return true;
    return kFrenchTaxNumberPattern.hasMatch(number.replaceAll(' ', ''));
  }

  /// Non vide et invalide : l'erreur s'affiche dès la saisie (champ vide, aide
  /// neutre).
  bool get isTaxNumberInvalid =>
      taxNumber.trim().isNotEmpty && !isTaxNumberValid;

  /// TVA facultative : vide, ou 4 à 40 caractères de la même règle que le
  /// numéro fiscal.
  bool get isVatValid {
    final vat = vatNumber.trim();
    return vat.isEmpty ||
        (vat.length >= kTaxNumberMinLength &&
            vat.length <= kVatNumberMaxLength &&
            kTaxNumberPattern.hasMatch(vat));
  }

  bool get isVatInvalid => !isVatValid;

  static bool _bounded(String value, int max) {
    final v = value.trim();
    return v.isNotEmpty && v.length <= max;
  }

  bool get isNameValid =>
      _bounded(firstName, kTaxNameMaxLength) &&
      _bounded(lastName, kTaxNameMaxLength);

  bool get isBirthDateValid {
    final day = birthDate;
    if (day == null) return false;
    final today = DateTime.now();
    return !day.isBefore(kTaxOldestBirthDate) &&
        !day.isAfter(DateTime(today.year, today.month, today.day));
  }

  bool get isAddressValid =>
      _bounded(street, kTaxStreetMaxLength) &&
      _bounded(postalCode, kTaxPostalCodeMaxLength) &&
      _bounded(city, kTaxCityMaxLength) &&
      line2.trim().length <= kTaxLine2MaxLength;

  /// Lieu de naissance saisi, ou déjà enregistré (champ laissé vide).
  bool get isBirthPlaceValid {
    if (birthPlace.trim().isEmpty) {
      return info?.identity?.birthPlaceProvided ?? false;
    }
    return _bounded(birthPlace, kTaxBirthPlaceMaxLength);
  }

  /// Le serveur a refusé ce champ (422 `tax-info-invalid`, `field`).
  bool serverRejected(String field) =>
      errorCode == kTaxInfoInvalidCode && errorField == field;

  /// Le serveur a refusé la TVA (422 `field: vatNumber`).
  bool get serverRejectedVat => serverRejected(kTaxFieldVat);

  /// Le serveur a refusé le numéro fiscal (422, champ désigné, pays
  /// d'émission ou aucun : sans champ, l'erreur se rattache au numéro).
  bool get serverRejectedTaxNumber =>
      errorCode == kTaxInfoInvalidCode &&
      (errorField == null ||
          errorField == kTaxFieldNumber ||
          errorField == kTaxFieldCountry);

  /// Un 422 que l'écran montre sous un champ visible : pas de message global
  /// en doublon.
  bool get hasInlineError {
    if (errorCode != kTaxInfoInvalidCode) return false;
    final field = errorField;
    if (field == null) return showsTaxNumberFields;
    if (!kTaxInlineFields.contains(field)) return false;
    return switch (field) {
      kTaxFieldNumber ||
      kTaxFieldCountry ||
      kTaxFieldVat => showsTaxNumberFields,
      kTaxFieldFirstName || kTaxFieldLastName => asksName,
      kTaxFieldBirthDate => asksBirthDate,
      kTaxFieldBirthPlace => asksBirthPlace,
      _ => asksAddress,
    };
  }

  /// Premier manque qui garde « Enregistrer » grisé, dans l'ordre de l'écran,
  /// ou `null` si tout est prêt.
  TaxInfoMissingInput? get firstMissingInput {
    if (asksResidence) {
      return residenceCountry == null ? TaxInfoMissingInput.residence : null;
    }
    if (asksName && !isNameValid) return TaxInfoMissingInput.name;
    if (asksBirthDate && !isBirthDateValid) {
      return TaxInfoMissingInput.birthDate;
    }
    if (asksAddress && !isAddressValid) return TaxInfoMissingInput.address;
    if (showsTaxNumberFields) {
      if (!isTaxNumberValid) return TaxInfoMissingInput.taxNumber;
      if (isVatInvalid) return TaxInfoMissingInput.vat;
      if (taxCountry == null) return TaxInfoMissingInput.taxCountry;
    }
    if (asksBirthPlace && !isBirthPlaceValid) {
      return TaxInfoMissingInput.birthPlace;
    }
    return null;
  }

  /// Corps du `PUT` partiel (collecte ciblée) : seulement les champs
  /// demandés par l'écran.
  TaxInfoUpdate get update {
    final place = birthPlace.trim();
    return TaxInfoUpdate(
      taxIdentificationNumber: showsTaxNumberFields ? taxNumber : null,
      taxCountry: showsTaxNumberFields ? taxCountry : null,
      vatNumber: showsTaxNumberFields ? vatNumber : null,
      firstName: asksName ? firstName : null,
      lastName: asksName ? lastName : null,
      birthDate: asksBirthDate ? birthDate : null,
      birthPlace: asksBirthPlace && place.isNotEmpty ? place : null,
      address: asksAddress
          ? TaxInfoAddressInput(
              street: street,
              line2: line2,
              postalCode: postalCode,
              city: city,
            )
          : null,
    );
  }

  bool get canSubmit =>
      load == TaxInfoLoadStatus.ready &&
      !submitting &&
      firstMissingInput == null &&
      // Rien à envoyer (lieu de naissance déjà enregistré, rien d'autre) :
      // pas d'envoi vide.
      (asksResidence || !isTargeted || !update.isEmpty);

  /// Aucun `toString` de débogage ne recopie le numéro fiscal ni la TVA saisis.
  @override
  bool? get stringify => false;

  TaxInfoState copyWith({
    TaxInfoLoadStatus? load,
    TaxInfo? info,
    bool? editing,
    String? taxNumber,
    String? taxCountry,
    String? vatNumber,
    bool? submitting,
    bool? saved,
    String? errorCode,
    String? errorField,
    bool clearError = false,
    String? residenceCountry,
    int? residenceSaves,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? street,
    String? line2,
    String? postalCode,
    String? city,
    bool? replacingAddress,
    bool? noTaxNumber,
    String? birthPlace,
  }) => TaxInfoState(
    load: load ?? this.load,
    info: info ?? this.info,
    editing: editing ?? this.editing,
    taxNumber: taxNumber ?? this.taxNumber,
    taxCountry: taxCountry ?? this.taxCountry,
    vatNumber: vatNumber ?? this.vatNumber,
    submitting: submitting ?? this.submitting,
    saved: saved ?? this.saved,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    errorField: clearError ? null : (errorField ?? this.errorField),
    residenceCountry: residenceCountry ?? this.residenceCountry,
    residenceSaves: residenceSaves ?? this.residenceSaves,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    birthDate: birthDate ?? this.birthDate,
    street: street ?? this.street,
    line2: line2 ?? this.line2,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    replacingAddress: replacingAddress ?? this.replacingAddress,
    noTaxNumber: noTaxNumber ?? this.noTaxNumber,
    birthPlace: birthPlace ?? this.birthPlace,
  );

  @override
  List<Object?> get props => [
    load,
    info,
    editing,
    taxNumber,
    taxCountry,
    vatNumber,
    submitting,
    saved,
    errorCode,
    errorField,
    residenceCountry,
    residenceSaves,
    firstName,
    lastName,
    birthDate,
    street,
    line2,
    postalCode,
    city,
    replacingAddress,
    noTaxNumber,
    birthPlace,
  ];
}

/// État de la ligne ou de la bannière du Profil.
class TaxInfoPromptState extends Equatable {
  const TaxInfoPromptState({this.info, this.dismissed = false});

  /// `null` tant que rien n'a été lu, ou quand la fonction est absente.
  final TaxInfo? info;

  /// « Plus tard » touché pendant cette session.
  final bool dismissed;

  bool get _targeted => info?.usesCollectionContract ?? false;

  /// Bannière : seulement pour un voyageur concerné, sauf « Plus tard ».
  ///
  /// Collecte ciblée : résident de l'Union à qui il manque quelque chose et
  /// à qui la demande a été faite (première acceptation ou rappels). Jamais
  /// pour un pays hors périmètre ni pour le pays seul (la notification et
  /// Réglages s'en chargent).
  bool get showBanner {
    if (dismissed) return false;
    final current = info;
    if (current == null) return false;
    if (!_targeted) {
      return current.solicitation == TaxInfoSolicitation.solliciter;
    }
    return current.collectionStatus == TaxInfoCollectionStatus.infoRequired &&
        current.requestedAt != null;
  }

  /// Ligne discrète « Informations fiscales ».
  ///
  /// Ancien contrat : informations déjà fournies. Collecte ciblée : tout est
  /// à jour (relire, modifier), ou il manque quelque chose sans bannière
  /// (pas encore demandé, ou « Plus tard » touché).
  bool get showRow {
    final current = info;
    if (current == null) return false;
    if (!_targeted) {
      return current.solicitation == TaxInfoSolicitation.dejaFourni;
    }
    return switch (current.collectionStatus) {
      TaxInfoCollectionStatus.complete => true,
      TaxInfoCollectionStatus.infoRequired => !showBanner,
      _ => false,
    };
  }

  /// La ligne invite à compléter plutôt qu'à relire.
  bool get rowNeedsAction =>
      _targeted &&
      info?.collectionStatus == TaxInfoCollectionStatus.infoRequired;

  @override
  List<Object?> get props => [info, dismissed];
}
