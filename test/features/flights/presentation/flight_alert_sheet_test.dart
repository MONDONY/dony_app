import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Future<void> _open(WidgetTester tester, double? lowest) async {
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => FlightAlertSheet.show(
            context,
            currentLowest: lowest,
            currencyCode: 'EUR',
            onSubmit: (_) async => true,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String _threshold(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('flight-alert-price')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets(
    'seuil proposé strictement sous le prix le plus bas : aucune alerte '
    'immédiate sur un prix déjà affiché',
    (tester) async {
      await _open(tester, 431.6);
      expect(_threshold(tester), '431');
    },
  );

  testWidgets('prix entier : seuil un cran en dessous', (tester) async {
    await _open(tester, 431);
    expect(_threshold(tester), '430');
  });

  testWidgets('sans prix connu : champ vide', (tester) async {
    await _open(tester, null);
    expect(_threshold(tester), isEmpty);
  });

  testWidgets('trajet repris : le bouton du bas crée l\'alerte et ferme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    FlightAlertDraft? sent;
    bool? created;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => created = await FlightAlertSheet.show(
              context,
              origin: const FlightPlace(code: 'PAR', name: 'Paris'),
              destination: const FlightPlace(code: 'ABJ', name: 'Abidjan'),
              currentLowest: 431,
              currencyCode: 'EUR',
              onSubmit: (draft) async {
                sent = draft;
                return true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Aller-retour : il manque la période du retour, le bouton est éteint.
    await tester.tap(find.byKey(const Key('flight-alert-trip-roundtrip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-return')), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-alert-submit')));
    await tester.pumpAndSettle();
    expect(sent, isNull);

    await tester.tap(find.byKey(const Key('flight-alert-trip-oneway')));
    await tester.tap(find.byKey(const Key('flight-alert-direct')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-alert-submit')));
    await tester.pumpAndSettle();

    expect(sent?.maxPrice, 430);
    expect(sent?.directOnly, isTrue);
    expect(sent?.returnFrom, isNull);
    expect(created, isTrue);
    expect(find.byKey(const Key('flight-alert-submit')), findsNothing);
  });

  testWidgets('périodes reprises : ramenées à 31 jours, échec sans fermer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    FlightAlertDraft? sent;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FlightAlertSheet.show(
              context,
              origin: const FlightPlace(code: 'PAR', name: 'Paris'),
              destination: const FlightPlace(code: 'DKR', name: 'Dakar'),
              // Commencée hier : repart d'aujourd'hui.
              departure: DateTimeRange(
                start: today.subtract(const Duration(days: 1)),
                end: today.add(const Duration(days: 3)),
              ),
              // 60 jours : ramenée à 31.
              returnRange: DateTimeRange(
                start: DateTime(today.year, today.month, today.day + 20),
                end: DateTime(today.year, today.month, today.day + 80),
              ),
              currentLowest: 300,
              currencyCode: 'EUR',
              onSubmit: (draft) async {
                sent = draft;
                return false;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flight-alert-return')), findsOneWidget);
    expect(find.text('31 jours au plus'), findsNothing);

    // Le calendrier s'ouvre puis se ferme sans choix.
    await tester.tap(find.byKey(const Key('flight-alert-departure')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-alert-submit')));
    await tester.pumpAndSettle();
    expect(sent?.departureFrom, today);
    expect(sent?.returnTo, DateTime(today.year, today.month, today.day + 50));
    expect(sent?.currency, 'EUR');
    // Refusé : la feuille reste ouverte, le bouton revient.
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
  });

  testWidgets('période passée ignorée', (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 40));
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FlightAlertSheet.show(
              context,
              departure: DateTimeRange(
                start: past,
                end: past.add(const Duration(days: 2)),
              ),
              currencyCode: 'EUR',
              onSubmit: (_) async => true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Toutes les dates à venir'), findsOneWidget);
  });
}
