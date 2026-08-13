import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/traveler_announcement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  setUpAll(() => initializeDateFormatting('fr'));

  Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  TravelerAnnouncement _announcement({
    String departureCity = 'Paris',
    String arrivalCity = 'Dakar',
    double pricePerKg = 8,
    double availableKg = 5,
    DateTime? departureDate,
    String status = 'ACTIVE',
    String currency = 'EUR',
  }) => TravelerAnnouncement(
    id: 'a1',
    departureCity: departureCity,
    arrivalCity: arrivalCity,
    departureDate: departureDate ?? DateTime(2026, 6, 1),
    pricePerKg: pricePerKg,
    availableKg: availableKg,
    status: status,
    currency: currency,
  );

  testWidgets('affiche les villes départ et arrivée', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(),
          onReserve: () {},
        ),
      ),
    );
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('affiche l\'emoji avion', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(),
          onReserve: () {},
        ),
      ),
    );
    // L'icône avion est désormais l'emoji décollage (DonyEmoji 🛫).
    expect(find.text('🛫'), findsOneWidget);
  });

  testWidgets('affiche la date formatée en français', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(departureDate: DateTime(2026, 6, 1)),
          onReserve: () {},
        ),
      ),
    );
    expect(find.text('01 juin 2026'), findsOneWidget);
  });

  testWidgets('affiche le poids disponible', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(availableKg: 7),
          onReserve: () {},
        ),
      ),
    );
    expect(find.text('7 kg dispo'), findsOneWidget);
  });

  testWidgets('affiche le prix et l\'unité /kg', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(pricePerKg: 8),
          onReserve: () {},
        ),
      ),
    );
    // Fiche publique vue par l'expéditeur : prix = net × 1,12 (8 → 8,96 €).
    expect(find.textContaining('8,96'), findsOneWidget);
    expect(find.textContaining('€'), findsOneWidget);
    expect(find.text('/kg'), findsOneWidget);
  });

  testWidgets('affiche le prix dans la devise du trajet, pas toujours en EUR', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(pricePerKg: 8, currency: 'CAD'),
          onReserve: () {},
        ),
      ),
    );
    expect(find.textContaining('CA\$'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('le bouton Réserver déclenche onReserve', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(),
          onReserve: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('Réserver'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('availableKg=0 → affiche "Complet" au lieu de "X kg dispo"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(availableKg: 0),
          onReserve: () {},
        ),
      ),
    );
    expect(find.text('Complet'), findsOneWidget);
    expect(find.textContaining('kg dispo'), findsNothing);
  });

  testWidgets('availableKg=0 → bouton Réserver désactivé', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(availableKg: 0),
          onReserve: () => tapped = true,
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Réserver'), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('pas de débordement sur 320px de large', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        TravelerAnnouncementCard(
          announcement: _announcement(
            departureCity: 'Paris',
            arrivalCity: 'Ouagadougou',
          ),
          onReserve: () {},
        ),
      ),
    );

    // Si RenderFlex overflow, le test lève une exception
    expect(tester.takeException(), isNull);
  });
}
