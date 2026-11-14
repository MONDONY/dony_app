import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/linked_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/plane_icon_expectations.dart';

LinkedTripSummary _trip({
  String mode = 'PLANE',
  String? date,
  String? capacityUnit,
}) => LinkedTripSummary(
  announcementId: 'ann-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: date ?? '2026-08-15',
  transportMode: mode,
  availableKg: 10,
  capacityUnit: capacityUnit,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('LinkedTripCard', () {
    testWidgets('displays departure and arrival cities', (tester) async {
      await tester.pumpWidget(
        _wrap(LinkedTripCard(trip: _trip(), onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('formats the date and shows the parcel weight (FLUTTER-Q3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(date: '2026-08-15'),
            parcelWeightKg: 5,
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('2026-08-15'), findsNothing);
      expect(find.text('sam. 15 août · Colis de 5 kg'), findsOneWidget);
      // Le poids restant du trajet n'est plus affiché : il valait 0 pour un
      // trajet dédié et laissait croire à un colis de 0 kg.
      expect(find.textContaining('10 kg'), findsNothing);
    });

    testWidgets('date only when the parcel weight is unknown', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(capacityUnit: 'KG_FREE'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('sam. 15 août'), findsOneWidget);
    });

    Future<void> pumpMode(WidgetTester tester, String? mode) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: LinkedTripSummary(
              announcementId: 'ann-1',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
              transportMode: mode,
              availableKg: 10,
            ),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('PLANE : icône avion', (tester) async {
      await pumpMode(tester, 'PLANE');
      expect(findDonyIcon('plane'), findsOneWidget);
    });

    testWidgets('BOAT : icône bateau, plus le colis 📦', (tester) async {
      await pumpMode(tester, 'BOAT');
      expect(findDonyIcon('ship'), findsOneWidget);
      expect(find.text('📦'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('CAR : icône voiture', (tester) async {
      await pumpMode(tester, 'CAR');
      expect(findDonyIcon('car'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('BUS : icône voiture (le bus est la route)', (tester) async {
      await pumpMode(tester, 'BUS');
      expect(findDonyIcon('car'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('TRAIN, mode inconnu ou absent : icône neutre route', (
      tester,
    ) async {
      for (final mode in ['TRAIN', 'ROCKET', null]) {
        await pumpMode(tester, mode);
        expect(findDonyIcon('route'), findsOneWidget, reason: '$mode');
        expectNoPlaneIcon(tester);
      }
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(LinkedTripCard(trip: _trip(), onTap: () => tapped = true)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('no date: only the parcel weight', (tester) async {
      const trip = LinkedTripSummary(
        announcementId: 'ann-2',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        transportMode: 'PLANE',
        availableKg: 0,
      );
      await tester.pumpWidget(
        _wrap(LinkedTripCard(trip: trip, parcelWeightKg: 5, onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Colis de 5 kg'), findsOneWidget);
    });

    testWidgets('en anglais : date et poids du colis traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(LinkedTripCard(trip: _trip(), parcelWeightKg: 2.5, onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Sat, Aug 15'), findsOneWidget);
      expect(find.textContaining('Parcel: 2.5 kg'), findsOneWidget);
    });
  });
}
