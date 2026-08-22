import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequestSearchItem _item({
  String categoryLabel = 'Vêtements & tissus',
  ParcelSize size = ParcelSize.medium,
  double? targetPrice = 35,
  double? grossPrice,
  String? photoUrl,
  List<String> photoUrls = const [],
  bool kycVerified = true,
  double rating = 4.9,
  int totalRatings = 12,
  DateTime? desiredDate,
  bool? urgent,
  int? matchScore,
  String? matchedTripId,
  DateTime? matchedTripDepartureDate,
}) => PackageRequestSearchItem(
  id: 'pr1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: desiredDate ?? DateTime(2026, 6, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: size,
  categories: [categoryLabel],
  targetPriceEur: targetPrice,
  grossPriceEur: grossPrice,
  photoUrl: photoUrl,
  photoUrls: photoUrls,
  urgent: urgent,
  matchScore: matchScore,
  matchedTripId: matchedTripId,
  matchedTripDepartureDate: matchedTripDepartureDate,
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
    await initializeDateFormatting('fr');
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
    ),
  );

  group('PackageRequestListCard', () {
    testWidgets(
      'identité ticket : micro-label + titre colis + trajet + budget',
      (tester) async {
        await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
        await tester.pumpAndSettle();
        expect(find.text('Demande d\'envoi'), findsOneWidget);
        expect(find.text('5 kg · Vêtements & tissus · M'), findsOneWidget);
        expect(find.textContaining('Paris → Dakar'), findsOneWidget);
        expect(find.textContaining('35'), findsWidgets);
        expect(find.textContaining('€'), findsWidgets);
      },
    );

    testWidgets('chip statut « Ouverte » par défaut', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Ouverte', skipOffstage: false), findsOneWidget);
    });

    testWidgets('chip statut reflète le statut passé', (tester) async {
      await tester.pumpWidget(
        wrap(
          PackageRequestListCard(
            item: _item(),
            status: PackageRequestStatus.negotiating,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('En négociation'), findsOneWidget);
    });

    testWidgets('isOwnRequest → chip « Ma demande » au lieu du statut', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(), isOwnRequest: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ma demande'), findsOneWidget);
      expect(find.text('Ouverte'), findsNothing);
    });

    testWidgets('rend « Budget libre » quand pas de targetPriceEur', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(targetPrice: null))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Budget libre'), findsOneWidget);
      expect(find.text('35 €'), findsNothing);
    });

    testWidgets(
      'affiche le brut (grossPriceEur) au lieu du net quand le serveur le fournit',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            PackageRequestListCard(
              item: _item(targetPrice: 35, grossPrice: 40),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('40'), findsWidgets);
        // Jamais les deux montants côte à côte (révélerait la commission).
        expect(find.textContaining('35'), findsNothing);
      },
    );

    testWidgets(
      'retombe sur le net (targetPriceEur) quand grossPriceEur est absent (ancien payload)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            PackageRequestListCard(item: _item(targetPrice: 35, grossPrice: null)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('35'), findsWidgets);
      },
    );

    testWidgets('badge compteur photos quand plusieurs photos', (tester) async {
      await tester.pumpWidget(
        wrap(
          PackageRequestListCard(item: _item(photoUrls: const ['a', 'b', 'c'])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('📷 3'), findsOneWidget);
    });

    testWidgets('catégorie Médicaments rendue dans le titre', (tester) async {
      await tester.pumpWidget(
        wrap(
          PackageRequestListCard(
            item: _item(categoryLabel: 'Médicaments traditionnels'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Médicaments'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('rend sender avec KYC verified', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Marie Diop'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsWidgets,
      );
      expect(find.text('4.9'), findsOneWidget);
    });

    testWidgets('pas d\'icône KYC quand non vérifié', (tester) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(kycVerified: false))),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsNothing,
      );
    });

    testWidgets('tap → callback onTap invoqué', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(), onTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 kg · Vêtements & tissus · M'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('accepte onMakeOffer sans planter le rendu', (tester) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(), onMakeOffer: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 kg · Vêtements & tissus · M'), findsOneWidget);
    });

    testWidgets('pas de CTA « Faire une offre »', (tester) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();
      expect(find.text('Faire une offre'), findsNothing);
    });
  });

  group('PackageRequestListCard – badge urgent', () {
    testWidgets('affiche le badge Urgent quand item.isUrgent', (tester) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(urgent: true))),
      );
      await tester.pumpAndSettle();
      expect(find.text('🔥 Urgent'), findsOneWidget);
    });

    testWidgets('pas de badge Urgent si item.isUrgent est faux', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(urgent: false))),
      );
      await tester.pumpAndSettle();
      expect(find.text('🔥 Urgent'), findsNothing);
    });
  });

  // ─── Score de compatibilité (filtre « Pour mes trajets ») ──────────────────
  group('PackageRequestListCard – score de match', () {
    testWidgets('affiche le score et le trajet retenu', (tester) async {
      await tester.pumpWidget(
        wrap(
          PackageRequestListCard(
            item: _item(
              matchScore: 94,
              matchedTripId: 'trip-1',
              matchedTripDepartureDate: DateTime(2026, 7, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('match-score-badge')), findsOneWidget);
      expect(find.text('94 %'), findsOneWidget);
      expect(find.textContaining('12 juil.'), findsOneWidget);
    });

    testWidgets('sans matchScore : aucun badge, la carte reste intacte', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(PackageRequestListCard(item: _item())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('match-score-badge')), findsNothing);
      // Le rendu nominal n'est pas dégradé par l'absence des champs de match.
      expect(find.text('5 kg · Vêtements & tissus · M'), findsOneWidget);
    });

    testWidgets('score sans date de trajet : le badge s\'affiche seul', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PackageRequestListCard(item: _item(matchScore: 61))),
      );
      await tester.pumpAndSettle();

      expect(find.text('61 %'), findsOneWidget);
      expect(find.textContaining('Ton trajet du'), findsNothing);
    });

    testWidgets('le libellé du trajet ne contient jamais de tiret cadratin', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PackageRequestListCard(
            item: _item(
              matchScore: 80,
              matchedTripDepartureDate: DateTime(2026, 7, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final libelle = tester
          .widget<Text>(find.textContaining('12 juil.'))
          .data!;
      expect(libelle, isNot(contains('—')));
    });
  });
}
