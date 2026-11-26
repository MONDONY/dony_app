import 'package:flutter/widgets.dart';

/// Longueur maximale, points de suspension compris, d'un prénom posé dans un
/// libellé de bouton (« Envoyer le code à {prénom} », « Appeler {prénom} ») :
/// le libellé le plus long (« Renvoyer le code à … », « Resend the code
/// to … », icône comprise) tient alors sur une ligne à 360 dp, en français et
/// en anglais, à la taille normale du bouton, même pour un prénom large saisi
/// en capitales (mesuré : 12 caractères en capitales débordaient de 5 dp).
const kButtonFirstNameMax = 11;

/// Prénom à poser dans un libellé de bouton : premier mot de [name], coupé à
/// [maxChars] caractères visibles (points de suspension compris). On coupe le
/// prénom, jamais la police : le `FittedBox` de `DonyButton` réduirait sinon
/// tout le libellé. `''` quand le nom est absent ou vide, le libellé prend
/// alors son texte de repli.
///
/// Compte en caractères visibles (graphèmes) : un emoji n'est jamais coupé en
/// deux.
String buttonFirstName(String? name, {int maxChars = kButtonFirstNameMax}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final first = trimmed.split(RegExp(r'\s+')).first.characters;
  if (first.length <= maxChars) return first.string;
  return '${first.take(maxChars - 1).string}…';
}
