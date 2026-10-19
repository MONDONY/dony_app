/// Derniers chiffres d'un numéro de téléphone, complet (`+2250748840856`)
/// ou masqué par le back (`+225 07 •• •• 56`) : sert à rappeler un compte
/// mobile money sans afficher le numéro (« Orange Money ••56 »). Chaîne vide
/// si le numéro ne contient aucun chiffre.
String phoneLastDigits(String phone, {int count = 2}) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length <= count
      ? digits
      : digits.substring(digits.length - count);
}
