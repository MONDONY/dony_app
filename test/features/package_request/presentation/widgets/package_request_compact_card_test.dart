import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_compact_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item({
  ContentCategory category = ContentCategory.vetements,
  double? targetPrice = 35,
}) =>
    PackageRequestSearchItem(
      id: 'pr1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      contentCategory: category,
      targetPriceEur: targetPrice,
      sender: const SenderPublicProfile(
        id: 's1',
        displayName: 'Marie',
        averageRating: 4.9,
        totalRatings: 12,
        kycVerified: true,
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr', null);
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 360, child: child),
          ),
        ),
      );

  group('PackageRequestCompactCard', () {
    testWidgets('rend le corridor + distance + prix', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestCompactCard(
        item: _item(),
        distanceLabel: '450 m',
      )));
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('35 €'), findsOneWidget);
    });

    testWidgets('tap → onTap callback invoqué', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(PackageRequestCompactCard(
        item: _item(),
        distanceLabel: '1.2 km',
        onTap: () => tapped = true,
      )));
      await tester.tap(find.text('Paris → Dakar'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CTA "Faire offre" visible quand onMakeOffer fourni',
        (tester) async {
      await tester.pumpWidget(wrap(PackageRequestCompactCard(
        item: _item(),
        distanceLabel: '1 km',
        onMakeOffer: () {},
      )));
      expect(find.text('Faire offre'), findsOneWidget);
    });

    testWidgets('rend ⚡ urgent badge si medicaments', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestCompactCard(
        item: _item(category: ContentCategory.medicaments),
        distanceLabel: '500 m',
      )));
      expect(find.text('⚡'), findsOneWidget);
    });
  });
}
