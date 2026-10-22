import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/request_corridor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap(Widget child, {double width = 360}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  testWidgets('villes, drapeaux déduits et libellés Départ / Arrivée', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const RequestCorridor(departureCity: 'Paris', arrivalCity: 'Abidjan'),
      ),
    );

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Abidjan'), findsOneWidget);
    expect(find.textContaining('Départ'), findsOneWidget);
    expect(find.textContaining('Arrivée'), findsOneWidget);
    // Drapeaux : France au départ, Côte d'Ivoire à l'arrivée.
    expect(find.textContaining('\u{1F1EB}\u{1F1F7}'), findsOneWidget);
    expect(find.textContaining('\u{1F1E8}\u{1F1EE}'), findsOneWidget);
  });

  testWidgets('ville inconnue : libellé seul, sans drapeau ni texte parasite', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const RequestCorridor(
          departureCity: 'Ville inventée',
          arrivalCity: 'Autre lieu',
        ),
      ),
    );

    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('la flèche est décorative : hors de l\'arbre sémantique', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const RequestCorridor(departureCity: 'Paris', arrivalCity: 'Dakar')),
    );

    final arrow = find.byType(CustomPaint).last;
    expect(
      find.ancestor(of: arrow, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
  });

  testWidgets('variante compacte : villes plus petites, flèche plus courte', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            RequestCorridor(departureCity: 'Paris', arrivalCity: 'Dakar'),
            RequestCorridor(
              compact: true,
              departureCity: 'Lyon',
              arrivalCity: 'Bamako',
            ),
          ],
        ),
      ),
    );

    double fontOf(String city) =>
        tester.widget<Text>(find.text(city)).style!.fontSize!;
    expect(fontOf('Lyon'), lessThan(fontOf('Paris')));

    final arrows = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(ExcludeSemantics),
            matching: find.byType(SizedBox),
          ),
        )
        .where((b) => b.width != null && b.height != null && b.width! > 40)
        .map((b) => b.width!)
        .toList();
    expect(arrows, containsAll(<double>[76, 56]));
  });

  testWidgets('petit écran et villes longues : aucun débordement', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const RequestCorridor(
          departureCity: 'Saint-Denis de la Réunion',
          arrivalCity: 'Port-au-Prince Toussaint Louverture',
        ),
        width: 260,
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('l\'anglais traduit les libellés', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(const RequestCorridor(departureCity: 'Paris', arrivalCity: 'Dakar')),
    );

    expect(find.textContaining('From'), findsOneWidget);
    expect(find.textContaining('To'), findsOneWidget);
  });
}
