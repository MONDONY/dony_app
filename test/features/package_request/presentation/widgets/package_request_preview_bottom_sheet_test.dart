import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item({
  double? targetPriceEur = 50.0,
  String? pickupNeighborhood,
  String? deliveryNeighborhood,
  bool kycVerified = true,
  int tolerance = 2,
}) =>
    PackageRequestSearchItem(
      id: 'pr-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: tolerance,
      weightKg: 5.0,
      parcelSize: ParcelSize.medium,
      contentCategory: ContentCategory.vetements,
      targetPriceEur: targetPriceEur,
      pickupNeighborhood: pickupNeighborhood,
      deliveryNeighborhood: deliveryNeighborhood,
      sender: SenderPublicProfile(
        id: 'sender-1',
        displayName: 'Fatou Diallo',
        averageRating: 4.8,
        totalRatings: 12,
        kycVerified: kycVerified,
      ),
    );

Widget _buildApp(PackageRequestSearchItem item, {bool isOwnRequest = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () => PackageRequestPreviewBottomSheet.show(
              ctx,
              item: item,
              isOwnRequest: isOwnRequest,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('PackageRequestPreviewBottomSheet', () {
    testWidgets('shows departure and arrival cities', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Paris'), findsWidgets);
      expect(find.text('Dakar'), findsWidgets);
    });

    testWidgets('shows price badge when targetPriceEur is set', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(targetPriceEur: 50.0)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('50 €'), findsOneWidget);
    });

    testWidgets('shows "Libre" price badge when no targetPriceEur',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(targetPriceEur: null)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Libre'), findsOneWidget);
    });

    testWidgets('shows date with tolerance', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(tolerance: 2)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('±2j'), findsOneWidget);
    });

    testWidgets('shows sender name', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Fatou Diallo'), findsOneWidget);
    });

    testWidgets('shows weight info tile', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('5 kg'), findsOneWidget);
    });

    testWidgets('shows "Faire une offre" button when not own request',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(), isOwnRequest: false));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsOneWidget);
    });

    testWidgets('hides "Faire une offre" button when own request',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(), isOwnRequest: true));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsNothing);
    });

    testWidgets('shows pickupNeighborhood label "Remise" when provided',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _buildApp(_item(pickupNeighborhood: 'Montmartre')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Remise'), findsOneWidget);
      expect(find.text('Montmartre'), findsOneWidget);
    });

    testWidgets('shows "Non précisé" when no neighborhood info',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.text('Non précisé'), findsOneWidget);
    });

    testWidgets('shows no tolerance suffix when tolerance=0', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(_item(tolerance: 0)));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('±'), findsNothing);
    });
  });
}
