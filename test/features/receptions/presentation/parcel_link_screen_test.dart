import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/receptions/bloc/parcel_link_cubit.dart';
import 'package:dony/features/receptions/data/models/parcel_role.dart';
import 'package:dony/features/receptions/presentation/screens/parcel_link_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockParcelLinkCubit extends MockCubit<ParcelLinkState>
    implements ParcelLinkCubit {}

void main() {
  const bidId = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
  late MockParcelLinkCubit cubit;
  late List<String> visited;

  setUp(() {
    cubit = MockParcelLinkCubit();
    visited = [];
  });

  Widget harness() {
    Widget leaf(GoRouterState s) {
      visited.add(s.uri.path);
      return const SizedBox();
    }

    final router = GoRouter(
      initialLocation: '/colis/$bidId',
      routes: [
        GoRoute(
          path: '/colis/:bidId',
          builder: (_, state) => BlocProvider<ParcelLinkCubit>.value(
            value: cubit,
            child: ParcelLinkScreen(bidId: state.pathParameters['bidId']!),
          ),
        ),
        GoRoute(path: '/receptions/:bidId', builder: (_, s) => leaf(s)),
        GoRoute(path: '/bids/:bidId', builder: (_, s) => leaf(s)),
        GoRoute(path: '/support', builder: (_, s) => leaf(s)),
      ],
    );
    return MaterialApp.router(
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  void resolvesTo(ParcelRole role) {
    whenListen(
      cubit,
      Stream<ParcelLinkState>.value(ParcelLinkResolved(role)),
      initialState: const ParcelLinkLoading(),
    );
  }

  testWidgets('chargement : indicateur', (tester) async {
    when(() => cubit.state).thenReturn(const ParcelLinkLoading());
    await tester.pumpWidget(harness());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('destinataire : ouvre Réceptions', (tester) async {
    resolvesTo(ParcelRole.recipient);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(visited, ['/receptions/$bidId']);
  });

  testWidgets('expéditeur : ouvre la fiche du colis', (tester) async {
    resolvesTo(ParcelRole.sender);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(visited, ['/bids/$bidId']);
  });

  testWidgets('voyageur : ouvre la fiche du colis', (tester) async {
    resolvesTo(ParcelRole.traveler);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(visited, ['/bids/$bidId']);
  });

  testWidgets('aucun lien : message et bouton support', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const ParcelLinkResolved(ParcelRole.none));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text("Ce colis n'est pas lié à votre compte"), findsOneWidget);
    await tester.tap(find.text('Contacter le support'));
    await tester.pumpAndSettle();
    expect(visited, ['/support']);
  });

  testWidgets('erreur : Réessayer relance le chargement', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const ParcelLinkError(NetworkException('offline')));
    when(() => cubit.load(bidId)).thenAnswer((_) async {});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    verify(() => cubit.load(bidId)).called(1);
  });
}
