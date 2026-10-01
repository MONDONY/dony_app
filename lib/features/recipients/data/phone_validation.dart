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
