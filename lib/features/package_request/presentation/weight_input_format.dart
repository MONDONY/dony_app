import 'package:flutter/services.dart';

/// Séparateur de milliers du champ de poids : l'espace fine insécable, celle du
/// français (« 1 200 »). Aucune virgule de milliers : en anglais elle se
/// confondrait avec la virgule décimale que le champ accepte déjà.
const String kWeightGroupSeparator = ' ';

/// Lit un poids saisi dans le champ : séparateurs de milliers ignorés, virgule
/// ou point décimal. `null` quand la saisie n'est pas un nombre.
double? parseWeightInput(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
  return double.tryParse(cleaned);
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

/// Groupe les milliers du poids pendant la frappe (« 1200 » devient
/// « 1 200 ») et garde le curseur sur le même chiffre. Ne garde que les
/// chiffres et une seule marque décimale.
class GroupedWeightInputFormatter extends TextInputFormatter {
  const GroupedWeightInputFormatter();

  static bool _isDecimalMark(String ch) => ch == '.' || ch == ',';
  static bool _isDigit(String ch) =>
      ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final caret = newValue.selection.baseOffset < 0
        ? text.length
        : newValue.selection.baseOffset.clamp(0, text.length);
    final kept = StringBuffer();
    var keptBeforeCaret = 0;
    var seenDecimal = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final isMark = _isDecimalMark(ch);
      if (!(_isDigit(ch) || (isMark && !seenDecimal))) continue;
      if (isMark) seenDecimal = true;
      kept.write(ch);
      if (i < caret) keptBeforeCaret++;
    }
    final raw = kept.toString();
    final mark = raw.indexOf(RegExp(r'[.,]'));
    final integer = mark < 0 ? raw : raw.substring(0, mark);
    final formatted =
        '${_group(integer)}${mark < 0 ? '' : raw.substring(mark)}';

    var offset = 0;
    var counted = 0;
    while (offset < formatted.length && counted < keptBeforeCaret) {
      if (formatted[offset] != kWeightGroupSeparator) counted++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
