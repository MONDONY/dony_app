import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_carousel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

PackageRequestSearchItem _item({
  double? targetPrice = 35,
  String? displayName = 'Amina',
}) => PackageRequestSearchItem(
  id: 'pr-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 10, 6),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  categories: const ['Vêtements'],
  targetPriceEur: targetPrice,
  sender: SenderPublicProfile(
    id: 's-1',
    displayName: displayName,
    averageRating: 4.9,
    totalRatings: 12,
    kycVerified: true,
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SizedBox(width: 220, height: 320, child: child)),
  );

  testWidgets('en français : prix libre et chip « Ma demande »', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PackageRequestCarouselCard(
          item: _item(targetPrice: null),
          index: 0,
          isOwnRequest: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Libre'), findsOneWidget);
    expect(find.text('Ma demande'), findsOneWidget);
  });

  testWidgets('en anglais : prix libre, chip et nom de repli traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        PackageRequestCarouselCard(
          item: _item(targetPrice: null, displayName: null),
          index: 0,
          isOwnRequest: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('My request'), findsOneWidget);
    expect(find.text('Yadony user'), findsOneWidget);
    expect(find.text('Libre'), findsNothing);
    expect(find.text('Ma demande'), findsNothing);
  });
}
