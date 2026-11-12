import 'package:dony/l10n/l10n.dart';

/// Taille d'un colis pour un trajet routier (voiture, bus) : du sac au meuble.
///
/// Miroir de `ItemSize` côté back (`"S"`, `"M"`, `"L"`, `"XL"`). L'ordre de
/// déclaration est celui de la taille croissante : [fitsWithin] s'appuie
/// dessus.
enum ItemSize {
  s('S'),
  m('M'),
  l('L'),
  xl('XL');

  const ItemSize(this.wire);

  /// Valeur échangée avec le back.
  final String wire;

  /// Vrai quand un colis de cette taille tient dans un trajet qui accepte
  /// jusqu'à [max] : une taille plus petite ou égale passe toujours.
  bool fitsWithin(ItemSize max) => index <= max.index;
}

/// Taille lue sur le fil ; une valeur absente ou inconnue (nouvelle taille
/// d'un back plus récent, `"NONE"`, minuscule) donne `null` : la taille reste
/// facultative, l'écran ne plante jamais sur une valeur qu'il ne connaît pas.
ItemSize? itemSizeFromWire(Object? raw) {
  if (raw is! String) {
    return null;
  }
  for (final size in ItemSize.values) {
    if (size.wire == raw) {
      return size;
    }
  }
  return null;
}

String itemSizeToWire(ItemSize size) => size.wire;

/// Pour la sérialisation d'un champ facultatif : `null` reste `null`.
String? itemSizeToWireOrNull(ItemSize? size) => size?.wire;

extension ItemSizeL10n on ItemSize {
  /// Code court affiché en gras sur la tuile (« S », « XL »).
  String get code => wire;

  /// Exemple parlant sous le code (« Sac », « Valise, chaise »).
  String description(AppLocalizations l) => switch (this) {
    ItemSize.s => l.itemSizeSDescription,
    ItemSize.m => l.itemSizeMDescription,
    ItemSize.l => l.itemSizeLDescription,
    ItemSize.xl => l.itemSizeXlDescription,
  };
}

/// Poids d'un colis suivi de sa taille quand elle est connue (« 25 kg · taille
/// L ») ; [weight] est déjà formaté avec son unité. Sans taille, le poids seul.
String parcelWeightWithSize(
  AppLocalizations l,
  String weight,
  ItemSize? size,
) => size == null ? weight : l.parcelWeightAndSize(weight, size.code);
