import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/traveler_announcement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  Widget _wrap(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  TravelerAnnouncement _announcement({
    String departureCity = 'Paris',
    String arrivalCity = 'Dakar',
    double pricePerKg = 8,
    double availableKg = 5,
    DateTime? departureDate,
  }) =>
      TravelerAnnouncement(
        id: 'a1',
        departureCity: departureCity,
        arrivalCity: arrivalCity,
        departureDate: departureDate ?? DateTime(2026, 6, 1),
        pricePerKg: pricePerKg,
        availableKg: availableKg,
        status: 'ACTIVE',
      );

  testWidgets('affiche les villes départ et arrivée', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(departureCity: 'Paris', arrivalCity: 'Dakar'),
      onReserve: () {},
    )));
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('affiche l\'icône avion', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(),
      onReserve: () {},
    )));
    expect(find.byIcon(Icons.flight_takeoff_rounded), findsOneWidget);
  });

  testWidgets('affiche la date formatée en français', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(departureDate: DateTime(2026, 6, 1)),
      onReserve: () {},
    )));
    expect(find.text('01 juin 2026'), findsOneWidget);
  });

  testWidgets('affiche le poids disponible', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(availableKg: 7),
      onReserve: () {},
    )));
    expect(find.text('7 kg dispo'), findsOneWidget);
  });

  testWidgets('affiche le prix et l\'unité /kg', (tester) async {
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(pricePerKg: 8),
      onReserve: () {},
    )));
    expect(find.text('8 €'), findsOneWidget);
    expect(find.text('/kg'), findsOneWidget);
  });

  testWidgets('le bouton Réserver déclenche onReserve', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(),
      onReserve: () => tapped = true,
    )));
    await tester.tap(find.text('Réserver'));
    expect(tapped, isTrue);
  });

  testWidgets('pas de débordement sur 320px de large', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(TravelerAnnouncementCard(
      announcement: _announcement(
        departureCity: 'Paris',
        arrivalCity: 'Ouagadougou',
      ),
      onReserve: () {},
    )));

    // Si RenderFlex overflow, le test lève une exception
    expect(tester.takeException(), isNull);
  });
}
