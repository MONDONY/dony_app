import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/widgets/flight_filter_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_results_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

FlightOffer _o(String path, double price, String airline, int hour) =>
    FlightOffer(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      price: price,
      currency: 'EUR',
      airlineCode: airline,
      airlineName: airline == 'AF' ? 'Air France' : 'Corsair',
      transfers: 0,
      departureAt: DateTime(2026, 12, 12, hour),
      gate: 'Kiwi.com',
      offerPath: path,
    );

final _offers = [
  _o('a', 300, 'AF', 8),
  _o('b', 500, 'SS', 14),
  _o('c', 700, 'AF', 20),
];

void main() {
  FlightFilters? result;

  Future<void> open(WidgetTester tester, {FlightFilterSection? focus}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    result = null;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await FlightFilterSheet.show(
              context,
              offers: _offers,
              current: const FlightFilters(),
              currency: 'EUR',
              focus: focus,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('horaires, prix maximum et compagnie, puis validation', (
    tester,
  ) async {
    await open(tester, focus: FlightFilterSection.times);

    expect(find.text('Horaires de départ'), findsOneWidget);
    expect(find.byKey(const Key('flight-slot-night')), findsNothing);
    await tester.tap(find.byKey(const Key('flight-slot-morning')));
    await tester.pumpAndSettle();
    expect(find.text('Voir 1 billet'), findsOneWidget);
    // Deuxième tap : la tranche est retirée.
    await tester.tap(find.byKey(const Key('flight-slot-morning')));
    await tester.pumpAndSettle();
    expect(find.text('Voir 3 billets'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flight-price-500')));
    await tester.pumpAndSettle();
    expect(find.text('Voir 2 billets'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('flight-airline-SS')));
    await tester.tap(find.byKey(const Key('flight-airline-SS')));
    await tester.pumpAndSettle();
    expect(find.text('Voir 1 billet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flight-filters-apply')));
    await tester.pumpAndSettle();
    expect(result?.maxPrice, 500);
    expect(result?.airlines, {'SS'});
    expect(result?.activeCount, 2);
  });

  testWidgets('une puce ouvre la feuille sur sa rubrique', (tester) async {
    await open(tester, focus: FlightFilterSection.airlines);
    expect(
      find.byKey(const Key('flight-airline-AF')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('tous les prix et réinitialiser', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('flight-stops-direct')));
    await tester.tap(find.byKey(const Key('flight-price-400')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-price-any')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-filters-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-filters-apply')));
    await tester.pumpAndSettle();
    expect(result, const FlightFilters());
  });
}
