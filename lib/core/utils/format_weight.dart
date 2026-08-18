/// Formatage d'un poids en kilogrammes pour l'affichage.
///
/// L'expression `toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)` était
/// recopiée dans chaque surface qui affiche un poids, et les copies avaient
/// déjà divergé sur le séparateur décimal : le même colis se lisait « 4.5 kg »
/// à un endroit et « 4,5 kg » à un autre.
String formatWeightKg(double kg) {
  final digits = kg.truncateToDouble() == kg ? 0 : 1;
  return '${kg.toStringAsFixed(digits).replaceFirst('.', ',')} kg';
}
