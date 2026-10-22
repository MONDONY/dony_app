import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Carte la plus chargée possible : tout ce qu'elle sait afficher, en même
/// temps, avec des noms longs.
AnnouncementModel _loaded({String travelerId = 't1'}) => AnnouncementModel(
  id: 'a1',
  travelerId: travelerId,
  departureCity: 'Ouagadougou',
  arrivalCity: 'Saint-Denis de la Réunion',
  departureDate: DateTime(2026, 11, 18),
  availableKg: 32,
  totalKg: 40,
  pricePerKg: 2500,
  currency: 'XOF',
  urgent: true,
  uniqueViewerCount: 12,
  stops: TripStops.twoOrMore,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  acceptedContentTypes: const [
    'Documents & administratif',
    'Vêtements & tissus',
    'Médicaments traditionnels',
  ],
  traveler: TravelerProfile(
    id: travelerId,
    displayName: 'Awa Konaté-Diallo-Traoré',
    averageRating: 4.7,
    totalTrips: 21,
    gpPro: true,
    isProAccount: true,
    kycVerified: true,
  ),
);

Widget _wrapAt(double width, double textScale, Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

TravelerCard _card({
  required AnnouncementModel announcement,
  bool compact = true,
  bool own = false,
  String? bidStatus,
  String? distance,
}) => TravelerCard(
  announcement: announcement,
  index: 0,
  isOwnAnnouncement: own,
  existingBidStatus: bidStatus,
  distanceBadge: distance,
  compact: compact,
  onTap: () {},
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('TravelerCard compact', () {
    // Les cas qui cassaient les cartes : écran étroit (320 dp) et texte
    // agrandi à 200 %. Rien ne doit déborder, et chaque pastille doit rester
    // entièrement dans la carte.
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'carte la plus chargée à ${width.toInt()} dp, texte ×$scale : '
          'aucun débordement, toutes les pastilles visibles',
          (tester) async {
            await tester.pumpWidget(
              _wrapAt(
                width,
                scale,
                _card(
                  announcement: _loaded(),
                  bidStatus: kNegotiatingBidStatus,
                  distance: 'à 3 km',
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);

            final cardRect = tester.getRect(find.byType(TravelerCard));
            for (final finder in [
              find.text('Offre envoyée'),
              find.byType(DonyUrgentBadge),
              find.byType(GpProBadge),
              find.text('à 3 km'),
            ]) {
              expect(finder, findsOneWidget);
              final rect = tester.getRect(finder);
              expect(
                rect.left >= cardRect.left - 0.5 &&
                    rect.right <= cardRect.right + 0.5,
                isTrue,
                reason: 'pastille hors de la carte : $rect dans $cardRect',
              );
            }
          },
        );
      }
    }

    testWidgets('mon propre trajet : « Votre trajet » et audience visibles, '
        'sans débordement à 320 dp et ×2', (tester) async {
      await tester.pumpWidget(
        _wrapAt(
          320,
          2,
          _card(announcement: _loaded(travelerId: 'moi'), own: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Votre trajet'), findsOneWidget);
      expect(find.text('12 vues'), findsOneWidget);
    });

    testWidgets('les escales restent sur la ligne du trajet, pas dans les '
        'pastilles', (tester) async {
      await tester.pumpWidget(_wrapAt(360, 1, _card(announcement: _loaded())));
      await tester.pumpAndSettle();

      // Le libellé est sous la ligne de la route, comme sur la carte normale.
      final routeRect = tester.getRect(find.byKey(const Key('route-header')));
      final stopsRect = tester.getRect(
        find.byKey(const Key('route-stop-markers')),
      );
      expect(routeRect.contains(stopsRect.center), isTrue);
      expect(find.text('2 escales et +'), findsOneWidget);
    });

    testWidgets('même contenu que la carte normale, en moins haut', (
      tester,
    ) async {
      final ann = _loaded();
      await tester.pumpWidget(
        _wrapAt(360, 1, _card(announcement: ann, compact: false)),
      );
      await tester.pumpAndSettle();
      final normalHeight = tester.getSize(find.byType(TravelerCard)).height;
      final normalHasUrgent = find
          .byType(DonyUrgentBadge)
          .evaluate()
          .isNotEmpty;

      await tester.pumpWidget(_wrapAt(360, 1, _card(announcement: ann)));
      await tester.pumpAndSettle();
      final compactHeight = tester.getSize(find.byType(TravelerCard)).height;

      expect(compactHeight, lessThan(normalHeight));
      expect(normalHasUrgent, isTrue);
      expect(
        find.byType(DonyUrgentBadge),
        findsOneWidget,
        reason: 'la pastille Urgent doit rester affichée en version compacte',
      );
    });
  });
}
