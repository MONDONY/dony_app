import 'package:dony/core/utils/text_search.dart';

/// Repère, dans un texte libre saisi par l'expéditeur (description du colis),
/// un terme qui évoque l'envoi d'argent : espèces, chèques, cartes bancaires.
/// Les CGU (article 4) interdisent de confier de l'argent à un voyageur.
///
/// LISTE DUPLIQUÉE dans le back (`common/MoneyKeywordDetector.java`), qui
/// signale de son côté la demande à la modération : garder les deux listes et
/// les deux règles de comparaison synchronisées. Une divergence afficherait
/// l'avertissement sans signalement, ou l'inverse.
///
/// Règle (identique au back) :
/// - normalisation : minuscules, accents retirés, et tout caractère qui n'est
///   ni lettre ni chiffre (apostrophe, ponctuation, espaces) remplacé par un
///   seul espace ;
/// - mot entier : le terme est précédé du début du texte ou d'un caractère
///   qui n'est ni lettre ni chiffre, et suivi de la fin du texte ou d'un tel
///   caractère. « argentine », « argenterie », « argenté » ne déclenchent
///   donc pas « argent » ;
/// - dans un terme de plusieurs mots, un ou plusieurs espaces entre les mots.
///
/// Les singuliers « espèce » et « devise » ne sont volontairement pas dans la
/// liste (« une espèce de… », « la devise du trajet »).
abstract final class MoneyKeywordDetector {
  /// Termes recherchés, déjà normalisés (minuscules, sans accents). Donnée de
  /// recherche, jamais affichée.
  static const List<String> terms = [
    'argent',
    'especes',
    'cash',
    'billet de banque', // i18n-ignore
    'billets de banque', // i18n-ignore
    'liasse',
    'liasses',
    'devises',
    'cheque',
    'cheques',
    'carte bancaire',
    'cartes bancaires',
    'carte prepayee',
    'cartes prepayees',
    'money',
    'banknote',
    'banknotes',
    'bank note',
    'bank notes',
    'prepaid card',
    'prepaid cards',
    'bank card',
    'bank cards',
  ];

  /// Ni lettre ni chiffre (Unicode) : séparateur de mots.
  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Marques diacritiques combinantes (accent saisi en deux caractères).
  static final RegExp _combiningMarks = RegExp(r'\p{M}', unicode: true);

  /// Un seul motif pour toute la liste. Les termes les plus longs passent en
  /// premier : à position égale, « cartes bancaires » l'emporte.
  static final RegExp _pattern = () {
    final sorted = [...terms]..sort((a, b) => b.length.compareTo(a.length));
    final alternatives = sorted
        .map((t) => t.split(' ').map(RegExp.escape).join(r'\s+'))
        .join('|');
    return RegExp(
      '(?<![\\p{L}\\p{N}])(?:$alternatives)(?![\\p{L}\\p{N}])',
      unicode: true,
    );
  }();

  /// Minuscules, sans accents, séparateurs ramenés à un seul espace.
  static String normalize(String text) => normalizeSearch(
    text,
  ).replaceAll(_combiningMarks, '').replaceAll(_separators, ' ');

  /// Premier terme de [terms] trouvé dans [text] (le plus tôt dans le texte),
  /// sous sa forme normalisée, ou `null` si le texte n'en contient aucun.
  static String? firstMatch(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return _pattern.firstMatch(normalize(text))?.group(0);
  }
}
