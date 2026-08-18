import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/bloc/user_reviews_cubit.dart';
import 'package:dony/features/profile/presentation/widgets/all_reviews_bottom_sheet.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserReviewsCubit extends Mock implements UserReviewsCubit {}

RatingItem _item({
  int stars = 5,
  String? comment,
  String? authorName,
  String? departureCity,
  String? arrivalCity,
}) => RatingItem(
  stars: stars,
  comment: comment,
  createdAt: DateTime.utc(2026, 3, 14),
  excluded: false,
  authorName: authorName,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
);

RatingSummary _summary({List<RatingItem> ratings = const []}) => RatingSummary(
  averageRating: 4.5,
  ratingCount: ratings.length,
  distribution: const {5: 1, 4: 1, 3: 0, 2: 0, 1: 0},
  ratings: ratings,
  page: 0,
  totalPages: 1,
);

void main() {
  late _MockUserReviewsCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  /// Le sheet lit son cubit dans GetIt et le ferme à la fermeture : chaque test
  /// réenregistre le sien pour rester indépendant des autres.
  void stubState(UserReviewsState state) {
    cubit = _MockUserReviewsCubit();
    when(() => cubit.state).thenReturn(state);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => Stream<UserReviewsState>.value(state));
    when(() => cubit.close()).thenAnswer((_) async {});
    when(
      () => cubit.load(any(), seed: any(named: 'seed')),
    ).thenAnswer((_) async {});
    when(() => cubit.loadNextPage(any())).thenAnswer((_) async {});
    if (getIt.isRegistered<UserReviewsCubit>()) {
      getIt.unregister<UserReviewsCubit>();
    }
    getIt.registerFactory<UserReviewsCubit>(() => cubit);
  }

  tearDown(() {
    if (getIt.isRegistered<UserReviewsCubit>()) {
      getIt.unregister<UserReviewsCubit>();
    }
  });

  /// [settle] est désactivé quand un CircularProgressIndicator est à l'écran :
  /// son animation ne s'arrête jamais, donc pumpAndSettle expirerait.
  Future<void> openSheet(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    AllReviewsBottomSheet.show(context, userId: 'user-1'),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('état chargement : skeleton, aucun avis rendu', (tester) async {
    stubState(const UserReviewsLoading());

    await openSheet(tester, settle: false);

    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
    expect(find.text('Aucun avis pour le moment.'), findsNothing);
  });

  testWidgets('état erreur : message du serveur affiché', (tester) async {
    stubState(const UserReviewsError(message: 'Connexion perdue'));

    await openSheet(tester);

    expect(find.text('Connexion perdue'), findsOneWidget);
  });

  testWidgets('liste vide : message dédié, pas de ligne d’avis', (
    tester,
  ) async {
    stubState(UserReviewsLoaded(summary: _summary(), allRatings: const []));

    await openSheet(tester);

    expect(find.text('Aucun avis pour le moment.'), findsOneWidget);
  });

  testWidgets('avis rendu : auteur, date localisée, commentaire et corridor', (
    tester,
  ) async {
    final items = [
      _item(
        stars: 4,
        comment: 'Colis livré rapidement',
        authorName: 'Awa Diop',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      ),
    ];
    stubState(
      UserReviewsLoaded(
        summary: _summary(ratings: items),
        allRatings: items,
      ),
    );

    await openSheet(tester);

    expect(find.text('Awa Diop'), findsOneWidget);
    expect(find.text('Colis livré rapidement'), findsOneWidget);
    expect(find.text('14 mars 2026'), findsOneWidget);
    expect(find.textContaining('Paris'), findsWidgets);
    expect(find.textContaining('Dakar'), findsWidgets);
  });

  testWidgets('auteur anonyme : repli « Utilisateur » sans planter', (
    tester,
  ) async {
    final items = [_item()];
    stubState(
      UserReviewsLoaded(
        summary: _summary(ratings: items),
        allRatings: items,
      ),
    );

    await openSheet(tester);

    expect(find.text('Utilisateur'), findsOneWidget);
  });

  testWidgets('page suivante en cours : indicateur ajouté sous la liste', (
    tester,
  ) async {
    final items = [_item(authorName: 'Awa Diop')];
    stubState(
      UserReviewsLoaded(
        summary: _summary(ratings: items),
        allRatings: items,
        isLoadingMore: true,
      ),
    );

    await openSheet(tester, settle: false);

    expect(find.text('Awa Diop'), findsOneWidget);
    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });
}
