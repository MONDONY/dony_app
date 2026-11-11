import 'package:dony/features/tax_info/data/models/tax_info.dart';

/// Réponses du contrat de collecte ciblée (yadony-back #730), partagées par
/// les tests du cubit, de l'écran et du Profil.

/// Pays inconnu : seul le pays est demandé.
const kResidence = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  dac7Status: 'RESIDENCE_INCONNUE',
  collectionStatus: TaxInfoCollectionStatus.residenceInconnue,
  missingFields: [TaxInfoField.residenceCountry],
  actionRequired: true,
);

/// Côte d'Ivoire : rien à demander, jamais d'écran.
const kOutOfScope = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  residenceCountry: 'CI',
  dac7Status: 'NON_DECLARABLE',
  collectionStatus: TaxInfoCollectionStatus.nePasSolliciter,
);

/// Résidente en France, pièce Didit complète, demande faite à
/// l'acceptation : seul le numéro fiscal manque.
final kDiditIdentity = TaxInfoIdentity(
  firstName: 'Awa',
  lastName: 'Diallo',
  nameSource: TaxInfoSource.didit,
  birthDate: DateTime(1990, 4, 12),
  birthDateSource: TaxInfoSource.didit,
  address: const TaxInfoAddress(
    street: '1 rue de la République',
    postalCode: '69001',
    city: 'Lyon',
    country: 'FR',
  ),
  addressSource: TaxInfoSource.didit,
  addressReplaceable: true,
);

final kFranceDiditNifMissing = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  residenceCountry: 'FR',
  dac7Status: 'DECLARABLE',
  collectionStatus: TaxInfoCollectionStatus.infoRequired,
  missingFields: const [TaxInfoField.taxIdentificationNumber],
  readOnlyFields: const [
    TaxInfoField.name,
    TaxInfoField.birthDate,
    TaxInfoField.address,
  ],
  actionRequired: true,
  requestedAt: DateTime.utc(2026, 11, 11, 10),
  identity: kDiditIdentity,
);

/// Résident belge sans rien (pas de pièce Didit lisible), jamais sollicité.
const kAllMissing = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  residenceCountry: 'BE',
  dac7Status: 'DECLARABLE',
  collectionStatus: TaxInfoCollectionStatus.infoRequired,
  missingFields: [
    TaxInfoField.name,
    TaxInfoField.birthDate,
    TaxInfoField.address,
    TaxInfoField.taxIdentificationNumber,
  ],
  actionRequired: true,
  identity: TaxInfoIdentity(),
);

/// Identité du profil, NIF déjà fourni, adresse manquante.
final kProfileAddressMissing = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****0123',
  taxCountry: 'FR',
  residenceCountry: 'FR',
  dac7Status: 'DECLARABLE',
  collectionStatus: TaxInfoCollectionStatus.infoRequired,
  missingFields: const [TaxInfoField.address],
  actionRequired: true,
  requestedAt: DateTime.utc(2026, 11, 11),
  identity: TaxInfoIdentity(
    firstName: 'Jeanne',
    lastName: 'Martin',
    nameSource: TaxInfoSource.profile,
    birthDate: DateTime(1988, 7, 14),
    birthDateSource: TaxInfoSource.profile,
  ),
);

/// Adresse reprise de la pièce sans liste `readOnlyFields` (cas limite).
const kDiditAddressOnlySource = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  residenceCountry: 'FR',
  collectionStatus: TaxInfoCollectionStatus.infoRequired,
  missingFields: [TaxInfoField.taxIdentificationNumber],
  identity: TaxInfoIdentity(
    address: TaxInfoAddress(street: 'a', postalCode: 'b', city: 'c'),
    addressSource: TaxInfoSource.didit,
  ),
);

/// Pas de numéro fiscal, lieu de naissance déjà donné (reste INFO_REQUIRED,
/// question ouverte côté back).
final kBirthPlaceSaved = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
  residenceCountry: 'FR',
  collectionStatus: TaxInfoCollectionStatus.infoRequired,
  missingFields: const [TaxInfoField.taxIdentificationNumber],
  readOnlyFields: const [TaxInfoField.name, TaxInfoField.birthDate],
  actionRequired: true,
  requestedAt: DateTime.utc(2026, 11, 11),
  identity: TaxInfoIdentity(
    firstName: 'Awa',
    lastName: 'Diallo',
    nameSource: TaxInfoSource.didit,
    birthDate: DateTime(1990, 4, 12),
    birthDateSource: TaxInfoSource.didit,
    address: const TaxInfoAddress(
      street: '3 rue Neuve',
      postalCode: '75011',
      city: 'Paris',
      country: 'FR',
    ),
    addressSource: TaxInfoSource.profile,
    birthPlaceProvided: true,
  ),
);

/// Résident de l'Union, tout est présent.
const kComplete = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****0123',
  taxCountry: 'FR',
  residenceCountry: 'FR',
  dac7Status: 'DECLARABLE',
  collectionStatus: TaxInfoCollectionStatus.complete,
);

/// Ancien contrat (lot 3d) : sollicité.
const kLegacyAsk = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.solliciter,
  residenceCountry: 'FR',
);
