import 'package:flutter/material.dart';

/// Style Google « nuit » dérivé des tokens dark du design system Yadony.
///
/// FLUTTER-FF : l'ancienne base (terre #11161E, eau #0A0E14) était presque
/// noire. À faible zoom (vue monde, 3,5), la carte entière se lisait comme un
/// rectangle noir, impossible à distinguer d'une carte qui n'a pas chargé.
/// Terre et eau sont éclaircies et séparées (l'eau tire vers le bleu), et les
/// frontières de pays réapparaissent, discrètes : les continents restent
/// lisibles sans casser l'ambiance nuit.
/// POI/transit masqués pour rester épuré (comme le style clair).
const String kGoogleNightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#222A35"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#B5AFA5"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#151C27"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"visibility":"on"},{"color":"#46505E"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2E3642"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1B222C"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8A847C"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3A4350"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#16212F"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5E6A78"}]}
]''';

/// Style de carte selon le thème :
/// clair → `null` (apparence Google standard), sombre → style nuit.
String? resolveMapStyle(Brightness brightness) =>
    brightness == Brightness.dark ? kGoogleNightMapStyle : null;
