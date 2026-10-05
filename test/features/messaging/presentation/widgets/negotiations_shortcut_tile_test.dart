import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/messaging/presentation/widgets/negotiations_shortcut_tile.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockBidNegotiationListBloc
    extends MockBloc<BidNegotiationListEvent, BidNegotiationListState>
    implements BidNegotiationListBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

NegotiationThread _thread(
  String id, {
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  bool myTurn = false,
}) => NegotiationThread(
  id: id,
  packageRequestId: 'pr-$id',
  travelerId: 'tr-1',
  status: status,
  currentPriceEur: 45,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 9, 30),
  createdAt: DateTime(2026, 9, 29),
  travelerTravelDate: DateTime(2026, 10, 15),
  travelerAvailableKg: 10,
  messages: const [],
  isMyTurn: myTurn,
);

BidNegotiationSummary _trip(
  String id, {
  String status = 'NEGOTIATING',
  bool myTurn = false,
  String role = 'SENDER',
}) => BidNegotiationSummary(
  bidId: id,
  announcementId: 'ann-$id',
  status: status,
  myTurn: myTurn,
  role: role,
);

void main() {
  group('negotiationsShortcutCounts', () {
    test('additionne les deux sources et ignore les fils clos', () {
      final counts = negotiationsShortcutCounts(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [
            _thread('a', myTurn: true),
            _thread('b'),
            _thread('c', status: NegotiationThreadStatus.rejected),
          ],
        ),
        BidNegotiationListState(
          status: BidNegotiationListStatus.loaded,
          summaries: [
            _trip('t1', myTurn: true),
            _trip('t2'),
            _trip('t3', status: 'ACCEPTED', myTurn: true),
          ],
        ),
      );
      expect(counts.open, 4);
      expect(counts.awaitingMe, 2);
    });

    test('un accord carte à payer par l\'expéditeur attend l\'utilisateur', () {
      final counts = negotiationsShortcutCounts(
        NegotiationListState(),
        BidNegotiationListState(
          summaries: [
            _trip('t1', status: 'AWAITING_PAYMENT'),
            _trip('t2', status: 'AWAITING_PAYMENT', role: 'TRAVELER'),
          ],
        ),
      );
      expect(counts.open, 2);
      expect(counts.awaitingMe, 1);
    });
  });

  group('NegotiationsShortcutSection', () {
    late _MockNegotiationListBloc requests;
    late _MockBidNegotiationListBloc trips;
    late _MockAnalyticsService analytics;

    setUpAll(() {
      registerFallbackValue(const NegotiationListRefreshRequested());
      registerFallbackValue(const BidNegotiationListRefreshRequested());
    });

    setUp(() {
      requests = _MockNegotiationListBloc();
      trips = _MockBidNegotiationListBloc();
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt
        ..registerSingleton<NegotiationListBloc>(requests)
        ..registerSingleton<BidNegotiationListBloc>(trips)
        ..registerSingleton<AnalyticsService>(analytics);
    });

    tearDown(() async {
      await getIt.reset();
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: NegotiationsShortcutSection()),
          ),
          GoRoute(
            path: '/negotiations',
            builder: (_, _) => const Scaffold(body: Text('ecran-negociations')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pump();
    }

    void seed({
      List<NegotiationThread> threads = const [],
      List<BidNegotiationSummary> summaries = const [],
    }) {
      whenListen(
        requests,
        const Stream<NegotiationListState>.empty(),
        initialState: NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: threads,
        ),
      );
      whenListen(
        trips,
        const Stream<BidNegotiationListState>.empty(),
        initialState: BidNegotiationListState(
          status: BidNegotiationListStatus.loaded,
          summaries: summaries,
        ),
      );
    }

    testWidgets('ne rend rien sans négociation ouverte', (tester) async {
      seed(threads: [_thread('a', status: NegotiationThreadStatus.expired)]);
      await pump(tester);

      expect(
        find.byKey(const Key('messages-negotiations-shortcut')),
        findsNothing,
      );
      verify(
        () => requests.add(const NegotiationListRefreshRequested()),
      ).called(1);
      verify(
        () => trips.add(const BidNegotiationListRefreshRequested()),
      ).called(1);
    });

    testWidgets('sans offre en attente : compteur des discussions, sans '
        'pastille', (tester) async {
      seed(threads: [_thread('a')], summaries: [_trip('t1')]);
      await pump(tester);

      expect(find.text('Discussions de prix'), findsOneWidget);
      expect(find.text('2 discussions en cours'), findsOneWidget);
      expect(
        find.byKey(const Key('messages-negotiations-shortcut-badge')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('messages-negotiations-shortcut-led')),
        findsNothing,
      );
    });

    testWidgets('une offre attend l\'utilisateur : pastille et sous-titre '
        'd\'action', (tester) async {
      seed(threads: [_thread('a', myTurn: true), _thread('b')]);
      await pump(tester);

      expect(find.text('Une offre attend votre réponse'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('messages-negotiations-shortcut-badge')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      ); // Voyant clignotant (FLUTTER-BY), nommé au lecteur d'écran.
      final led = find.byKey(const Key('messages-negotiations-shortcut-led'));
      expect(led, findsOneWidget);
      expect(
        find.descendant(of: led, matching: find.byType(FadeTransition)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Action requise')), findsOneWidget);
    });

    testWidgets('réduction des animations : voyant fixe, toujours présent', (
      tester,
    ) async {
      seed(threads: [_thread('a', myTurn: true)]);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester);

      final led = find.byKey(const Key('messages-negotiations-shortcut-led'));
      expect(led, findsOneWidget);
      expect(
        find.descendant(of: led, matching: find.byType(FadeTransition)),
        findsNothing,
      );
    });

    testWidgets('un tap ouvre /negotiations, trace l\'event et rafraîchit au '
        'retour', (tester) async {
      seed(summaries: [_trip('t1', myTurn: true)]);
      await pump(tester);

      await tester.tap(find.byKey(const Key('messages-negotiations-shortcut')));
      // Le voyant clignote en boucle : pumpAndSettle n'aboutirait jamais.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ecran-negociations'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.messagesNegotiationsShortcutOpened,
          properties: {'open_count': 1, 'awaiting_me_count': 1},
        ),
      ).called(1);

      GoRouter.of(tester.element(find.text('ecran-negociations'))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Un refresh à l'ouverture, un au retour.
      verify(
        () => requests.add(const NegotiationListRefreshRequested()),
      ).called(2);
      verify(
        () => trips.add(const BidNegotiationListRefreshRequested()),
      ).called(2);
    });
  });
}
