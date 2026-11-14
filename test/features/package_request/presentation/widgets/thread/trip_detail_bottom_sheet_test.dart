import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/plane_icon_expectations.dart';

LinkedTripSummary _trip({
  String? date,
  String? time,
  String? mode,
  String? pickupLabel,
  String? deliveryLabel,
  String? description,
  int availableKg = 10,
}) => LinkedTripSummary(
  announcementId: 'ann-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: date,
  departureTime: time,
  transportMode: mode ?? 'PLANE',
  pickupAddressLabel: pickupLabel,
  deliveryAddressLabel: deliveryLabel,
  availableKg: availableKg,
  description: description,
);

Widget _buildApp(
  LinkedTripSummary trip, {
  bool isSender = false,
  double? parcelWeightKg,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Builder(
      builder: (ctx) => ElevatedButton(
        key: const Key('open'),
        onPressed: () => TripDetailBottomSheet.show(
          ctx,
          trip: trip,
          isSender: isSender,
          parcelWeightKg: parcelWeightKg,
        ),
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

    testWidgets(
      'fr : rendu historique du mois abrégé sans point (« 6 oct 2026 »)',
      (tester) async {
        await tester.pumpWidget(_buildApp(_trip(date: '2026-10-06')));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        expect(find.text('6 oct 2026'), findsOneWidget);
      },
    );

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

    testWidgets(
      'parcel weight shown, empty trip capacity hidden (FLUTTER-Q3)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(_trip(availableKg: 0), parcelWeightKg: 4.5),
        );
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        expect(find.text('Poids du colis'), findsOneWidget);
        expect(find.text('4,5 kg'), findsOneWidget);
        expect(find.text('Poids disponible'), findsNothing);
        expect(find.text('0 kg'), findsNothing);
      },
    );

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

    Future<void> openWithMode(WidgetTester tester, String mode) async {
      await tester.pumpWidget(_buildApp(_trip(mode: mode)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('PLANE : icône avion', (tester) async {
      await openWithMode(tester, 'PLANE');
      expect(findDonyIcon('plane'), findsOneWidget);
    });

    testWidgets('BOAT : icône bateau, plus le colis 📦', (tester) async {
      await openWithMode(tester, 'BOAT');
      expect(findDonyIcon('ship'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('CAR : icône voiture', (tester) async {
      await openWithMode(tester, 'CAR');
      expect(findDonyIcon('car'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('BUS : icône voiture', (tester) async {
      await openWithMode(tester, 'BUS');
      expect(findDonyIcon('car'), findsOneWidget);
    });

    testWidgets('TRAIN ou mode inconnu : icône neutre route', (tester) async {
      await openWithMode(tester, 'TRAIN');
      expect(findDonyIcon('route'), findsOneWidget);
      expectNoPlaneIcon(tester);
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

  group('en anglais', () {
    testWidgets('titre, adresses et bouton de refus traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _buildApp(
          _trip(pickupLabel: '10 rue Rivoli', deliveryLabel: 'Aéroport DSS'),
          isSender: true,
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Linked trip'), findsOneWidget);
      expect(find.text('Drop-off address'), findsOneWidget);
      expect(find.text('Delivery address'), findsOneWidget);
      expect(find.text('Decline this trip'), findsOneWidget);
    });

    testWidgets('en : la date passe par DateFormat.yMMMd', (tester) async {
      useEnglish();
      await tester.pumpWidget(_buildApp(_trip(date: '2026-10-06')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(
        find.text(DateFormat.yMMMd('en').format(DateTime(2026, 10, 6))),
        findsOneWidget,
      );
    });
  });
}
