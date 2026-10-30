// Navigations de l'écran du trajet (trip_routes.dart) : route filtrée des
// demandes, relecture silencieuse au retour ancrée sur l'écran (pas sur le
// widget touché), double appui, écran quitté pendant la page ouverte.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_card_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    registerFallbackValue(BidListRequested('fallback'));
  });

  test('tripRequestsLocation compose la route filtrée', () {
    expect(
      tripRequestsLocation('11111111-2222-3333-4444-555555555555'),
      '/demandes?filter=aTraiter&announcement=11111111-2222-3333-4444-555555555555',
    );
  });

  group('relecture au retour', () {
    late MockBidBloc bidBloc;
    late MockAnnouncementBloc annBloc;
    late ValueNotifier<bool> showButton;
    late int pushes;

    setUp(() {
      bidBloc = MockBidBloc();
      annBloc = MockAnnouncementBloc();
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidListLoaded(const []),
      );
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementDetailLoaded(tripFixture()),
      );
      showButton = ValueNotifier(true);
      pushes = 0;
    });

    tearDown(() => showButton.dispose());

    /// `/home` → `/trip` (l'écran, sous ses blocs, avec un bouton qui ouvre
    /// la fiche d'un colis et peut disparaître) → `/bids/:id` (`back` revient
    /// à l'écran, `leave` quitte l'écran).
    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(context.push<void>('/trip')),
                child: const Text('open trip'),
              ),
            ),
          ),
          GoRoute(
            path: '/trip',
            builder: (context, _) => MultiBlocProvider(
              providers: [
                BlocProvider<BidBloc>.value(value: bidBloc),
                BlocProvider<AnnouncementBloc>.value(value: annBloc),
              ],
              child: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showButton,
                  builder: (context, show, _) => show
                      ? Builder(
                          builder: (rowContext) => TextButton(
                            onPressed: () => unawaited(
                              openTripParcel(
                                rowContext,
                                tripId: 'trip-1',
                                bidId: 'b1',
                              ),
                            ),
                            child: const Text('row'),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/bids/:bidId',
            builder: (context, _) {
              pushes++;
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('back'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('leave'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('open trip'));
      await tester.pumpAndSettle();
    }

    testWidgets('relecture silencieuse des colis et du trajet', (tester) async {
      await pump(tester);

      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      verifyNever(() => bidBloc.add(any()));
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      final bidEvent =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(bidEvent.silent, isTrue);
      final annEvent =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(annEvent.id, 'trip-1');
      expect(annEvent.silent, isTrue);
    });

    testWidgets('widget touché démonté pendant la page : l\'écran est relu', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      // La liste relue ne contient plus la ligne touchée.
      showButton.value = false;
      await tester.pump();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
      verify(
        () => annBloc.add(any(that: isA<AnnouncementDetailRequested>())),
      ).called(1);
    });

    testWidgets('écran quitté pendant la page : rien n\'est relu', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(find.text('open trip'), findsOneWidget);
      verifyNever(() => bidBloc.add(any()));
      verifyNever(() => annBloc.add(any()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('double appui : une seule page, puis de nouveau possible', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('row'));
      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      expect(pushes, 1);

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      expect(pushes, 2);
    });
  });
}
