import 'package:dony/features/matching/data/models/announcement_model.dart';

/// Repère, dans la grille du voyageur, les articles qui semblent décrire le
/// colis déclaré au kilo : un téléphone déclaré « 1 kg, Téléphone &
/// électronique » alors que le voyageur facture « Téléphone » à l'article.
///
/// Les libellés de grille sont libres (saisis par le voyageur) et les
/// catégories du catalogue n'y sont reliées par rien : la correspondance se
/// fait par mots-clés, accents et casse ignorés. Faux positif sans gravité :
/// l'expéditeur répond « Mon colis n'en contient pas ».
abstract final class GridItemDeclarationMatcher {
  /// Mots-clés par catégorie du catalogue, repérée par un fragment de son
  /// libellé normalisé (les libellés canoniques sont en français).
  static const Map<String, List<String>> _categoryKeywords = {
    'telephone': [
      'telephone',
      'phone',
      'smartphone',
      'iphone',
      'samsung',
      'portable',
      'mobile',
      'ordinateur',
      'laptop',
      'macbook',
      'tablette',
      'tablet',
      'ipad',
      'console',
      'playstation',
      'television',
      'tele',
      'ecouteur',
      'airpods',
      'casque',
      'montre',
      'watch',
      'camera',
      'appareil photo',
      'electronique',
    ],
    'vetement': [
      'vetement',
      'habit',
      'tissu',
      'pagne',
      'wax',
      'bazin',
      'boubou',
      'robe',
      'chemise',
    ],
    'chaussure': ['chaussure', 'basket', 'sneaker', 'sandale', 'escarpin'],
    'cosmetique': [
      'cosmetique',
      'parfum',
      'creme',
      'maquillage',
      'karite',
      'meche',
      'perruque',
    ],
    'document': ['document', 'papier', 'dossier', 'courrier'],
    'alimentation': [
      'alimentation',
      'nourriture',
      'riz',
      'sucre',
      'farine',
      'epice',
      'conserve',
      'cafe',
    ],
    'livre': ['livre', 'manuel', 'cahier'],
    'cadeau': ['cadeau', 'jouet', 'peluche'],
    'medicament': ['medicament', 'traitement'],
  };

  /// Articles de [items] non choisis (quantité nulle dans [quantities]) qui
  /// correspondent à une catégorie de [categories] ou à un mot de
  /// [description]. Ordre de la grille conservé, [dismissed] (identifiants
  /// écartés par l'expéditeur) exclus.
  static List<AnnouncementGridItemModel> suggest({
    required List<AnnouncementGridItemModel> items,
    required Set<String> categories,
    required String description,
    required Map<String, int> quantities,
    Set<String> dismissed = const {},
  }) {
    final normalizedDescription = normalize(description);
    final keywords = <String>{
      for (final entry in _categoryKeywords.entries)
        // Groupe retenu par la catégorie choisie, ou par un de ses mots-clés
        // écrit dans la description (« iPhone 13 » sans catégorie).
        if (categories.any((c) => normalize(c).contains(entry.key)) ||
            entry.value.any((k) => _containsWord(normalizedDescription, k)))
          ...entry.value,
    };
    final descriptionWords = _words(description);
    return [
      for (final item in items)
        if ((quantities[item.id] ?? 0) == 0 &&
            !dismissed.contains(item.id) &&
            _matches(normalize(item.label), keywords, descriptionWords))
          item,
    ];
  }

  static bool _matches(
    String label,
    Set<String> keywords,
    Set<String> descriptionWords,
  ) {
    if (keywords.any((k) => _containsWord(label, k))) return true;
    // Un mot significatif du libellé (« valise », « ordinateur ») écrit dans
    // la description : « une valise de vêtements » face à « Valise 23 kg ».
    return _words(label).any(descriptionWords.contains);
  }

  /// [keyword] apparaît dans [text] comme début de mot : « telephone » dans
  /// « telephone portable », « tele » ne prend pas « hotel ».
  static bool _containsWord(String text, String keyword) =>
      RegExp('(^|[^a-z0-9])${RegExp.escape(keyword)}').hasMatch(text);

  /// Mots de 4 lettres ou plus, normalisés : « kg », « de », « 23 » ne
  /// relient rien.
  static Set<String> _words(String text) => normalize(text)
      .split(RegExp('[^a-z0-9]+'))
      .where((w) => w.length >= 4 && !RegExp(r'^\d+$').hasMatch(w))
      .map(_singular)
      .toSet();

  static String _singular(String word) =>
      word.length > 4 && (word.endsWith('s') || word.endsWith('x'))
      ? word.substring(0, word.length - 1)
      : word;

  /// Lettres accentuées (en échappements : ce ne sont pas des textes affichés).
  static const Map<String, String> _accents = {
    '\u00e0': 'a',
    '\u00e2': 'a',
    '\u00e4': 'a',
    '\u00e1': 'a',
    '\u00e7': 'c',
    '\u00e9': 'e',
    '\u00e8': 'e',
    '\u00ea': 'e',
    '\u00eb': 'e',
    '\u00ee': 'i',
    '\u00ef': 'i',
    '\u00ed': 'i',
    '\u00f4': 'o',
    '\u00f6': 'o',
    '\u00f3': 'o',
    '\u00f9': 'u',
    '\u00fb': 'u',
    '\u00fc': 'u',
    '\u00fa': 'u',
    '\u00ff': 'y',
    '\u0153': 'oe',
    '\u00e6': 'ae',
  };

  /// Minuscules sans accents.
  static String normalize(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      buffer.write(_accents[c] ?? c);
    }
    return buffer.toString();
  }
}
