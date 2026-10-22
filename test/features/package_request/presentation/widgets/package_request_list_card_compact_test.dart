import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/package_request/data/models/my_negotiation_summary.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

/// Demande la plus chargée possible : urgente, compatible avec un trajet,
/// négociation en cours, noms longs.
PackageRequestSearchItem _loaded() => PackageRequestSearchItem(
  id: 'pr1',
  departureCity: 'Saint-Denis de la Réunion',
  arrivalCity: 'Ouagadougou',
  desiredDate: DateTime(2026, 11, 20),
  dateToleranceDays: 2,
  weightKg: 12,
  parcelSize: ParcelSize.large,
  categories: const ['Documents & administratif'],
  targetPriceEur: 35,
  urgent: true,
  matchScore: 94,
  matchedTripId: 't1',
  matchedTripDepartureDate: DateTime(2026, 7, 12),
  uniqueViewerCount: 5,
  myNegotiation: const MyNegotiationSummary(
    threadId: 'th1',
    status: 'OPEN',
    myTurn: false,
  ),
  sender: const SenderPublicProfile(
    id: 's1',
    displayName: 'Mariam Diakité-Traoré de la Réunion',
    averageRating: 4.9,
    totalRatings: 12,
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('PackageRequestListCard compact', () {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'demande la plus chargée à ${width.toInt()} dp, texte ×$scale : '
          'aucun débordement, pastilles dans la carte',
          (tester) async {
            await tester.pumpWidget(
              _wrapAt(
                width,
                scale,
                PackageRequestListCard(item: _loaded(), compact: true),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);

            final cardRect = tester.getRect(
              find.byType(PackageRequestListCard),
            );
            for (final finder in [
              find.byKey(const Key('match-score-badge')),
              find.text('Proposition en attente'),
              find.byType(DonyUrgentBadge),
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

    testWidgets('ma demande : « Ma demande » et « 5 vues » visibles sans '
        'débordement à 320 dp et ×2', (tester) async {
      await tester.pumpWidget(
        _wrapAt(
          320,
          2,
          PackageRequestListCard(
            item: _loaded(),
            compact: true,
            isOwnRequest: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ma demande'), findsOneWidget);
      expect(find.text('5 vues'), findsOneWidget);
    });

    testWidgets('compacte : pas de cœur favori même si showFavorite', (
      tester,
    ) async {
      final cubit = FavoriteIdsCubit(_MockFavoriteRepository())
        ..emitSeed(trips: {}, requests: {});
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrapAt(
            390,
            1,
            PackageRequestListCard(
              item: _loaded(),
              compact: true,
              showFavorite: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets('390 dp : libellé d\'en-tête entier, sur la ligne du statut', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapAt(390, 1, PackageRequestListCard(item: _loaded(), compact: true)),
      );
      await tester.pumpAndSettle();

      final label = find.text('Demande d\'envoi');
      expect(label, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(label);
      final painter = tester.widget<Text>(label);
      expect(painter.maxLines, 1);
      expect(renderBox.size.width, greaterThan(90));
    });

    testWidgets('même contenu que la carte normale, en moins haute', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapAt(
          360,
          1,
          PackageRequestListCard(item: _loaded(), isOwnRequest: true),
        ),
      );
      await tester.pumpAndSettle();
      final normal = tester.getSize(find.byType(PackageRequestListCard)).height;

      await tester.pumpWidget(
        _wrapAt(
          360,
          1,
          PackageRequestListCard(
            item: _loaded(),
            isOwnRequest: true,
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final compact = tester
          .getSize(find.byType(PackageRequestListCard))
          .height;

      expect(compact, lessThan(normal));
      expect(find.text('5 vues'), findsOneWidget);
    });
  });
}
