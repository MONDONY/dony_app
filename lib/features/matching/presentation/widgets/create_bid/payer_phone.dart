/// Normalise un numéro de téléphone payeur mobile money avant l'envoi au
/// backend (`BidCreateRequested.phoneNumber` /
/// `BidNegotiationProposeRequested.phoneNumber`) : ne garde que les chiffres
/// et un éventuel `+` initial — espaces, tirets, points et parenthèses sont
/// retirés. Une chaîne vide après normalisation vaut `null` (le backend
/// repliera alors sur le téléphone Firebase de l'expéditeur).
///
/// Fonction pure, aucune autre validation ici : le backend renvoie une 422
/// `mobile-money-invalid-phone` si le numéro reste invalide après cette
/// normalisation.
String? normalizePayerPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final hasLeadingPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  return hasLeadingPlus ? '+$digits' : digits;
}
