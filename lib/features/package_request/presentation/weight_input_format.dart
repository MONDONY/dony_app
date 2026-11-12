import 'package:flutter/services.dart';

/// Séparateur de milliers affiché dans le champ de poids : l'espace fine
/// insécable, celle du français (« 1 200 »).
const String kWeightGroupSeparator = ' ';

/// Décimales gardées : le back stocke les poids à deux décimales.
const int _maxFractionDigits = 2;

/// Lecture d'une saisie de poids : chiffres entiers, partie décimale (`null`
/// sans décimale, vide pour « 12, » en cours de frappe) et marque décimale
/// retenue (`.` ou `,`).
typedef WeightReading = ({
  String integer,
  String? fraction,
  String? mark,
  int? markIndex,
});

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

bool _isMark(String ch) => ch == '.' || ch == ',';

/// Interprète [raw] sans ambiguïté sur les milliers et les décimales.
///
/// - Espaces (dont l'insécable et l'espace fine) : toujours des milliers.
/// - Un `,` et un `.` ensemble : le dernier est la marque décimale, l'autre
///   sépare les milliers (« 1,200.5 » EN, « 1.200,5 » FR).
/// - La même marque plusieurs fois (« 1,200,500 ») : des milliers.
/// - Une seule marque suivie d'exactement trois chiffres, après un à trois
///   chiffres non nuls (« 1,200 », « 1.200 ») : ambiguë. En route et en
///   bateau ([heavy]) c'est un séparateur de MILLIERS (les poids s'y comptent
///   en centaines et en milliers : « 1,200 » en anglais est 1 200 kg, jamais
///   1,2) ; en avion et « peu importe » (32 kg au plus) elle reste décimale.
/// - Toute autre marque seule est décimale (« 1.5 », « 1200.5 », « 0.500 »).
WeightReading readWeightInput(String raw, {bool heavy = false}) {
  // Garde chiffres et marques, en retenant la place de chaque marque dans
  // [raw] pour replacer le curseur.
  final kept = StringBuffer();
  final rawIndexes = <int>[];
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    if (_isDigit(ch) || _isMark(ch)) {
      kept.write(ch);
      rawIndexes.add(i);
    }
  }
  final s = kept.toString();
  final marks = <int>[
    for (var i = 0; i < s.length; i++)
      if (_isMark(s[i])) i,
  ];
  String digitsOf(String text) => text.replaceAll(RegExp(r'[.,]'), '');

  if (marks.isEmpty) {
    return (integer: s, fraction: null, mark: null, markIndex: null);
  }
  final hasDot = s.contains('.');
  final hasComma = s.contains(',');
  final last = marks.last;

  if (hasDot && hasComma) {
    return (
      integer: digitsOf(s.substring(0, last)),
      fraction: s.substring(last + 1),
      mark: s[last],
      markIndex: rawIndexes[last],
    );
  }
  if (marks.length > 1) {
    // Une marque répétée ne peut être que des milliers.
    return (integer: digitsOf(s), fraction: null, mark: null, markIndex: null);
  }
  final before = s.substring(0, last);
  final after = s.substring(last + 1);
  final ambiguousThousands =
      heavy &&
      after.length == 3 &&
      before.isNotEmpty &&
      before.length <= 3 &&
      before != '0';
  if (ambiguousThousands) {
    return (
      integer: before + after,
      fraction: null,
      mark: null,
      markIndex: null,
    );
  }
  return (
    integer: before,
    fraction: after,
    mark: s[last],
    markIndex: rawIndexes[last],
  );
}

/// Lit un poids saisi dans le champ (voir [readWeightInput]). `null` quand la
/// saisie n'est pas un nombre.
double? parseWeightInput(String text, {bool heavy = false}) {
  final r = readWeightInput(text, heavy: heavy);
  final fraction = r.fraction;
  final hasFraction = fraction != null && fraction.isNotEmpty;
  if (r.integer.isEmpty && !hasFraction) return null;
  final integer = r.integer.isEmpty ? '0' : r.integer;
  return double.tryParse(hasFraction ? '$integer.$fraction' : integer);
}

/// Texte du champ pour un poids déjà connu : milliers groupés (« 1 200 »),
/// aucune décimale quand le poids est entier.
String formatWeightInput(double kg) {
  final whole = kg == kg.roundToDouble();
  final text = whole ? kg.toInt().toString() : kg.toString();
  final dot = text.indexOf('.');
  final integer = dot < 0 ? text : text.substring(0, dot);
  final rest = dot < 0 ? '' : text.substring(dot);
  return '${_group(integer)}$rest';
}

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(kWeightGroupSeparator);
    }
    out.write(digits[i]);
  }
  return out.toString();
}

/// Réécrit le poids pendant la frappe : milliers groupés (« 1200 » devient
/// « 1 200 »), un séparateur de milliers tapé ou collé (« 1,200 » en route)
/// lu comme tel, une seule marque décimale, deux décimales au plus. Le champ
/// montre ce qui est réellement retenu, [parseWeightInput] lit la même
/// chose. Le curseur reste sur le même chiffre.
class GroupedWeightInputFormatter extends TextInputFormatter {
  const GroupedWeightInputFormatter({this.heavy = false});

  /// Route ou bateau : un `,` ou `.` ambigu est un séparateur de milliers.
  final bool heavy;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final caret = newValue.selection.baseOffset < 0
        ? text.length
        : newValue.selection.baseOffset.clamp(0, text.length);
    final r = readWeightInput(text, heavy: heavy);
    var fraction = r.fraction;
    if (fraction != null && fraction.length > _maxFractionDigits) {
      fraction = fraction.substring(0, _maxFractionDigits);
    }
    final mark = fraction == null ? null : r.mark;
    final formatted =
        '${_group(r.integer)}${mark == null ? '' : '$mark${fraction ?? ''}'}';

    if (caret >= text.length) {
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    // Curseur : après le même nombre de chiffres, et après la marque décimale
    // si elle le précédait.
    var digitsBefore = 0;
    for (var i = 0; i < caret; i++) {
      if (_isDigit(text[i])) digitsBefore++;
    }
    final markBefore =
        mark != null && r.markIndex != null && r.markIndex! < caret;
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBefore) {
      if (_isDigit(formatted[offset])) seen++;
      offset++;
    }
    if (markBefore) {
      while (offset < formatted.length && formatted[offset] != mark) {
        offset++;
      }
      if (offset < formatted.length) offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
