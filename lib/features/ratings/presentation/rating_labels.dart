import 'package:dony/l10n/l10n.dart';

/// Libellé affiché d'une note en étoiles, de 1 à 5.
///
/// Remplace la méthode `_starLabel` locale de `rating_bottom_sheet.dart`.
/// Une valeur hors de 1..5 (ne devrait pas arriver, [stars] vient d'un
/// sélecteur borné) rend une chaîne vide, comme l'ancien code.
String ratingStarLabel(AppLocalizations l, int stars) {
  return switch (stars) {
    1 => l.ratingStarVeryDisappointing,
    2 => l.ratingStarDisappointing,
    3 => l.ratingStarFair,
    4 => l.ratingStarGood,
    5 => l.ratingStarExcellent,
    _ => '',
  };
}
