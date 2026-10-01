import 'package:dony/core/phone/phone_country.dart';

/// E.164 phone regex shared across the recipients feature: `+` followed by
/// 7 to 15 digits total (country code + subscriber number), first digit
/// non-zero. A 2-7 digit number isn't a reachable phone number, so both
/// call sites use this stricter form (matches `complete_details_screen`'s
/// inline validator).
final RegExp kRecipientPhoneE164 = RegExp(r'^\+[1-9]\d{6,14}$');

/// Numéro saisi ramené à la forme E.164 attendue par le serveur : espaces,
/// tirets, points et parenthèses retirés, préfixe international `00`
/// remplacé par `+`. Le résultat se valide ensuite avec [kRecipientPhoneE164].
String normalizeRecipientPhone(String raw) {
  final compact = raw.trim().replaceAll(RegExp(r'[\s\-.()]'), '');
  if (compact.startsWith('00')) {
    return '+${compact.substring(2)}';
  }
  return compact;
}

/// Email accepté par `POST /recipient-invitations` : une forme simple, le
/// serveur reste juge (422 sinon).
final RegExp kRecipientEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Numéro du destinataire mis au format international à partir du pays
/// d'arrivée du trajet ([countryCode], code ISO).
///
/// - déjà `+` : inchangé (séparateurs retirés) ;
/// - `00` : remplacé par `+` ;
/// - sinon l'indicatif du pays est ajouté, en retirant le zéro national là où
///   c'est un préfixe interurbain (France) et en le gardant ailleurs (Italie,
///   Côte d'Ivoire), selon [toE164] ;
/// - pays inconnu : saisie rendue telle quelle, que la validation refusera.
String internationalizeRecipientPhone(String raw, String? countryCode) {
  final compact = normalizeRecipientPhone(raw);
  if (compact.isEmpty || compact.startsWith('+')) return compact;
  final country = countryCode == null ? null : phoneCountryForCode(countryCode);
  if (country == null) return compact;
  return toE164(country.dialCode, compact);
}
