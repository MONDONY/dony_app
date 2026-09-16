/// Indicatifs téléphoniques proposés à la connexion, et règle de composition
/// du format E.164 attendu par le backend.
///
/// Le zéro initial d'un numéro national n'a pas le même statut partout. En
/// France, au Royaume-Uni et en RD Congo c'est un *préfixe interurbain* que
/// l'indicatif pays remplace : `06 12 34 56 78` devient `+33612345678`.
/// Ailleurs, il fait partie du numéro et le retirer fabrique un destinataire
/// qui n'existe pas. C'est le cas de la Côte d'Ivoire depuis le passage à dix
/// chiffres de 2021, dont les numéros commencent par 01, 05, 07, 25 ou 27 :
/// le bon format est `+2250748840874`, pas `+225748840874`.
///
/// Cette information vit ici, à côté de la liste, parce que deux écrans la
/// consomment (connexion par téléphone et ajout d'un numéro depuis le profil).
/// Chacun portait sa propre copie de la liste et sa propre règle, opposée à
/// celle de l'autre.
library;

/// Un pays du sélecteur d'indicatif.
class PhoneCountry {
  const PhoneCountry({
    required this.dialCode,
    required this.flag,
    required this.name,
    required this.stripsLeadingZero,
    required this.hint,
  });

  /// Indicatif au format international, plus compris (ex. `+225`).
  final String dialCode;

  /// Drapeau affiché dans le sélecteur.
  final String flag;

  /// Nom affiché dans la liste de choix.
  final String name;

  /// Le zéro initial est-il un préfixe interurbain à retirer ?
  ///
  /// Vrai uniquement pour les plans de numérotation qui en utilisent un.
  final bool stripsLeadingZero;

  /// Exemple de saisie, affiché en filigrane dans le champ.
  final String hint;
}

/// Les pays proposés, France en tête car c'est le départ le plus fréquent.
const List<PhoneCountry> kPhoneCountries = [
  PhoneCountry(
    dialCode: '+33',
    flag: '🇫🇷',
    name: 'France',
    stripsLeadingZero: true,
    hint: '06 12 34 56 78',
  ),
  PhoneCountry(
    dialCode: '+44',
    flag: '🇬🇧',
    name: 'Royaume-Uni',
    stripsLeadingZero: true,
    hint: '07911 123456',
  ),
  PhoneCountry(
    dialCode: '+1',
    flag: '🇺🇸',
    name: 'États-Unis',
    stripsLeadingZero: false,
    hint: '201 555 0123',
  ),
  PhoneCountry(
    dialCode: '+221',
    flag: '🇸🇳',
    name: 'Sénégal',
    stripsLeadingZero: false,
    hint: '77 123 45 67',
  ),
  PhoneCountry(
    dialCode: '+225',
    flag: '🇨🇮',
    name: 'Côte d\'Ivoire',
    stripsLeadingZero: false,
    hint: '07 48 84 08 74',
  ),
  PhoneCountry(
    dialCode: '+223',
    flag: '🇲🇱',
    name: 'Mali',
    stripsLeadingZero: false,
    hint: '76 12 34 56',
  ),
  PhoneCountry(
    dialCode: '+237',
    flag: '🇨🇲',
    name: 'Cameroun',
    stripsLeadingZero: false,
    hint: '6 71 23 45 67',
  ),
  PhoneCountry(
    dialCode: '+241',
    flag: '🇬🇦',
    name: 'Gabon',
    stripsLeadingZero: false,
    hint: '06 03 12 34',
  ),
  PhoneCountry(
    dialCode: '+242',
    flag: '🇨🇬',
    name: 'Congo',
    stripsLeadingZero: false,
    hint: '06 123 45 67',
  ),
  PhoneCountry(
    dialCode: '+243',
    flag: '🇨🇩',
    name: 'RD Congo',
    stripsLeadingZero: true,
    hint: '081 234 5678',
  ),
];

/// Le pays portant cet indicatif, ou `null` s'il n'est pas dans la liste.
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
