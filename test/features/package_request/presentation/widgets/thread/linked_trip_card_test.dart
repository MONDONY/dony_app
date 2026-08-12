import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/linked_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    testWidgets('displays date and availableKg', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(date: '2026-08-15'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('2026-08-15'), findsOneWidget);
      expect(find.textContaining('10 kg'), findsOneWidget);
    });

    testWidgets('displays « Kg libre » for KG_FREE capacity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(capacityUnit: 'KG_FREE'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Kg libre'), findsOneWidget);
      expect(find.textContaining('10 kg'), findsNothing);
    });

    testWidgets('displays plane icon for PLANE mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(mode: 'PLANE'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('✈'), findsOneWidget);
    });

    testWidgets('displays train icon for TRAIN mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(mode: 'TRAIN'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('🚄'), findsOneWidget);
    });

    testWidgets('displays car icon for CAR mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(mode: 'CAR'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('🚗'), findsOneWidget);
    });

    testWidgets('displays default icon for unknown mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedTripCard(
            trip: _trip(mode: 'BOAT'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('📦'), findsOneWidget);
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

    testWidgets('shows null date as empty string', (tester) async {
      final trip = LinkedTripSummary(
        announcementId: 'ann-2',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        transportMode: 'PLANE',
        availableKg: 5,
      );
      await tester.pumpWidget(_wrap(LinkedTripCard(trip: trip, onTap: () {})));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('5 kg'), findsOneWidget);
    });
  });
}
