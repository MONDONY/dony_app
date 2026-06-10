/// Drapeaux emoji par ville des corridors dony.
/// Retourne null pour une ville inconnue — l'appelant affiche un point bleu.
String? cityFlag(String city) {
  final key = _normalize(city);
  return _cityToFlag[key];
}

String _normalize(String city) {
  const accents = 'àâäéèêëîïôöùûüç';
  const plain = 'aaaeeeeiioouuuc';
  var s = city.trim().toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    s = s.replaceAll(accents[i], plain[i]);
  }
  return s;
}

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
