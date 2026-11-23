/// Lecture tolérante d'un nombre de réponse JSON : un nombre (`20`, `19678`,
/// `20.5`) ou un texte décimal (`"20.00"`, espaces de bord ignorés). Tout le
/// reste (absent, booléen, texte illisible) rend `null`.
double? lenientDoubleOrNull(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}
