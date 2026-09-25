import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/screens/my_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockMyReviewsBloc extends MockBloc<MyReviewsEvent, MyReviewsState>
    implements MyReviewsBloc {}

class FakeMyReviewsEvent extends Fake implements MyReviewsEvent {}

Widget _wrap(MyReviewsBloc bloc) => BlocProvider<MyReviewsBloc>.value(
  value: bloc,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const MyReviewsScreen())],
    ),
  ),
);

final _summaryWithReviews = RatingSummary(
  averageRating: 4.5,
  ratingCount: 3,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 1, 5: 2},
  ratings: [
    RatingItem(
      stars: 5,
      comment: 'Excellent envoi !',
      createdAt: DateTime.utc(2026, 3, 15),
      excluded: false,
    ),
    RatingItem(stars: 4, createdAt: DateTime.utc(2026, 4), excluded: false),
  ],
  page: 0,
  totalPages: 1,
);

// Régression finale F : 'd MMM yyyy' fixe (AppL10n.localeName) + toUpperCase
// → DateFormat.yMMMd(l.localeName).toUpperCase(). Rendu fr identique à
// l'ancien motif.
final _summaryWithDatedReview = RatingSummary(
  averageRating: 5,
  ratingCount: 1,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
  ratings: [
    RatingItem(
      stars: 5,
      comment: 'Très bien !',
      createdAt: DateTime(2026, 10, 6, 14, 5),
      excluded: false,
    ),
  ],
  page: 0,
  totalPages: 1,
);

const _emptySummary = RatingSummary(
  averageRating: 0.0,
  ratingCount: 0,
  distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  ratings: [],
  page: 0,
  totalPages: 0,
);

void main() {
  late MockMyReviewsBloc bloc;

  setUpAll(() {
    registerFallbackValue(FakeMyReviewsEvent());
    // _ReviewItem formate la date en français (DateFormat('d MMM yyyy', 'fr')).
    initializeDateFormatting('fr');
  });

  setUp(() {
    bloc = MockMyReviewsBloc();
    when(() => bloc.state).thenReturn(const MyReviewsInitial());
  });

  // 1. Affiche CircularProgressIndicator quand MyReviewsLoading
  testWidgets('shows skeleton when MyReviewsLoading', (tester) async {
    when(() => bloc.state).thenReturn(const MyReviewsLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  // 2. Affiche "Mes avis reçus" comme titre
  testWidgets('shows "Mes avis reçus" as title', (tester) async {
    when(() => bloc.state).thenReturn(const MyReviewsLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Mes avis reçus'), findsOneWidget);
  });

  // 3. Affiche état vide quand ratingCount == 0
  testWidgets('shows empty state when ratingCount is 0', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MyReviewsLoaded(summary: _emptySummary));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining("pas encore reçu d'avis"), findsOneWidget);
  });

  // 4. Affiche le score moyen quand des avis existent
  // Correction R46 (fix round 1) : l'ancien code (`toStringAsFixed(1)`)
  // affichait un point même en français ("4.5"). `formatOneDecimal` rend
  // désormais la virgule française ("4,5"), déclarée ici comme accord.
  testWidgets('shows average score with French comma when reviews exist', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('4,5'), findsOneWidget);
    expect(find.text('4.5'), findsNothing);
  });

  testWidgets('shows average score with English dot when reviews exist', (
    tester,
  ) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('shows review date like the old fr pattern', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithDatedReview));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('6 OCT. 2026'), findsOneWidget);
  });

  testWidgets('shows review date in English', (tester) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithDatedReview));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final expected = DateFormat.yMMMd(
      'en',
    ).format(DateTime(2026, 10, 6, 14, 5)).toUpperCase();
    expect(find.text(expected), findsOneWidget);
  });

  // 5. Affiche les barres de distribution
  testWidgets('shows distribution bars when reviews exist', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Les barres affichent 5★, 4★, 3★, 2★, 1★
    expect(find.text('5★'), findsOneWidget);
    expect(find.text('4★'), findsOneWidget);
  });

  // 6. Bouton "Réessayer" quand MyReviewsError
  testWidgets('shows retry button on MyReviewsError', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MyReviewsError(message: 'Erreur réseau'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches MyReviewsRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MyReviewsError(message: 'Erreur réseau'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    clearInteractions(bloc);

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<MyReviewsRequested>()))).called(1);
  });

  // 8. Tap sur une ligne de distribution → MyReviewsStarFilterToggled
  testWidgets('tapping a distribution row dispatches star filter', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    clearInteractions(bloc);

    // La ligne 5★ a 2 avis → cliquable.
    await tester.tap(find.text('5★'));
    verify(
      () => bloc.add(
        any(
          that: isA<MyReviewsStarFilterToggled>().having(
            (e) => e.stars,
            'stars',
            5,
          ),
        ),
      ),
    ).called(1);
  });

  // 9. Filtre actif → liste réduite + bouton « Tout afficher »
  testWidgets('active filter shows only matching reviews and a reset', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MyReviewsLoaded(summary: _summaryWithReviews, selectedStars: 5),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Tout afficher'), findsOneWidget);
    // _summaryWithReviews a 1 avis 5★ et 1 avis 4★ → filtre 5★ ⇒ 1 visible.
    expect(find.text('AVIS 5★ · 1'), findsOneWidget);
  });

  testWidgets('titre et en-têtes traduits en anglais', (tester) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Reviews received'), findsOneWidget);
    expect(find.text('REVIEWS RECEIVED'), findsOneWidget);
    expect(find.text('From 3 reviews'), findsOneWidget);
    expect(find.text('“Excellent envoi !”'), findsOneWidget);
    expect(find.text('« Excellent envoi ! »'), findsNothing);
  });

  testWidgets('état vide traduit en anglais', (tester) async {
    useEnglish();
    when(
      () => bloc.state,
    ).thenReturn(const MyReviewsLoaded(summary: _emptySummary));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining("haven't received any reviews yet"),
      findsOneWidget,
    );
  });
}
