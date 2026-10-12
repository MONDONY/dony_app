import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/widgets/flight_billet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

final _offer = FlightOffer(
  originCode: 'PAR',
  destinationCode: 'ABJ',
  originAirport: 'CDG',
  departureAt: DateTime(2026, 12, 12, 11, 30),
  returnAt: DateTime(2027, 1, 8, 14, 5),
  price: 431,
  currency: 'EUR',
  airlineCode: 'AT',
  airlineName: 'Royal Air Maroc',
  transfers: 1,
  durationMinutes: 585,
  offerPath: '/search/X',
);

Widget _host({
  bool cheapest = false,
  bool opening = false,
  VoidCallback? onOpen,
}) => localizedApp(
  Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: FlightBilletCard(
        offer: _offer,
        originName: 'Paris',
        destinationName: 'Abidjan',
        cheapest: cheapest,
        opening: opening,
        onOpen: onOpen,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'billet : compagnie, codes d\'aéroport, escales, prix et mention',
    (tester) async {
      await tester.pumpWidget(_host(cheapest: true));
      await tester.pumpAndSettle();

      expect(find.text('ROYAL AIR MAROC'), findsOneWidget);
      expect(find.text('CDG'), findsOneWidget);
      expect(find.text('ABJ'), findsOneWidget);
      expect(find.text('1 escale · 9 h 45'), findsOneWidget);
      expect(find.text('Le moins cher'), findsOneWidget);
      expect(find.textContaining('431'), findsOneWidget);
      expect(
        find.text('Prix indicatif · réservation chez notre partenaire'),
        findsOneWidget,
      );
      expect(find.text('Aller'), findsOneWidget);
      expect(find.text('Retour'), findsOneWidget);
    },
  );

  testWidgets('« Voir l\'offre » déclenche l\'ouverture', (tester) async {
    var opened = false;
    await tester.pumpWidget(_host(onOpen: () => opened = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Voir l'offre"));
    expect(opened, isTrue);
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: SingleChildScrollView(
            child: FlightBilletCard(
              offer: _offer,
              originName: 'Paris',
              destinationName: 'Abidjan',
              onOpen: () {},
            ),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View offer'), findsOneWidget);
    expect(find.text('1 stop · 9h 45m'), findsOneWidget);
  });
}
