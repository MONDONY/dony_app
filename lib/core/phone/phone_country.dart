/// Indicatifs téléphoniques proposés à la connexion, et règle de composition
/// du format E.164 attendu par le backend.
///
/// ## Le zéro initial n'a pas le même statut partout
///
/// Il n'est un *préfixe interurbain* que dans les pays qui en utilisent un :
/// l'E.164 le remplace alors par l'indicatif, et `06 12 34 56 78` devient
/// `+33612345678`. Ailleurs il fait partie du numéro, et le retirer fabrique un
/// destinataire qui n'existe pas. C'est le cas de la Côte d'Ivoire depuis le
/// passage à dix chiffres de 2021, dont les numéros commencent par 01, 05, 07,
/// 25 ou 27 : le bon format est `+2250748840874`, pas `+225748840874`.
///
/// Le piège vaut aussi en Europe. L'Italie, l'Espagne, le Portugal, la Grèce et
/// les pays baltes n'ont pas de préfixe interurbain, alors que leurs voisins
/// immédiats en ont un.
///
/// ## Pourquoi la liste est dérivée du catalogue pays
///
/// Elle en comptait dix quand [CountryCatalog] en listait trente-huit. Un
/// Ivoirien installé en Belgique, en Italie ou au Portugal ne pouvait pas créer
/// de compte par téléphone, alors que son pays de résidence était proposé
/// partout ailleurs dans l'application. Les deux listes ne peuvent plus
/// diverger : un test échoue dès qu'un pays du catalogue n'a pas sa métadonnée
/// téléphonique ici.
library;

import 'package:dony/core/currency/country_catalog.dart';

/// Un pays du sélecteur d'indicatif.
class PhoneCountry {
  const PhoneCountry({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.stripsLeadingZero,
    required this.hint,
  });

  /// Code ISO à deux lettres, identifiant réel de l'entrée.
  ///
  /// C'est lui qui distingue les pays, pas l'indicatif : le Canada et les
  /// États-Unis partagent `+1`.
  final String code;

  /// Nom affiché, repris du catalogue pays pour rester cohérent partout.
  final String name;

  /// Indicatif au format international, plus compris (ex. `+225`).
  final String dialCode;

  /// Drapeau affiché dans le sélecteur.
  final String flag;

  /// Le zéro initial est-il un préfixe interurbain à retirer ?
  final bool stripsLeadingZero;

  /// Exemple de saisie, affiché en filigrane dans le champ.
  final String hint;
}

/// Métadonnée téléphonique d'un pays, indexée par code ISO.
typedef _Meta = ({String dial, String flag, bool strip, String hint});

/// Le drapeau, l'indicatif et la règle du zéro, pays par pays.
///
/// `strip: true` signifie que le pays utilise un préfixe interurbain. Ne le
/// mettre qu'après avoir vérifié le plan de numérotation : c'est la valeur qui
/// décide si le code SMS arrive ou se perd.
const Map<String, _Meta> _phoneMeta = {
  // ── Europe ──────────────────────────────────────────────────────────────
  // Préfixe interurbain 0 : Allemagne, Autriche, Belgique, Croatie, Finlande,
  // France, Irlande, Pays-Bas, Royaume-Uni, Slovaquie, Slovénie, Suisse.
  'DE': (dial: '+49', flag: '🇩🇪', strip: true, hint: '0151 23456789'),
  'AT': (dial: '+43', flag: '🇦🇹', strip: true, hint: '0664 1234567'),
  'BE': (dial: '+32', flag: '🇧🇪', strip: true, hint: '0470 12 34 56'),
  'HR': (dial: '+385', flag: '🇭🇷', strip: true, hint: '091 234 5678'),
  'FI': (dial: '+358', flag: '🇫🇮', strip: true, hint: '040 1234567'),
  'FR': (dial: '+33', flag: '🇫🇷', strip: true, hint: '06 12 34 56 78'),
  'IE': (dial: '+353', flag: '🇮🇪', strip: true, hint: '085 123 4567'),
  'NL': (dial: '+31', flag: '🇳🇱', strip: true, hint: '06 12345678'),
  'GB': (dial: '+44', flag: '🇬🇧', strip: true, hint: '07911 123456'),
  'SK': (dial: '+421', flag: '🇸🇰', strip: true, hint: '0912 123 456'),
  'SI': (dial: '+386', flag: '🇸🇮', strip: true, hint: '031 123 456'),
  'CH': (dial: '+41', flag: '🇨🇭', strip: true, hint: '078 123 45 67'),
  // Sans préfixe interurbain : le zéro éventuel appartient au numéro.
  // L'Italie est le piège le plus courant, ses fixes commencent par 0.
  'IT': (dial: '+39', flag: '🇮🇹', strip: false, hint: '312 345 6789'),
  'ES': (dial: '+34', flag: '🇪🇸', strip: false, hint: '612 34 56 78'),
  'PT': (dial: '+351', flag: '🇵🇹', strip: false, hint: '912 345 678'),
  'GR': (dial: '+30', flag: '🇬🇷', strip: false, hint: '691 234 5678'),
  'CY': (dial: '+357', flag: '🇨🇾', strip: false, hint: '96 123456'),
  'MT': (dial: '+356', flag: '🇲🇹', strip: false, hint: '9696 1234'),
  'LU': (dial: '+352', flag: '🇱🇺', strip: false, hint: '621 123 456'),
  'EE': (dial: '+372', flag: '🇪🇪', strip: false, hint: '5123 4567'),
  'LV': (dial: '+371', flag: '🇱🇻', strip: false, hint: '21 234 567'),
  // Lituanie : le préfixe interurbain est 8, pas 0. Un zéro saisi serait donc
  // un chiffre du numéro, pas un préfixe à retirer.
  'LT': (dial: '+370', flag: '🇱🇹', strip: false, hint: '612 34567'),

  // ── Amérique du Nord ────────────────────────────────────────────────────
  // Plan de numérotation nord-américain : préfixe interurbain 1, jamais 0.
  // Deux pays pour un même indicatif, d'où l'indexation par code ISO.
  'CA': (dial: '+1', flag: '🇨🇦', strip: false, hint: '514 555 0123'),
  'US': (dial: '+1', flag: '🇺🇸', strip: false, hint: '201 555 0123'),

  // ── Afrique de l'Ouest ──────────────────────────────────────────────────
  // Aucun préfixe interurbain. Là où un zéro ouvre le numéro (Côte d'Ivoire
  // depuis 2021, Bénin depuis 2020), il en fait partie.
  'CI': (dial: '+225', flag: '🇨🇮', strip: false, hint: '07 48 84 08 74'),
  'SN': (dial: '+221', flag: '🇸🇳', strip: false, hint: '77 123 45 67'),
  'ML': (dial: '+223', flag: '🇲🇱', strip: false, hint: '76 12 34 56'),
  'BJ': (dial: '+229', flag: '🇧🇯', strip: false, hint: '01 96 12 34 56'),
  'BF': (dial: '+226', flag: '🇧🇫', strip: false, hint: '70 12 34 56'),
  'NE': (dial: '+227', flag: '🇳🇪', strip: false, hint: '90 12 34 56'),
  'TG': (dial: '+228', flag: '🇹🇬', strip: false, hint: '90 12 34 56'),
  'GW': (dial: '+245', flag: '🇬🇼', strip: false, hint: '955 012 345'),

  // ── Afrique centrale ────────────────────────────────────────────────────
  'CM': (dial: '+237', flag: '🇨🇲', strip: false, hint: '6 71 23 45 67'),
  'GA': (dial: '+241', flag: '🇬🇦', strip: false, hint: '06 03 12 34'),
  'CG': (dial: '+242', flag: '🇨🇬', strip: false, hint: '06 123 45 67'),
  'TD': (dial: '+235', flag: '🇹🇩', strip: false, hint: '63 01 23 45'),
  'CF': (dial: '+236', flag: '🇨🇫', strip: false, hint: '70 01 23 45'),
  'GQ': (dial: '+240', flag: '🇬🇶', strip: false, hint: '222 123 456'),

  // ── Hors catalogue pays ─────────────────────────────────────────────────
  // La RD Congo n'est pas un pays de résidence proposé par le backend, mais
  // elle figurait dans le sélecteur d'origine. La retirer couperait la
  // connexion aux comptes déjà créés avec un numéro congolais. Elle a, seule
  // de la région, un préfixe interurbain 0.
  'CD': (dial: '+243', flag: '🇨🇩', strip: true, hint: '081 234 5678'),
};

/// Nom affiché des entrées absentes du catalogue pays.
const Map<String, String> _horsCatalogueNames = {
  'CD': 'RD Congo', // i18n-ignore
};

/// Les pays proposés, dans l'ordre du catalogue puis les exceptions.
///
/// L'ordre du catalogue groupe déjà par zone, ce que le sélecteur reprend.
final List<PhoneCountry> kPhoneCountries = [
  for (final country in CountryCatalog.all)
    if (_phoneMeta[country.code] case final m?)
      PhoneCountry(
        code: country.code,
        name: country.name,
        dialCode: m.dial,
        flag: m.flag,
        stripsLeadingZero: m.strip,
        hint: m.hint,
      ),
  for (final entry in _horsCatalogueNames.entries)
    if (_phoneMeta[entry.key] case final m?)
      PhoneCountry(
        code: entry.key,
        name: entry.value,
        dialCode: m.dial,
        flag: m.flag,
        stripsLeadingZero: m.strip,
        hint: m.hint,
      ),
];

/// Le pays par défaut du sélecteur : la France, départ le plus fréquent.
final PhoneCountry kDefaultPhoneCountry = phoneCountryForCode('FR')!;

/// Le pays portant ce code ISO, ou `null` s'il n'est pas proposé.
PhoneCountry? phoneCountryForCode(String code) {
  final normalized = code.trim().toUpperCase();
  for (final country in kPhoneCountries) {
    if (country.code == normalized) return country;
  }
  return null;
}

/// Le premier pays portant cet indicatif, ou `null`.
///
/// Plusieurs pays peuvent partager un indicatif (`+1`). Cette fonction ne sert
/// qu'à appliquer la règle du zéro, identique pour eux : pour désigner un pays,
/// utiliser [phoneCountryForCode].
PhoneCountry? phoneCountryFor(String dialCode) {
  for (final country in kPhoneCountries) {
    if (country.dialCode == dialCode) return country;
  }
  return null;
}

/// Compose le numéro E.164 envoyé au backend.
///
/// [dialCode] est l'indicatif choisi dans le sélecteur, [raw] la saisie brute
/// du champ. Les séparateurs de confort sont ignorés.
///
/// Un indicatif absent du catalogue ne retire jamais le zéro : sans règle
/// connue, transmettre la saisie entière est le seul choix qui ne fabrique pas
/// un faux numéro.
String toE164(String dialCode, String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (cleaned.isEmpty) return dialCode;

  // Saisie déjà internationale : l'utilisateur a recopié un numéro complet.
  if (cleaned.startsWith('+')) return cleaned;

  // Préfixe international composé, mais seulement s'il porte bien l'indicatif
  // choisi. Sinon « 007911... » au Royaume-Uni perdrait deux chiffres.
  final bare = dialCode.startsWith('+') ? dialCode.substring(1) : dialCode;
  if (cleaned.startsWith('00$bare')) return '+${cleaned.substring(2)}';

  var local = cleaned;
  final country = phoneCountryFor(dialCode);
  if (country != null && country.stripsLeadingZero && local.startsWith('0')) {
    local = local.substring(1);
  }
  return '$dialCode$local';
}
