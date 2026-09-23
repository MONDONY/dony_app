// Feuille « Aucun trajet actif », ouverte par son point d'entrée public
// `showNoActiveTripSheet`, en français puis en anglais.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/presentation/widgets/no_active_trip_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _host({VoidCallback? onPublishTrip}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showNoActiveTripSheet(
          context,
          sheetsToPop: 1,
          onPublishTrip: onPublishTrip,
        ),
        child: const Text('ouvrir'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, {VoidCallback? onPublishTrip}) async {
  await tester.pumpWidget(_host(onPublishTrip: onPublishTrip));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en français : titre, explication et bouton inchangés', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('Aucun trajet actif'), findsOneWidget);
    expect(
      find.text(
        'Ce filtre ne montre que les colis compatibles avec tes '
        "trajets à venir. Publie un trajet pour t'en servir.",
      ),
      findsOneWidget,
    );
    expect(find.text('Publier un trajet'), findsOneWidget);
  });

  testWidgets('en anglais : la feuille est traduite', (tester) async {
    useEnglish();
    await _open(tester);

    expect(find.text('No active trip'), findsOneWidget);
    expect(
      find.text(
        'This filter only shows parcels that fit your upcoming trips. '
        'Post a trip to use it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Post a trip'), findsOneWidget);
    expect(find.text('Aucun trajet actif'), findsNothing);
  });

  testWidgets('le bouton ferme la feuille puis lance la publication', (
    tester,
  ) async {
    var publications = 0;
    await _open(tester, onPublishTrip: () => publications++);

    await tester.tap(find.widgetWithText(DonyButton, 'Publier un trajet'));
    await tester.pumpAndSettle();

    expect(publications, 1);
    expect(find.text('Aucun trajet actif'), findsNothing);
  });
}
