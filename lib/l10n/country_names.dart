import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/l10n/l10n.dart';

/// Nom affichable d'un pays du catalogue, dans la langue de [l].
///
/// `Country.name` reste le nom français de référence (miroir du backend) ; ce
/// helper est la seule source des noms affichés. Un code inconnu renvoie le
/// code lui-même plutôt que de planter.
String countryName(AppLocalizations l, String code) => switch (code) {
  'DE' => l.countryNameDe,
  'AT' => l.countryNameAt,
  'BE' => l.countryNameBe,
  'CY' => l.countryNameCy,
  'HR' => l.countryNameHr,
  'ES' => l.countryNameEs,
  'EE' => l.countryNameEe,
  'FI' => l.countryNameFi,
  'FR' => l.countryNameFr,
  'GR' => l.countryNameGr,
  'IE' => l.countryNameIe,
  'IT' => l.countryNameIt,
  'LV' => l.countryNameLv,
  'LT' => l.countryNameLt,
  'LU' => l.countryNameLu,
  'MT' => l.countryNameMt,
  'NL' => l.countryNameNl,
  'PT' => l.countryNamePt,
  'GB' => l.countryNameGb,
  'SK' => l.countryNameSk,
  'SI' => l.countryNameSi,
  'CH' => l.countryNameCh,
  'CA' => l.countryNameCa,
  'US' => l.countryNameUs,
  'BJ' => l.countryNameBj,
  'BF' => l.countryNameBf,
  'CI' => l.countryNameCi,
  'GW' => l.countryNameGw,
  'ML' => l.countryNameMl,
  'NE' => l.countryNameNe,
  'SN' => l.countryNameSn,
  'TG' => l.countryNameTg,
  'CM' => l.countryNameCm,
  'CF' => l.countryNameCf,
  'CG' => l.countryNameCg,
  'GA' => l.countryNameGa,
  'GQ' => l.countryNameGq,
  'TD' => l.countryNameTd,
  // Hors catalogue, proposé seulement par le sélecteur d'indicatif.
  'CD' => l.countryNameCd,
  _ => code,
};

/// Libellé affichable d'une zone du catalogue, dans la langue de [l].
String countryZoneLabel(AppLocalizations l, CountryZone zone) => switch (zone) {
  CountryZone.europe => l.countryZoneEurope,
  CountryZone.ameriqueDuNord => l.countryZoneNorthAmerica,
  CountryZone.afriqueOuest => l.countryZoneWestAfrica,
  CountryZone.afriqueCentrale => l.countryZoneCentralAfrica,
};
