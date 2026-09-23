import 'package:dony/l10n/l10n.dart';

/// Libellé de repli utilisé comme adresse quand le géocodage inverse échoue :
/// les coordonnées brutes, formatées à 4 décimales.
///
/// Construit à partir de `AppLocalizations` pour rester traduit, mais reste
/// reconnaissable dans les deux langues via [isGpsPositionLabel].
String gpsPositionLabel(AppLocalizations l, double lat, double lng) =>
    l.addressGpsPosition(lat.toStringAsFixed(4), lng.toStringAsFixed(4));

/// Vrai si [label] est un libellé de position GPS brute produit par
/// [gpsPositionLabel], quelle que soit la langue dans laquelle il a été
/// construit.
///
/// Une adresse enregistrée dans une langue doit rester reconnue dans l'autre
/// (ex. choisir l'icône « position actuelle » plutôt que « lieu »), donc ce
/// test porte uniquement sur le suffixe de coordonnées, indépendant du texte
/// traduit qui le précède.
final RegExp _gpsCoordinatesSuffix = RegExp(r'\(-?\d+\.\d{4}, -?\d+\.\d{4}\)$');

bool isGpsPositionLabel(String label) => _gpsCoordinatesSuffix.hasMatch(label);
