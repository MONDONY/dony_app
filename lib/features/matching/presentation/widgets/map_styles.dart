import 'package:flutter/material.dart';

/// Style Google « nuit » dérivé des tokens dark du design system Yadony :
/// geometry = neutralDark50 (#11161E), water = neutralDark0 (#0A0E14),
/// road = neutralDark200 (#222932), road stroke = neutralDark100 (#161B23),
/// highway = neutralDark300 (#2D333D), labels = neutralDark500 (#B5AFA5).
/// POI/transit masqués pour rester épuré (comme l'ancien style clair).
const String kGoogleNightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#11161E"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#B5AFA5"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0A0E14"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#222932"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#161B23"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7E7972"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2D333D"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#0A0E14"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#54504A"}]}
]''';

/// Style de carte selon le thème :
/// clair → `null` (apparence Google standard), sombre → style nuit.
String? resolveMapStyle(Brightness brightness) =>
    brightness == Brightness.dark ? kGoogleNightMapStyle : null;
