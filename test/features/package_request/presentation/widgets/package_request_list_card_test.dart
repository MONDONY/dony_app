import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item({
  ContentCategory category = ContentCategory.vetements,
  ParcelSize size = ParcelSize.medium,
  double? targetPrice = 35,
  String? photoUrl,
  bool kycVerified = true,
  double rating = 4.9,
  int totalRatings = 12,
}) =>
    PackageRequestSearchItem(
      id: 'pr1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: size,
      contentCategory: category,
      targetPriceEur: targetPrice,
      photoUrl: photoUrl,
      sender: SenderPublicProfile(
        id: 's1',
        displayName: 'Marie Diop',
        averageRating: rating,
        totalRatings: totalRatings,
        kycVerified: kycVerified,
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

  group('PackageRequestListCard', () {
    testWidgets('rend le corridor + date + catégorie + prix', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('35 €'), findsOneWidget);
      expect(find.textContaining('Vêtements'), findsOneWidget);
    });

    testWidgets('rend "Libre" quand pas de targetPriceEur', (tester) async {
      await tester
          .pumpWidget(wrap(PackageRequestListCard(item: _item(targetPrice: null))));
      await tester.pumpAndSettle();
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('35 €'), findsNothing);
    });

    testWidgets('rend la catégorie Médicaments (isUrgent coloring)',
        (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(category: ContentCategory.medicaments),
      )));
      await tester.pumpAndSettle();
      // Le widget utilise un style coloré (error) pour la catégorie urgente
      // au lieu d'un badge textuel "URGENT"
      expect(find.textContaining('Médicaments'), findsOneWidget);
    });

    testWidgets('pas de badge URGENT pour les autres catégories',
        (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(category: ContentCategory.vetements),
      )));
      await tester.pumpAndSettle();
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('rend le badge S/M/L + poids dans le hero', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(size: ParcelSize.small),
      )));
      await tester.pumpAndSettle();
      expect(find.text('S'), findsOneWidget);
      expect(find.text('5 kg'), findsOneWidget);
    });

    testWidgets('rend sender avec KYC verified', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Marie Diop'), findsOneWidget);
      // DonyAvatar superpose 2 icônes verified_rounded (blanc + couleur)
      expect(find.byIcon(Icons.verified_rounded), findsWidgets);
      expect(find.text('4.9'), findsOneWidget);
    });

    testWidgets('pas d\'icône KYC quand non vérifié', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(kycVerified: false),
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
    });

    testWidgets('tap → callback onTap invoqué', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(),
        onTap: () => tapped = true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris → Dakar'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('accepte onMakeOffer sans planter le rendu',
        (tester) async {
      // Le bouton "Faire une offre" a été retiré du widget mais la propriété
      // est conservée pour la compatibilité avec les appelants.
      await tester.pumpWidget(wrap(PackageRequestListCard(
        item: _item(),
        onMakeOffer: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('pas de CTA quand onMakeOffer null', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsNothing);
    });
  });
}
