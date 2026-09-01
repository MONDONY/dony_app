/// Mois abrégés en français.
///
/// Table en dur plutôt que `DateFormat('d MMM', 'fr')` : ce libellé s'affiche
/// dans une liste montée par des tests widget, et `DateFormat` lève tant que
/// `initializeDateFormatting` n'a pas tourné — ce que `main()` fait, mais pas
/// un test.
const List<String> _kMoisAbreges = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Ancienneté lisible de la dernière publication d'un voyageur.
///
/// Format court volontairement : la valeur s'affiche en bout de ligne, à côté
/// du nom, et doit rester lisible sans faire passer le nom à la ligne. Au-delà
/// d'une semaine on bascule sur la date, « il y a 23 j » ne disant plus rien.
///
/// [now] n'existe que pour les tests : par défaut c'est l'heure courante.
String subscriptionRecencyLabel(DateTime publishedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(publishedAt);

  // Une date future (horloge du téléphone en retard sur le serveur) se lit
  // « à l'instant » plutôt que « il y a -3 min ».
  if (diff.isNegative || diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return '${publishedAt.day} ${_kMoisAbreges[publishedAt.month - 1]}';
}

/// Date de départ d'un trajet, en format court : « 27 sept. ».
///
/// L'année n'apparaît que si le départ ne tombe pas dans les douze mois à
/// venir : « 27 sept. » suffit pour un trajet proche, et l'année devient
/// indispensable au-delà.
String subscriptionDepartureLabel(DateTime departure, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final jour = '${departure.day} ${_kMoisAbreges[departure.month - 1]}';
  final horizon = DateTime(reference.year + 1, reference.month, reference.day);
  if (departure.isAfter(horizon)) return '$jour ${departure.year}';
  return jour;
}
