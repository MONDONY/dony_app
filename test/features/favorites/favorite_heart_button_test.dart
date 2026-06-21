import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _wrapWithTheme(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: child),
    );

// ---------------------------------------------------------------------------
// FavoriteHeartButton — pure widget tests (no cubit)
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('FavoriteHeartButton — état non-favori', () {
    testWidgets('affiche le cœur vide (favorite_border) quand isFavorite=false',
        (tester) async {
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: false,
        onToggle: () {},
      )));
      await tester.pump();

      // favorite_border icon should be present
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.favorite_border);
    });

    testWidgets('couleur icône = onSurfaceVariant quand isFavorite=false',
        (tester) async {
      await tester.pumpWidget(_wrapWithTheme(FavoriteHeartButton(
        isFavorite: false,
        onToggle: () {},
      )));
      await tester.pump();

      final cs =
          Theme.of(tester.element(find.byType(FavoriteHeartButton))).colorScheme;
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, cs.onSurfaceVariant);
    });
  });

  group('FavoriteHeartButton — état favori', () {
    testWidgets('affiche le cœur rempli (favorite) quand isFavorite=true',
        (tester) async {
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: true,
        onToggle: () {},
      )));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.favorite);
    });

    testWidgets('couleur icône = DonyColors.favorite quand isFavorite=true',
        (tester) async {
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: true,
        onToggle: () {},
      )));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, DonyColors.favorite);
    });
  });

  group('FavoriteHeartButton — interaction', () {
    testWidgets('tap déclenche onToggle', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: true,
        onToggle: () => tapped = true,
      )));
      await tester.pump();

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('tap multiple déclenche onToggle à chaque fois', (tester) async {
      var count = 0;
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: false,
        onToggle: () => count++,
      )));
      await tester.pump();

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      expect(count, 2);
    });
  });

  group('FavoriteHeartButton — tooltip', () {
    testWidgets('tooltip "Ajouter aux favoris" quand isFavorite=false',
        (tester) async {
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: false,
        onToggle: () {},
      )));
      await tester.pump();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Ajouter aux favoris');
    });

    testWidgets('tooltip "Retirer des favoris" quand isFavorite=true',
        (tester) async {
      await tester.pumpWidget(_wrap(FavoriteHeartButton(
        isFavorite: true,
        onToggle: () {},
      )));
      await tester.pump();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Retirer des favoris');
    });
  });

  // ---------------------------------------------------------------------------
  // TripCard integration — showFavorite
  // ---------------------------------------------------------------------------

  group('TripCard — showFavorite', () {
    AnnouncementModel makeAnnouncement() => AnnouncementModel.fromJson({
          'id': 'trip-1',
          'travelerId': 't1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate':
              DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'totalKg': 20.0,
          'availableKg': 15.0,
          'pricePerKg': 8.0,
          'pricingMode': 'KG',
          'status': 'ACTIVE',
          'pendingBidCount': 0,
          'confirmedParcelCount': 0,
          'createdAt': '2024-01-01T00:00:00Z',
          'updatedAt': '2024-01-01T00:00:00Z',
        });

    testWidgets(
        'showFavorite=false (défaut) : aucun FavoriteHeartButton affiché',
        (tester) async {
      await tester.pumpWidget(_wrap(TripCard(
        announcement: makeAnnouncement(),
        onTap: () {},
        index: 0,
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets(
        'showFavorite=true sans cubit dans l\'arbre : dégradation silencieuse (pas de crash)',
        (tester) async {
      // No BlocProvider — the card must not crash
      await tester.pumpWidget(_wrap(TripCard(
        announcement: makeAnnouncement(),
        onTap: () {},
        index: 0,
        showFavorite: true,
      )));
      await tester.pump(const Duration(milliseconds: 600));

      // Defensive read: no heart rendered (SizedBox.shrink), no exception
      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets(
        'showFavorite=true avec cubit : FavoriteHeartButton affiché non-favori',
        (tester) async {
      final repo = _MockFavoriteRepository();
      when(() => repo.ids()).thenAnswer((_) async => throw Exception());

      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TripCard(
            announcement: makeAnnouncement(),
            onTap: () {},
            index: 0,
            showFavorite: true,
          )),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      // The heart must NOT be filled (trip-1 is not in favorites)
      expect(icon.icon, Icons.favorite_border);
    });

    testWidgets(
        'showFavorite=true avec cubit : tap cœur appelle toggleTrip',
        (tester) async {
      final repo = _MockFavoriteRepository();
      when(() => repo.add(any(), any())).thenAnswer((_) async {});

      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TripCard(
            announcement: makeAnnouncement(),
            onTap: () {},
            index: 0,
            showFavorite: true,
          )),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byType(FavoriteHeartButton));
      // Use pump with duration instead of pumpAndSettle to avoid timing out
      // due to the pulsing animation in the status badge.
      await tester.pump(const Duration(milliseconds: 500));

      // After toggle, 'trip-1' must be in favorites (optimistic)
      expect(cubit.isTripFav('trip-1'), isTrue);
      verify(() => repo.add('trip', 'trip-1')).called(1);
    });

    testWidgets(
        'showFavorite=true avec cubit seeded favori : cœur rempli',
        (tester) async {
      final repo = _MockFavoriteRepository();

      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {'trip-1'}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TripCard(
            announcement: makeAnnouncement(),
            onTap: () {},
            index: 0,
            showFavorite: true,
          )),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      // Find the Icon inside the FavoriteHeartButton specifically
      final icons = find.descendant(
        of: find.byType(FavoriteHeartButton),
        matching: find.byType(Icon),
      );
      final icon = tester.widget<Icon>(icons.first);
      expect(icon.icon, Icons.favorite);
      expect(icon.color, DonyColors.favorite);
    });
  });
}
