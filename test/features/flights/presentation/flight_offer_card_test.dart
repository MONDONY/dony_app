import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

/// Aller-retour Corsair : retour de nuit qui arrive le lendemain.
final _roundTrip = FlightOffer.fromJson(const {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'originAirport': 'ORY',
  'departureAt': '2026-12-12T11:45:00+01:00',
  'arrivalAt': '2026-12-12T16:45:00Z',
  'returnAt': '2027-01-03T23:30:00Z',
  'returnArrivalAt': '2027-01-04T06:50:00+01:00',
  'price': 498,
  'currency': 'EUR',
  'airlineCode': 'SS',
  'airlineName': 'Corsair',
  'flightNumber': '950',
  'transfers': 0,
  'returnTransfers': 1,
  'durationMinutes': 740,
  'outboundDurationMinutes': 360,
  'returnDurationMinutes': 380,
  'gate': 'Kiwi.com',
  'offerPath': '/search/X',
});

/// Ancien back : pas d'heure d'arrivée, pas de durée par trajet.
final _legacy = FlightOffer.fromJson(const {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'originAirport': 'CDG',
  'departureAt': '2026-12-12T11:30:00+01:00',
  'price': 431,
  'currency': 'EUR',
  'airlineCode': 'AT',
  'airlineName': 'Royal Air Maroc',
  'flightNumber': 'AT 571',
  'transfers': 2,
  'durationMinutes': 585,
  'offerPath': '/search/Y',
});

Widget _host(
  FlightOffer offer, {
  FlightOfferBadge? badge,
  bool opening = false,
  VoidCallback? onOpen,
  Locale locale = AppL10n.fr,
}) => localizedApp(
  Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: FlightOfferCard(
        offer: offer,
        badge: badge,
        opening: opening,
        onOpen: onOpen,
      ),
    ),
  ),
  locale: locale,
);

void main() {
  testWidgets('aller-retour : horaires, durées, escales, +1, site et prix', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_roundTrip, badge: FlightOfferBadge.fastest));
    await tester.pumpAndSettle();

    expect(find.text('Corsair · SS 950'), findsOneWidget);
    expect(find.text('Le plus rapide'), findsOneWidget);
    expect(find.byKey(const Key('flight-leg-outbound')), findsOneWidget);
    expect(find.byKey(const Key('flight-leg-return')), findsOneWidget);
    // Heures locales des aéroports, telles que reçues.
    expect(find.text('11:45', findRichText: true), findsOneWidget);
    expect(find.text('16:45', findRichText: true), findsOneWidget);
    expect(find.text('23:30', findRichText: true), findsOneWidget);
    expect(find.text('6 h'), findsOneWidget);
    expect(find.text('6 h 20'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('1 escale'), findsOneWidget);
    // Retour arrivé le lendemain : « +1 » une seule fois.
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('ORY'), findsNWidgets(2));
    expect(find.text('Kiwi.com', findRichText: true), findsNothing);
    expect(find.text('via Kiwi.com', findRichText: true), findsOneWidget);
    expect(find.textContaining('498'), findsOneWidget);
    expect(find.text('prix indicatif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans heure d\'arrivée : le code de l\'aéroport seul, sans durée '
      'inventée', (tester) async {
    await tester.pumpWidget(_host(_legacy, badge: FlightOfferBadge.cheapest));
    await tester.pumpAndSettle();

    expect(find.text('Royal Air Maroc · AT 571'), findsOneWidget);
    expect(find.text('Le moins cher'), findsOneWidget);
    expect(find.text('11:30', findRichText: true), findsOneWidget);
    expect(find.text('ABJ'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
    expect(find.byKey(const Key('flight-leg-return')), findsNothing);
    expect(find.text('2 escales'), findsOneWidget);
    // Aller simple sur un ancien back : la durée totale est celle de l'aller.
    expect(find.text('9 h 45'), findsOneWidget);
    // Pas de site vendeur : rien à gauche du prix.
    expect(find.textContaining('via'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toute la carte ouvre l\'offre ; en cours, plus de second tap', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(_host(_roundTrip, onOpen: () => opened++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-open-/search/X')));
    expect(opened, 1);

    await tester.pumpWidget(
      _host(_roundTrip, opening: true, onOpen: () => opened++),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-open-/search/X')));
    expect(opened, 1);
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(
      _host(
        _roundTrip,
        badge: FlightOfferBadge.cheapest,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.text('1 stop'), findsOneWidget);
    expect(find.text('6h 20m'), findsOneWidget);
    expect(find.text('indicative price'), findsOneWidget);
  });
}
