import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/presentation/screens/my_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockMyReviewsBloc extends MockBloc<MyReviewsEvent, MyReviewsState>
    implements MyReviewsBloc {}

class FakeMyReviewsEvent extends Fake implements MyReviewsEvent {}

Widget _wrap(MyReviewsBloc bloc) => BlocProvider<MyReviewsBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const MyReviewsScreen(),
            ),
          ],
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
    RatingItem(
      stars: 4,
      comment: null,
      createdAt: DateTime.utc(2026, 4, 1),
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

  setUpAll(() => registerFallbackValue(FakeMyReviewsEvent()));

  setUp(() {
    bloc = MockMyReviewsBloc();
    when(() => bloc.state).thenReturn(const MyReviewsInitial());
  });

  // 1. Affiche CircularProgressIndicator quand MyReviewsLoading
  testWidgets('shows CircularProgressIndicator when MyReviewsLoading',
      (tester) async {
    when(() => bloc.state).thenReturn(const MyReviewsLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
    when(() => bloc.state)
        .thenReturn(const MyReviewsLoaded(summary: _emptySummary));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining("pas encore reçu d'avis"), findsOneWidget);
  });

  // 4. Affiche le score moyen quand des avis existent
  testWidgets('shows average score when reviews exist', (tester) async {
    when(() => bloc.state)
        .thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('4.5'), findsOneWidget);
  });

  // 5. Affiche les barres de distribution
  testWidgets('shows distribution bars when reviews exist', (tester) async {
    when(() => bloc.state)
        .thenReturn(MyReviewsLoaded(summary: _summaryWithReviews));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Les barres affichent 5★, 4★, 3★, 2★, 1★
    expect(find.text('5★'), findsOneWidget);
    expect(find.text('4★'), findsOneWidget);
  });

  // 6. Bouton "Réessayer" quand MyReviewsError
  testWidgets('shows retry button on MyReviewsError', (tester) async {
    when(() => bloc.state)
        .thenReturn(const MyReviewsError(message: 'Erreur réseau'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches MyReviewsRequested', (tester) async {
    when(() => bloc.state)
        .thenReturn(const MyReviewsError(message: 'Erreur réseau'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    clearInteractions(bloc);

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<MyReviewsRequested>()))).called(1);
  });
}
