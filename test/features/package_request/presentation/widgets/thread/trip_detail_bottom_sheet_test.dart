import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LinkedTripSummary _trip({
  String? date,
  String? time,
  String? mode,
  String? pickupLabel,
  String? deliveryLabel,
  String? description,
}) => LinkedTripSummary(
  announcementId: 'ann-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: date,
  departureTime: time,
  transportMode: mode ?? 'PLANE',
  pickupAddressLabel: pickupLabel,
  deliveryAddressLabel: deliveryLabel,
  availableKg: 10,
  description: description,
);

Widget _buildApp(LinkedTripSummary trip, {bool isSender = false}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () =>
                TripDetailBottomSheet.show(ctx, trip: trip, isSender: isSender),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

void main() {
  group('TripDetailBottomSheet', () {
    testWidgets('shows corridor Paris → Dakar', (tester) async {
      await tester.pumpWidget(_buildApp(_trip()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('shows "Trajet lié" title', (tester) async {
      await tester.pumpWidget(_buildApp(_trip()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Trajet lié'), findsOneWidget);
    });

    testWidgets('shows departure date when provided', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(date: '2026-08-15')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Date de départ'), findsOneWidget);
    });

    testWidgets('shows departure time when provided', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(time: '10:30')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('shows available kg', (tester) async {
      await tester.pumpWidget(_buildApp(_trip()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('10 kg'), findsOneWidget);
    });

    testWidgets('shows pickup address when provided', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(pickupLabel: '10 rue Rivoli')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Adresse de remise'), findsOneWidget);
      expect(find.text('10 rue Rivoli'), findsOneWidget);
    });

    testWidgets('shows delivery address when provided', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(deliveryLabel: 'Aéroport DSS')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Adresse de livraison'), findsOneWidget);
      expect(find.text('Aéroport DSS'), findsOneWidget);
    });

    testWidgets('shows description when provided', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(description: 'Ma note')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Note du voyageur'), findsOneWidget);
      expect(find.text('Ma note'), findsOneWidget);
    });

    testWidgets('shows Refuser button when isSender=true', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(), isSender: true));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Refuser ce trajet'), findsOneWidget);
    });

    testWidgets('hides Refuser button when isSender=false', (tester) async {
      await tester.pumpWidget(_buildApp(_trip()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Refuser ce trajet'), findsNothing);
    });

    testWidgets('shows train icon for TRAIN mode', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(mode: 'TRAIN')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('🚄'), findsOneWidget);
    });

    testWidgets('shows car icon for CAR mode', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(mode: 'CAR')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('🚗'), findsOneWidget);
    });

    testWidgets('shows plane icon for PLANE mode', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(mode: 'PLANE')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('✈️'), findsOneWidget);
    });

    testWidgets('shows default icon for unknown mode', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(mode: 'BOAT')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('📦'), findsOneWidget);
    });

    testWidgets('tapping Refuser opens confirmation sheet', (tester) async {
      await tester.pumpWidget(_buildApp(_trip(), isSender: true));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refuser ce trajet'));
      await tester.pumpAndSettle();
      expect(
        find.text('Refuser ce trajet'),
        findsOneWidget,
      ); // confirmation title
      expect(find.text('Confirmer le refus'), findsOneWidget);
    });
  });
}
