import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _buildAnnouncement({
  bool kycVerified = false,
  int? totalTrips,
  double? rating,
  String displayName = 'Ibrahima Diallo',
}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(now.year, now.month + 1, 15),
    availableKg: 12,
    totalKg: 20,
    pricePerKg: 8,
    status: 'ACTIVE',
    traveler: TravelerProfile(
      id: 't1',
      displayName: displayName,
      averageRating: rating,
      totalTrips: totalTrips,
      kycVerified: kycVerified,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

Widget _harness({required AnnouncementModel announcement}) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () =>
              showTravelerAnnouncementSheet(ctx, announcement: announcement),
          child: const Text('Ouvrir'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche le titre, le voyageur et le bouton Faire une demande',
      (tester) async {
    final a = _buildAnnouncement(
      kycVerified: true,
      totalTrips: 5,
      rating: 4.8,
    );
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Détail du trajet'), findsOneWidget);
    expect(find.text('Ibrahima Diallo'), findsOneWidget);
    expect(find.text('Faire une demande'), findsOneWidget);
  });

  testWidgets('affiche le badge KYC quand le voyageur est vérifié',
      (tester) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('traveler-kyc-badge')), findsOneWidget);
  });

  testWidgets("n'affiche pas le badge KYC quand le voyageur n'est pas vérifié",
      (tester) async {
    final a = _buildAnnouncement(kycVerified: false);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('traveler-kyc-badge')), findsNothing);
  });

  testWidgets('affiche toujours le nombre de trajets, même à 0',
      (tester) async {
    final a = _buildAnnouncement(totalTrips: 0);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 trajet'), findsOneWidget);
  });

  testWidgets('affiche le pluriel quand totalTrips > 1', (tester) async {
    final a = _buildAnnouncement(totalTrips: 7);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7 trajets'), findsOneWidget);
  });

  testWidgets('le bloc voyageur est tappable pour ouvrir son profil',
      (tester) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 4);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final block = find.byKey(const Key('traveler-block'));
    expect(block, findsOneWidget);
    final inkWell = tester.widget<InkWell>(block);
    expect(inkWell.onTap, isNotNull);
  });
}
