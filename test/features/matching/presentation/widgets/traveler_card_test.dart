import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _makeAnn({
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
  String? departureFlag,
  String? arrivalFlag,
  bool kiloPro = false,
  bool isProAccount = false,
  bool kycVerified = false,
}) =>
    AnnouncementModel(
      id: 'a1',
      travelerId: 't1',
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureFlag: departureFlag,
      arrivalFlag: arrivalFlag,
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
        isProAccount: isProAccount,
        kycVerified: kycVerified,
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
      // Carte vue par l'expéditeur : prix au kilo affiché = net × 1,12
      // (12 €/kg net → 13,44 €/kg commission Dony incluse).
      expect(find.text('13.44 €/kg'), findsOneWidget);
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

    testWidgets('shows PRO badge when isProAccount is true', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('does NOT show PRO badge when isProAccount is false',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: false),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('avatar shows gold verified badge when pro + kycVerified',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: true, kycVerified: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      final goldIcons = tester.widgetList<DonyIcon>(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check')).where(
        (icon) => icon.color == const Color(0xFFF0B829),
      );
      expect(goldIcons, isNotEmpty);
    });

    testWidgets('avatar shows blue verified badge when kycVerified but NOT pro',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: false, kycVerified: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      final blueIcons = tester.widgetList<DonyIcon>(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check')).where(
        (icon) => icon.color != const Color(0xFFF0B829),
      );
      expect(blueIcons, isNotEmpty);
    });

    testWidgets(
        'own card shows pill, chevron and is tappable when isOwnAnnouncement',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: true,
        onTap: () => tapped = true,
      )));
      await tester.pumpAndSettle();

      // Pill « Votre trajet » présent (key + texte).
      expect(find.byKey(const Key('own-trip-pill')), findsOneWidget);
      expect(find.text('Votre trajet'), findsOneWidget);

      // Chevron de cliquabilité sur le corridor.
      final chevrons = tester.widgetList<DonyIcon>(find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'chevron-right',
      ));
      expect(chevrons, isNotEmpty);

      // La carte propriétaire est désormais cliquable.
      await tester.tap(find.byType(TravelerCard));
      expect(tapped, isTrue);
    });

    testWidgets('does NOT show own-trip pill when isOwnAnnouncement is false',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('own-trip-pill')), findsNothing);
      expect(find.text('Votre trajet'), findsNothing);
      final chevrons = tester.widgetList<DonyIcon>(find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'chevron-right',
      ));
      expect(chevrons, isEmpty);
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

  group('TravelerCard – trajet (route header)', () {
    testWidgets('affiche les villes départ et arrivée', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(departureCity: 'Lyon', arrivalCity: 'Abidjan'),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Abidjan'), findsOneWidget);
    });

    testWidgets('retombe sur cityFlag quand le drapeau backend est absent',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      // Paris → 🇫🇷, Dakar → 🇸🇳 via la map locale cityFlag().
      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('🇸🇳'), findsOneWidget);
    });

    testWidgets('privilégie le drapeau résolu par le backend', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(
          departureCity: 'Tombouctou-les-Bains', // inconnu de cityFlag
          departureFlag: '🇲🇱',
          arrivalFlag: '🇸🇳',
        ),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('🇲🇱'), findsOneWidget);
      expect(find.text('🇸🇳'), findsOneWidget);
    });

    testWidgets('appui réduit légèrement la carte (scale < 1)', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(TravelerCard)));
      await tester.pump(const Duration(milliseconds: 200));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
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

  group('TravelerCard – existingBidStatus', () {
    const chipKey = Key('traveler-card-existing-bid-chip');

    testWidgets('affiche le chip "Demande en attente" pour status PENDING',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'PENDING',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande en attente'), findsOneWidget);
    });

    testWidgets('affiche le chip "Demande acceptée" pour status ACCEPTED',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'ACCEPTED',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande acceptée'), findsOneWidget);
    });

    testWidgets(
        'PAYMENT_ESCROWED reste "Demande en attente" (paiement séquestré, non accepté)',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'PAYMENT_ESCROWED',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande en attente'), findsOneWidget);
      expect(find.text('Demande acceptée'), findsNothing);
    });

    testWidgets("n'affiche pas le chip quand existingBidStatus est null",
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsNothing);
    });
  });
}
