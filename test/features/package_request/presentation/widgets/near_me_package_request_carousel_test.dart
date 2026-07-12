import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/near_me_package_request_carousel.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_carousel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item(String id, String city) =>
    PackageRequestSearchItem(
      id: id,
      departureCity: city,
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      categories: const ['Vêtements'],
      targetPriceEur: 35,
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
    home: Scaffold(body: SizedBox(height: 260, child: child)),
  );

  group('NearMePackageRequestCarousel', () {
    testWidgets('items vides → empty state avec bouton "Élargir la zone"', (
      tester,
    ) async {
      var seeAllCalled = false;
      await tester.pumpWidget(
        wrap(
          NearMePackageRequestCarousel(
            items: const [],
            userPosition: null,
            onSeeAll: () => seeAllCalled = true,
          ),
        ),
      );
      expect(find.text('Aucune demande à proximité'), findsOneWidget);
      expect(find.text('Élargir la zone'), findsOneWidget);
      await tester.tap(find.text('Élargir la zone'));
      await tester.pump();
      expect(seeAllCalled, isTrue);
    });

    testWidgets('items N → PageView rend N cards + bouton "Voir les N"', (
      tester,
    ) async {
      final items = [
        _item('1', 'Paris'),
        _item('2', 'Lyon'),
        _item('3', 'Marseille'),
      ];
      await tester.pumpWidget(
        wrap(
          NearMePackageRequestCarousel(
            items: items,
            userPosition: null,
            onSeeAll: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PackageRequestCarouselCard), findsWidgets);
      expect(find.text('Voir les 3 demandes'), findsOneWidget);
    });

    testWidgets('onSeeAll appelé au tap sur le bouton', (tester) async {
      var called = false;
      await tester.pumpWidget(
        wrap(
          NearMePackageRequestCarousel(
            items: [_item('1', 'Paris')],
            userPosition: null,
            onSeeAll: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Pour une seule demande, le widget affiche le libellé singulier.
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });
}
