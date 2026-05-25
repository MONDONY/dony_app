import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/traveler_announcement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche corridor, prix et bouton Réserver', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TravelerAnnouncementCard(
            announcement: TravelerAnnouncement(
              id: 'a1',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              departureDate: DateTime(2026, 6, 1),
              pricePerKg: 8,
              availableKg: 5,
              status: 'ACTIVE',
            ),
            onReserve: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('8 €'), findsOneWidget);
    await tester.tap(find.text('Réserver'));
    expect(tapped, true);
  });
}
