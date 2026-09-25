import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/l10n_test_helpers.dart';

TripMatchModel _trip() => TripMatchModel(
  announcementId: 'ann-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7, 10),
  travelerId: 't-1',
  travelerName: 'Awa S.',
  travelerInitials: 'AS',
  travelerRating: 4.7,
  availableKg: 12.0,
  pricePerKg: 9.5,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
  });

  testWidgets('renders corridor, traveler, kg and price', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TripMatchCard(
            match: _trip(),
            index: 0,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Paris'), findsWidgets);
    expect(find.textContaining('Dakar'), findsWidgets);
    expect(find.text('Awa S.'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets); // kg dispo
    await tester.tap(find.byType(TripMatchCard));
    expect(tapped, isTrue);
  });

  testWidgets(
    'date de départ — fr : motif inchangé (DateFormat.MMMd == ancien \'d MMM\')',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TripMatchCard(match: _trip(), index: 0)),
        ),
      );
      await tester.pumpAndSettle();
      // DateTime(2026, 7, 10) → ancien DateFormat('d MMM', 'fr') rendait déjà
      // « 10 juil. » ; DateFormat.MMMd('fr') rend le même texte (vérifié hors
      // widget avec intl 0.20.2).
      expect(find.text('10 juil.'), findsOneWidget);
    },
  );

  testWidgets('date de départ — anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripMatchCard(match: _trip(), index: 0)),
      ),
    );
    await tester.pumpAndSettle();
    // DateFormat.MMMd('en').format(...) → 'Jul 10'.
    expect(find.text('Jul 10'), findsOneWidget);
  });

  testWidgets('renders price per kg', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripMatchCard(match: _trip(), index: 0)),
      ),
    );
    await tester.pumpAndSettle();
    // pricePerKg = 9.5 → '9 €/kg'
    expect(find.textContaining('€/kg'), findsWidgets);
  });

  testWidgets('renders Prix libre when pricePerKg is null', (tester) async {
    final trip = TripMatchModel(
      announcementId: 'ann-2',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      departureDate: DateTime(2026, 8),
      travelerId: 't-2',
      travelerName: 'Kofi B.',
      travelerInitials: 'KB',
      travelerRating: 4.2,
      availableKg: 8.0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripMatchCard(match: trip, index: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Prix libre'), findsOneWidget);
  });

  testWidgets('anglais : « Trajet disponible » et prix libre traduits', (
    tester,
  ) async {
    useEnglish();
    final trip = TripMatchModel(
      announcementId: 'ann-3',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      departureDate: DateTime(2026, 8),
      travelerId: 't-3',
      travelerName: 'Kofi B.',
      travelerInitials: 'KB',
      travelerRating: 4.2,
      availableKg: 8.0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripMatchCard(match: trip, index: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip available'), findsOneWidget);
    expect(find.text('Open price'), findsOneWidget);
    expect(find.text('8 kg available'), findsOneWidget);
  });

  testWidgets('renders traveler rating', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripMatchCard(match: _trip(), index: 0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('4.7'), findsWidgets);
  });
}
