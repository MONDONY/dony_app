import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/billet/trip_billet_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/plane_icon_expectations.dart';

AnnouncementModel _trip({TransportMode? mode, TripStops? stops}) =>
    AnnouncementModel(
      id: 'ann-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 12),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 7,
      status: 'ACTIVE',
      transportMode: mode,
      stops: stops,
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
    );

Future<void> _pump(WidgetTester tester, AnnouncementModel announcement) async {
  tester.view.physicalSize = const Size(414, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TripBilletCard(announcement: announcement),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('trajet en route : icône car, villes en clair, ni code ni avion, '
      'ni puce escales', (tester) async {
    await _pump(
      tester,
      _trip(mode: TransportMode.car, stops: TripStops.direct),
    );
    expect(findDonyIcon('car'), findsWidgets);
    expect(find.text('CDG'), findsNothing);
    expect(find.text('DSS'), findsNothing);
    expect(find.byKey(const Key('detail-stops-chip')), findsNothing);
    expectNoPlaneIcon(tester);
  });

  testWidgets('trajet en bateau : icône ship, aucun avion', (tester) async {
    await _pump(tester, _trip(mode: TransportMode.boat));
    expect(findDonyIcon('ship'), findsWidgets);
    expect(find.text('CDG'), findsNothing);
    expectNoPlaneIcon(tester);
  });

  testWidgets('trajet en avion : codes IATA et puce escales', (tester) async {
    await _pump(
      tester,
      _trip(mode: TransportMode.plane, stops: TripStops.direct),
    );
    expect(find.text('CDG'), findsOneWidget);
    expect(find.text('DSS'), findsOneWidget);
    expect(findDonyIcon('plane'), findsWidgets);
    expect(find.byKey(const Key('detail-stops-chip')), findsOneWidget);
  });

  testWidgets('ancien trajet sans mode : avion, escales gardées', (
    tester,
  ) async {
    await _pump(tester, _trip(stops: TripStops.one));
    expect(find.text('CDG'), findsOneWidget);
    expect(findDonyIcon('plane'), findsWidgets);
    expect(find.byKey(const Key('detail-stops-chip')), findsOneWidget);
  });
}
