import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/l10n_test_helpers.dart';

TripMatchModel _trip({double availableKg = 12.0, String? status}) =>
    TripMatchModel(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 7, 10),
      travelerId: 't-1',
      travelerName: 'Awa S.',
      travelerInitials: 'AS',
      travelerRating: 4.7,
      availableKg: availableKg,
      pricePerKg: 9.5,
      status: status,
    );

Future<void> _pump(
  WidgetTester tester,
  TripMatchModel match, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TripMatchCard(match: match, index: 0, onTap: onTap),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _cardOpacity(WidgetTester tester) {
  final opacities = tester.widgetList<Opacity>(
    find.descendant(
      of: find.byType(TripMatchCard),
      matching: find.byType(Opacity),
    ),
  );
  return opacities.fold(1.0, (acc, o) => acc * o.opacity);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  group('trajet complet (FLUTTER-EW)', () {
    testWidgets('0 kg : « Complet », pas de « 0 kg dispo », grisée, tap sans '
        'effet', (tester) async {
      var tapped = false;
      await _pump(tester, _trip(availableKg: 0), onTap: () => tapped = true);

      expect(find.text('Complet'), findsOneWidget);
      expect(find.text('Trajet disponible'), findsNothing);
      expect(find.textContaining('kg dispo'), findsNothing);
      // La carte reste affichée avec ses informations.
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Awa S.'), findsOneWidget);
      expect(_cardOpacity(tester), closeTo(TripMatchCard.fullOpacity, 0.001));

      await tester.tap(find.byType(TripMatchCard), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(TripMatchCard),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('kg négatif traité comme complet', (tester) async {
      await _pump(tester, _trip(availableKg: -1));
      expect(find.text('Complet'), findsOneWidget);
    });

    testWidgets('kg > 0 : inchangé (disponible, opaque, tapable)', (
      tester,
    ) async {
      var tapped = false;
      await _pump(tester, _trip(), onTap: () => tapped = true);

      expect(find.text('Trajet disponible'), findsOneWidget);
      expect(find.text('12 kg dispo'), findsOneWidget);
      expect(find.text('Complet'), findsNothing);
      expect(_cardOpacity(tester), 1.0);
      expect(find.bySemanticsLabel(RegExp('Trajet complet')), findsNothing);

      await tester.tap(find.byType(TripMatchCard));
      expect(tapped, isTrue);
    });

    testWidgets('statut FULL avec kg restants : complet quand même', (
      tester,
    ) async {
      var tapped = false;
      await _pump(
        tester,
        _trip(availableKg: 5, status: 'FULL'),
        onTap: () => tapped = true,
      );

      expect(find.text('Complet'), findsOneWidget);
      expect(find.textContaining('kg dispo'), findsNothing);
      expect(_cardOpacity(tester), closeTo(TripMatchCard.fullOpacity, 0.001));
      await tester.tap(find.byType(TripMatchCard), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('statut OPEN avec kg restants : disponible', (tester) async {
      await _pump(tester, _trip(status: 'OPEN'));
      expect(find.text('Trajet disponible'), findsOneWidget);
      expect(find.text('Complet'), findsNothing);
    });

    testWidgets('accessibilité : libellé « Trajet complet »', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _trip(availableKg: 0));
      expect(find.bySemanticsLabel(RegExp('Trajet complet')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('anglais : « Full » et libellé « Trip full »', (tester) async {
      useEnglish();
      final handle = tester.ensureSemantics();
      await _pump(tester, _trip(availableKg: 0));

      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Trip available'), findsNothing);
      expect(find.textContaining('kg available'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Trip full')), findsOneWidget);
      handle.dispose();
    });
  });
}
