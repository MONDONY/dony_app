import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockProfilePublicBloc
    extends MockBloc<ProfilePublicEvent, ProfilePublicState>
    implements ProfilePublicBloc {}

class FakeProfilePublicEvent extends Fake implements ProfilePublicEvent {}

const _profile = ProfilePublicModel(
  userId: 'user-1',
  displayName: 'Fatou Diallo',
  avatarUrl: null,
  kycVerified: true,
  isProAccount: false,
  isKiloPro: false,
  completedBidsCount: 12,
  averageRating: 4.8,
  ratingCount: 7,
  memberSince: 'mars 2025',
  badges: ['Super Expéditeur'],
);

final _ratingSummary = RatingSummary(
  averageRating: 4.8,
  ratingCount: 7,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 2, 5: 5},
  ratings: [
    RatingItem(
      stars: 5,
      comment: 'Parfait !',
      createdAt: DateTime.utc(2026, 3, 1),
      excluded: false,
    ),
  ],
  page: 0,
  totalPages: 1,
);

Widget _wrap(ProfilePublicBloc bloc) => BlocProvider<ProfilePublicBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  const ProfilePublicScreen(userId: 'user-1'),
            ),
            GoRoute(
              path: '/profile/reviews',
              builder: (_, __) => const Scaffold(body: Text('Reviews')),
            ),
          ],
        ),
      ),
    );

void main() {
  late MockProfilePublicBloc bloc;

  setUpAll(() => registerFallbackValue(FakeProfilePublicEvent()));

  setUp(() {
    bloc = MockProfilePublicBloc();
    when(() => bloc.state).thenReturn(const ProfilePublicInitial());
  });

  // 1. Affiche CircularProgressIndicator pendant le chargement
  testWidgets('shows CircularProgressIndicator when loading', (tester) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // 2. Affiche le titre "Ce que les autres voient"
  testWidgets('shows title "Ce que les autres voient"', (tester) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ce que les autres voient'), findsOneWidget);
  });

  // 3. Affiche le displayName
  testWidgets('shows displayName when loaded', (tester) async {
    when(() => bloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _profile,
        recentRatings: _ratingSummary,
      ),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Fatou Diallo'), findsOneWidget);
  });

  // 4. Affiche le badge KYC
  testWidgets('shows KYC badge when verified', (tester) async {
    when(() => bloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _profile,
        recentRatings: _ratingSummary,
      ),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('✓ Vérifié'), findsOneWidget);
  });

  // 5. Affiche "Réessayer" en cas d'erreur
  testWidgets('shows retry button on error', (tester) async {
    when(() => bloc.state)
        .thenReturn(const ProfilePublicError(message: 'Serveur indisponible'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches ProfilePublicRequested', (tester) async {
    when(() => bloc.state)
        .thenReturn(const ProfilePublicError(message: 'Serveur indisponible'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<ProfilePublicRequested>()))).called(1);
  });
}
