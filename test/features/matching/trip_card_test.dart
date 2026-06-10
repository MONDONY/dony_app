import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  String status = 'ACTIVE',
  double totalKg = 20,
  double availableKg = 13,
  String? capacityUnit,
  int pendingBidCount = 0,
  int confirmedParcelCount = 0,
}) {
  return AnnouncementModel.fromJson({
    'id': 'a1',
    'travelerId': 't1',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate':
        DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    'totalKg': totalKg,
    'availableKg': availableKg,
    'pricePerKg': 8.0,
    'status': status,
    if (capacityUnit != null) 'capacityUnit': capacityUnit,
    'pendingBidCount': pendingBidCount,
    'confirmedParcelCount': confirmedParcelCount,
    'createdAt': '2024-01-01T00:00:00Z',
    'updatedAt': '2024-01-01T00:00:00Z',
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche route, drapeaux, progression et prix', (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('🇫🇷'), findsOneWidget);
    expect(find.text('🇸🇳'), findsOneWidget);
    expect(find.textContaining('7 kg vendus sur 20 kg'), findsOneWidget);
    expect(find.textContaining('13 kg'), findsWidgets);
    expect(find.textContaining('8 €'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('carte terminée : footer condensé, pas de progression',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(status: 'COMPLETED', availableKg: 0),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Terminé'), findsOneWidget);
    expect(find.textContaining('vendus sur'), findsNothing);
    expect(find.textContaining('20 kg vendus'), findsOneWidget);
    expect(find.textContaining('160 € gagnés'), findsOneWidget);
  });

  // ── KG_FREE tests ──────────────────────────────────────────────────────────

  testWidgets(
      'KG_FREE actif : affiche "Kg libre", cache la barre de progression et vendus sur',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    // Should show "Kg libre" instead of raw kg numbers
    expect(find.text('Kg libre'), findsOneWidget);

    // Must NOT show the "vendus sur" progress label
    expect(find.textContaining('vendus sur'), findsNothing);

    // Must NOT show "1 kg disponibles" (raw availableKg)
    expect(find.textContaining('1 kg disponibles'), findsNothing);
  });

  testWidgets(
      'KG_FREE terminé : footer condensé affiche "Kg libre" au lieu de vendus',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(
        status: 'COMPLETED',
        capacityUnit: 'KG_FREE',
        availableKg: 0,
        totalKg: 1,
      ),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Terminé'), findsOneWidget);
    // Must NOT show "{kg} vendus" for KG_FREE past trips
    expect(find.textContaining('vendus'), findsNothing);
    // Should show "Kg libre" instead
    expect(find.text('Kg libre'), findsOneWidget);
  });

  // ── Demandes stats row ───────────────────────────────────────────────────

  testWidgets(
      'trajet actif : affiche les chips acceptées + en attente (pluriel)',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(confirmedParcelCount: 2, pendingBidCount: 3),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('2 acceptées'), findsOneWidget);
    expect(find.text('3 en attente'), findsOneWidget);
  });

  testWidgets('trajet actif : aucun chip quand les deux compteurs sont à 0',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('acceptée'), findsNothing);
    expect(find.textContaining('en attente'), findsNothing);
  });

  testWidgets('trajet actif : singulier "1 acceptée" (pas "acceptées")',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(confirmedParcelCount: 1),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('1 acceptée'), findsOneWidget);
    expect(find.text('1 acceptées'), findsNothing);
  });

  testWidgets('trajet terminé : la ligne de stats est absente même si compteurs > 0',
      (tester) async {
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(
        status: 'COMPLETED',
        availableKg: 0,
        confirmedParcelCount: 2,
        pendingBidCount: 3,
      ),
      onTap: () {},
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('acceptée'), findsNothing);
    expect(find.textContaining('en attente'), findsNothing);
  });

  testWidgets('onTap déclenché', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(TripCard(
      announcement: _announcement(),
      onTap: () => tapped = true,
      index: 0,
    )));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(TripCard));
    expect(tapped, isTrue);
  });
}
