import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item({
  double? targetPriceEur = 35.0,
  bool negotiable = true,
}) =>
    PackageRequestSearchItem(
      id: 'pr-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      contentCategory: ContentCategory.vetements,
      targetPriceEur: targetPriceEur,
      negotiable: negotiable,
      sender: const SenderPublicProfile(
        id: 'sender-1',
        displayName: 'Fatou Diallo',
        averageRating: 4.8,
        totalRatings: 12,
        kycVerified: true,
      ),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('fr', null));

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 360, child: child),
          ),
        ),
      );

  group('PackageRequestCard CTA', () {
    testWidgets('shows "Faire une offre" when negotiable', (tester) async {
      await tester.pumpWidget(
          wrap(PackageRequestCard(item: _item(negotiable: true), index: 0)));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsOneWidget);
      expect(find.textContaining('Prendre à'), findsNothing);
    });

    testWidgets(
        'shows "Prendre à …" (not "Faire une offre") when firm price',
        (tester) async {
      await tester.pumpWidget(wrap(PackageRequestCard(
        item: _item(negotiable: false, targetPriceEur: 35.0),
        index: 0,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsNothing);
      expect(find.text('Prendre à 35,00 €'), findsOneWidget);
    });

    testWidgets('falls back to "Faire une offre" when firm but no price',
        (tester) async {
      await tester.pumpWidget(wrap(PackageRequestCard(
        item: _item(negotiable: false, targetPriceEur: null),
        index: 0,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsOneWidget);
      expect(find.textContaining('Prendre à'), findsNothing);
    });
  });
}
