import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _makeAnn({String arrivalCity = 'Dakar', bool kiloPro = false}) =>
    AnnouncementModel(
      id: 'a1',
      travelerId: 't1',
      departureCity: 'Paris',
      arrivalCity: arrivalCity,
      departureDate: DateTime(2026, 6, 15),
      availableKg: 8,
      totalKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      traveler: TravelerProfile(
        id: 't1',
        displayName: 'Mamadou Diallo',
        averageRating: 4.8,
        totalTrips: 5,
        kiloPro: kiloPro,
      ),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('TravelerCard', () {
    testWidgets('shows traveler name and price', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Mamadou Diallo'), findsOneWidget);
      expect(find.text('12 €/kg'), findsOneWidget);
    });

    testWidgets('shows KYC badge when kiloPro is true', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(kiloPro: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('KYC'), findsOneWidget);
    });

    testWidgets('shows Votre trajet label when isOwnAnnouncement', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: true,
        onTap: null,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Votre trajet'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () => tapped = true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TravelerCard));
      expect(tapped, isTrue);
    });
  });

  group('TravelerCard – distanceBadge', () {
    testWidgets('affiche le badge quand distanceBadge est fourni', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        distanceBadge: 'CDG · 8 km',
      )));
      await tester.pumpAndSettle();
      expect(find.text('CDG · 8 km'), findsOneWidget);
    });

    testWidgets('n\'affiche rien quand distanceBadge est null', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('CDG · 8 km'), findsNothing);
    });
  });
}
