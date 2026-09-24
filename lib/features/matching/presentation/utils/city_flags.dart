/// Drapeaux emoji par ville des corridors Yadony.
/// Retourne null pour une ville inconnue — l'appelant affiche un point bleu.
String? cityFlag(String city) {
  final key = _normalize(city);
  return _cityToFlag[key];
}

String _normalize(String city) {
  // Table de translittération technique (retire les accents pour la clé de
  // recherche `_cityToFlag`), jamais affichée à l'utilisateur.
  const accents =
      'àâäéèêëîïôöùûüç'; // i18n-ignore : table technique, non affichée
  const plain = 'aaaeeeeiioouuuc';
  var s = city.trim().toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    s = s.replaceAll(accents[i], plain[i]);
  }
  return s;
}

// i18n-ignore : clés de recherche (noms de ville normalisés, jamais affichés
// tels quels — le nom affiché vient de `departureCity`/`arrivalCity`) et
// drapeaux emoji (pictogrammes, pas des mots à traduire).
const _cityToFlag = <String, String>{
  // France
  'paris': '🇫🇷',
  'lyon': '🇫🇷',
  'marseille': '🇫🇷',
  'toulouse': '🇫🇷',
  'bordeaux': '🇫🇷',
  'lille': '🇫🇷',
  'nantes': '🇫🇷',
  'nice': '🇫🇷',
  // Sénégal
  'dakar': '🇸🇳',
  'thies': '🇸🇳',
  'saint-louis': '🇸🇳',
  // Côte d'Ivoire
  'abidjan': '🇨🇮',
  'bouake': '🇨🇮',
  'yamoussoukro': '🇨🇮',
  // Mali
  'bamako': '🇲🇱',
  // Cameroun
  'douala': '🇨🇲',
  'yaounde': '🇨🇲',
  // Diaspora élargie
  'bruxelles': '🇧🇪',
  'conakry': '🇬🇳',
  'lome': '🇹🇬',
  'cotonou': '🇧🇯',
  'kinshasa': '🇨🇩',
  'casablanca': '🇲🇦',
  'tunis': '🇹🇳',
  'alger': '🇩🇿',
};
