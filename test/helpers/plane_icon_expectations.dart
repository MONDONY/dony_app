import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Glyphes Material « avion » (`Icons.flight*`, toutes variantes).
final Set<int> _materialFlightCodePoints = {
  Icons.flight.codePoint,
  Icons.flight_rounded.codePoint,
  Icons.flight_outlined.codePoint,
  Icons.flight_sharp.codePoint,
  Icons.flight_takeoff.codePoint,
  Icons.flight_takeoff_rounded.codePoint,
  Icons.flight_takeoff_outlined.codePoint,
  Icons.flight_takeoff_sharp.codePoint,
  Icons.flight_land.codePoint,
  Icons.flight_land_rounded.codePoint,
  Icons.flight_land_outlined.codePoint,
  Icons.flight_land_sharp.codePoint,
};

/// Emoji d'avion (texte brut, `DonyEmoji.planeTakeoff` compris).
const List<String> _planeEmoji = ['✈', '🛫', '🛬'];

/// Chaque `DonyIcon` d'avion (`plane`, `plane-takeoff`, `plane-landing`...).
Finder findPlaneDonyIcons() => find.byWidgetPredicate(
  (widget) => widget is DonyIcon && widget.name.startsWith('plane'),
  description: 'DonyIcon avion',
);

/// Chaque `Icon` Material d'avion (`Icons.flight*`).
Finder findMaterialFlightIcons() => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      widget.icon != null &&
      widget.icon!.fontFamily == 'MaterialIcons' &&
      _materialFlightCodePoints.contains(widget.icon!.codePoint),
  description: 'Icon Material avion',
);

/// Chaque texte portant un emoji d'avion (✈️, 🛫, 🛬).
Finder findPlaneEmojiTexts() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data != null) &&
      _planeEmoji.any(widget.data!.contains),
  description: 'Text avec emoji avion',
);

/// Aucun avion dessiné dans l'arbre courant : ni `DonyIcon('plane*')`, ni
/// `Icons.flight*`, ni emoji d'avion. À utiliser pour tout trajet qui n'est
/// pas un avion (bateau, route, mode neutre).
void expectNoPlaneIcon(WidgetTester tester) {
  expect(findPlaneDonyIcons(), findsNothing, reason: 'DonyIcon avion');
  expect(findMaterialFlightIcons(), findsNothing, reason: 'Icons.flight*');
  expect(findPlaneEmojiTexts(), findsNothing, reason: 'emoji avion');
}

/// `DonyIcon` de nom [name] présent dans l'arbre courant.
Finder findDonyIcon(String name) => find.byWidgetPredicate(
  (widget) => widget is DonyIcon && widget.name == name,
  description: "DonyIcon('$name')",
);
