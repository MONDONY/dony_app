import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/favorite_travelers/bloc/favorite_traveler_bloc.dart';
import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';
import 'package:dony/features/favorite_travelers/presentation/screens/favorite_travelers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockFavoriteTravelerBloc
    extends MockBloc<FavoriteTravelerEvent, FavoriteTravelerState>
    implements FavoriteTravelerBloc {}

class FakeFavoriteTravelerEvent extends Fake implements FavoriteTravelerEvent {}

const _t1 = FavoriteTraveler(
  id: 'fav-1',
  travelerId: 'traveler-1',
  travelerName: 'Ibrahima Diallo',
  travelerAverageRating: 4.8,
);

const _t2 = FavoriteTraveler(
  id: 'fav-2',
  travelerId: 'traveler-2',
  travelerName: 'Fatoumata Bah',
  travelerAverageRating: 4.5,
);

Widget _wrap(FavoriteTravelerBloc bloc) =>
    BlocProvider<FavoriteTravelerBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const FavoriteTravelersScreen(),
            ),
            GoRoute(
              path: '/travelers/:id',
              builder: (_, __) => const Scaffold(body: Text('Traveler Profile')),
            ),
          ],
        ),
      ),
    );

void main() {
  late MockFavoriteTravelerBloc bloc;

  setUpAll(() => registerFallbackValue(FakeFavoriteTravelerEvent()));

  setUp(() {
    bloc = MockFavoriteTravelerBloc();
    when(() => bloc.state).thenReturn(const FavoriteTravelerState());
  });

  testWidgets('shows loading state', (tester) async {
    when(() => bloc.state).thenReturn(
      const FavoriteTravelerState(status: FavoriteTravelerStatus.loading),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FavoriteTravelersScreen), findsOneWidget);
  });

  testWidgets('shows empty state when no favorites', (tester) async {
    when(() => bloc.state).thenReturn(
      const FavoriteTravelerState(status: FavoriteTravelerStatus.success),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Aucun voyageur favori'), findsOneWidget);
  });

  testWidgets('shows list of favorite travelers', (tester) async {
    when(() => bloc.state).thenReturn(
      const FavoriteTravelerState(
        status: FavoriteTravelerStatus.success,
        travelers: [_t1, _t2],
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ibrahima Diallo'), findsOneWidget);
    expect(find.text('Fatoumata Bah'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    when(() => bloc.state).thenReturn(
      const FavoriteTravelerState(
        status: FavoriteTravelerStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches FavoriteTravelerLoaded', (tester) async {
    when(() => bloc.state).thenReturn(
      const FavoriteTravelerState(
        status: FavoriteTravelerStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<FavoriteTravelerLoaded>()))).called(1);
  });
}
