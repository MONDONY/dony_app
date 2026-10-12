import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/widgets/flight_dates_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  FlightDatesChoice? choice;

  Future<void> open(
    WidgetTester tester, {
    FlightWhen? departure,
    FlightWhen? returnDate,
    bool roundTrip = false,
    bool returnFirst = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    choice = null;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => choice = await FlightDatesSheet.show(
              context,
              departure: departure,
              returnDate: returnDate,
              roundTrip: roundTrip,
              returnFirst: returnFirst,
              today: DateTime(2026, 10, 12),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester) =>
      tester
          .widget<DonyButton>(find.byKey(const Key('flight-dates-validate')))
          .onPressed !=
      null;

  testWidgets('retour avant l\'aller : refusé au jour, accepté au mois', (
    tester,
  ) async {
    await open(
      tester,
      departure: FlightWhen.day(DateTime(2026, 12, 20)),
      returnDate: FlightWhen.day(DateTime(2026, 12, 10)),
      returnFirst: true,
    );
    expect(find.byKey(const Key('flight-dates-return')), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('flight-dates-month')));
    await tester.pumpAndSettle();
    expect(enabled(tester), isTrue);
    // Sur le retour, les mois avant l'aller sont éteints.
    await tester.tap(find.byKey(const Key('flight-month-2027-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();
    expect(choice?.departure, FlightWhen.month(DateTime(2026, 12)));
    expect(choice?.returnDate, FlightWhen.month(DateTime(2027)));
  });

  testWidgets('aller choisi après le retour : le retour est effacé', (
    tester,
  ) async {
    await open(
      tester,
      departure: FlightWhen.month(DateTime(2026, 11)),
      returnDate: FlightWhen.month(DateTime(2026, 12)),
    );
    await tester.tap(find.byKey(const Key('flight-dates-departure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-month-2027-2')));
    await tester.pumpAndSettle();
    // L'aller-retour passe au retour, désormais vide.
    await tester.tap(find.byKey(const Key('flight-dates-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();
    expect(choice?.departure, FlightWhen.day(DateTime(2027, 2)));
    expect(choice?.returnDate, isNull);
  });
}
