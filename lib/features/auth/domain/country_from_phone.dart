import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/phone/phone_country.dart';

/// Pays de résidence proposé d'après le numéro E.164 du compte (`+221…` donne
/// `SN`), ou `null` quand le numéro est vide, inconnu ou ambigu.
///
/// L'indicatif le plus long l'emporte (`+225` plutôt qu'un hypothétique
/// `+22`). Un indicatif partagé par plusieurs pays (`+1` : Canada et
/// États-Unis) ne propose rien : deviner faux serait pire que ne rien
/// proposer. Seuls les pays du [CountryCatalog] sont rendus, le serveur
/// refuserait les autres (la RD Congo n'a qu'un indicatif de connexion).
///
/// Ce n'est qu'une proposition affichée : rien n'est écrit sans « Continuer ».
String? countryFromPhone(String? e164) {
  final number = e164?.replaceAll(RegExp(r'\s'), '') ?? '';
  if (!number.startsWith('+')) return null;

  var bestLength = 0;
  final matches = <String>[];
  for (final country in kPhoneCountries) {
    if (CountryCatalog.byCode(country.code) == null) continue;
    final dial = country.dialCode;
    if (!number.startsWith(dial) || dial.length < bestLength) continue;
    if (dial.length > bestLength) {
      bestLength = dial.length;
      matches.clear();
    }
    matches.add(country.code);
  }
  return matches.length == 1 ? matches.single : null;
}
