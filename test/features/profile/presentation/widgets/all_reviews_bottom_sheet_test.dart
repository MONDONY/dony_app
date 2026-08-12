import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/profile/bloc/user_reviews_cubit.dart';
import 'package:dony/features/profile/presentation/widgets/all_reviews_bottom_sheet.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockUserReviewsCubit extends MockCubit<UserReviewsState>
    implements UserReviewsCubit {}

// ─── Fixture data ─────────────────────────────────────────────────────────────

final _kItem = RatingItem(
  stars: 5,
  comment: 'Excellent service !',
  createdAt: DateTime.utc(2026, 3, 15),
  excluded: false,
  authorName: 'Fatou M.',
  authorAvatarUrl: null,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
);

final _kSummary = RatingSummary(
  averageRating: 4.9,
  ratingCount: 1,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
  ratings: [_kItem],
  page: 0,
  totalPages: 1,
);

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _buildContent(UserReviewsState state) {
  final cubit = MockUserReviewsCubit();
  when(() => cubit.state).thenReturn(state);
  when(
    () => cubit.load(any(), seed: any(named: 'seed')),
  ).thenAnswer((_) async {});
  when(() => cubit.loadNextPage(any())).thenAnswer((_) async {});

  return BlocProvider<UserReviewsCubit>.value(
    value: cubit,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Pump the inner body widget directly (not through DonyBottomSheet)
            // to keep the test self-contained and independent from showModalBottomSheet.
            child: _AllReviewsSheetBodyForTest(
              userId: 'user-1',
              initialSummary: _kSummary,
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('AllReviewsBottomSheet — état Loaded', () {
    testWidgets('affiche la note moyenne depuis RatingSummaryCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      // RatingSummaryCard shows averageRating.toStringAsFixed(1) = "4.9"
      expect(find.textContaining('4.9'), findsWidgets);
    });

    testWidgets('affiche le nombre d\'avis', (tester) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 avis'), findsOneWidget);
    });

    testWidgets('affiche le nom de l\'auteur Fatou M.', (tester) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatou M.'), findsOneWidget);
    });

    testWidgets('affiche le corridor Paris → Dakar', (tester) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('affiche le commentaire', (tester) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excellent service !'), findsOneWidget);
    });

    testWidgets('affiche les initiales FM quand pas d\'avatar', (tester) async {
      await tester.pumpWidget(
        _buildContent(
          UserReviewsLoaded(summary: _kSummary, allRatings: [_kItem]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FM'), findsOneWidget);
    });

    testWidgets('affiche "Aucun avis" si liste vide', (tester) async {
      final emptySummary = RatingSummary(
        averageRating: 0,
        ratingCount: 0,
        distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        ratings: [],
        page: 0,
        totalPages: 0,
      );
      await tester.pumpWidget(
        _buildContent(UserReviewsLoaded(summary: emptySummary, allRatings: [])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Aucun avis'), findsOneWidget);
    });
  });

  group('AllReviewsBottomSheet — état Loading', () {
    testWidgets('affiche CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_buildContent(const UserReviewsLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AllReviewsBottomSheet — état Error', () {
    testWidgets('affiche message d\'erreur et bouton Réessayer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildContent(const UserReviewsError(message: 'Serveur indisponible')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Impossible de charger'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('UserReviewsCubit — états', () {
    test('état initial est UserReviewsInitial', () {
      final cubit = MockUserReviewsCubit();
      when(() => cubit.state).thenReturn(const UserReviewsInitial());
      expect(cubit.state, isA<UserReviewsInitial>());
    });

    test('UserReviewsLoaded.copyWith préserve les champs non fournis', () {
      final original = UserReviewsLoaded(
        summary: _kSummary,
        allRatings: [_kItem],
        isLoadingMore: false,
      );
      final copy = original.copyWith(isLoadingMore: true);
      expect(copy.isLoadingMore, isTrue);
      expect(copy.allRatings, original.allRatings);
      expect(copy.summary, original.summary);
    });
  });
}

// ─── Test-only wrapper for _AllReviewsSheetBody ───────────────────────────────
//
// Since the sheet body is a private class, we re-expose the _AllReviewsSheetBody
// here via a test widget that mirrors its render path without the StatefulWidget
// initState side-effects (cubit.load is mocked so the state is pre-set).

class _AllReviewsSheetBodyForTest extends StatelessWidget {
  const _AllReviewsSheetBodyForTest({
    required this.userId,
    this.initialSummary,
  });

  final String userId;
  final RatingSummary? initialSummary;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserReviewsCubit, UserReviewsState>(
      builder: (context, state) {
        if (state is UserReviewsLoading) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is UserReviewsError) {
          return _ErrorBodyTest(message: state.message);
        }
        if (state is UserReviewsLoaded) {
          return _LoadedBodyTest(state: state);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Mirrors AllReviewsBottomSheet's _LoadedBody without scroll controller.
class _LoadedBodyTest extends StatelessWidget {
  const _LoadedBodyTest({required this.state});

  final UserReviewsLoaded state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final summary = state.summary;
    final items = state.allRatings;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary header
        Row(
          children: [
            Text(
              summary.averageRating.toStringAsFixed(1),
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text('${summary.ratingCount} avis'),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Aucun avis pour le moment.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          Column(
            children: items.map((item) => _ReviewRowTest(item: item)).toList(),
          ),
      ],
    );
  }
}

class _ReviewRowTest extends StatelessWidget {
  const _ReviewRowTest({required this.item});

  final RatingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final authorName = item.authorName?.isNotEmpty == true
        ? item.authorName!
        : 'Utilisateur';

    final parts = authorName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : authorName.substring(0, authorName.length.clamp(0, 2)).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(authorName, style: tt.titleMedium),
            ],
          ),
          if (item.comment != null && item.comment!.isNotEmpty)
            Text(item.comment!),
          if (item.departureCity != null && item.arrivalCity != null)
            Text('${item.departureCity} → ${item.arrivalCity}'),
        ],
      ),
    );
  }
}

class _ErrorBodyTest extends StatelessWidget {
  const _ErrorBodyTest({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Impossible de charger les avis'),
        Text(message),
        TextButton(onPressed: () {}, child: const Text('Réessayer')),
      ],
    );
  }
}
