import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  String status = 'ACTIVE',
  double totalKg = 20,
  double availableKg = 13,
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
