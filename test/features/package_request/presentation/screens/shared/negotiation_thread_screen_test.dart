import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

NegotiationThread _thread({
  String? travelerName = 'Fatou Ndiaye',
  double? travelerRating = 4.9,
  int? travelerTripsCount = 24,
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  List<NegotiationMessage> messages = const [],
}) =>
    NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: status,
      currentPriceEur: 50,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: messages,
      travelerName: travelerName,
      travelerRating: travelerRating,
      travelerTripsCount: travelerTripsCount,
    );

NegotiationMessage _msg({
  String id = 'm-1',
  String fromUserId = 'tr-1',
  NegotiationMessageKind kind = NegotiationMessageKind.proposal,
  double? proposedPriceEur = 50,
}) =>
    NegotiationMessage(
      id: id,
      threadId: 't-1',
      fromUserId: fromUserId,
      kind: kind,
      proposedPriceEur: proposedPriceEur,
      createdAt: DateTime(2026, 5, 10),
    );

void main() {
  late _MockNegotiationBloc bloc;

  setUpAll(() {
    registerFallbackValue(const NegotiationFetchRequested('t-1'));
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    getIt.registerFactory<NegotiationBloc>(() => bloc);
  });

  tearDown(() {
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
  });

  Widget wrap({String viewerUserId = 'sender-1'}) => MaterialApp(
        theme: AppTheme.light,
        home: NegotiationThreadScreen(
          threadId: 't-1',
          viewerUserId: viewerUserId,
        ),
      );

  group('NegotiationThreadScreen', () {
    testWidgets('affiche CircularProgressIndicator en état Initial',
        (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche "Négociation" dans l\'AppBar en état Initial',
        (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Négociation'), findsOneWidget);
    });

    testWidgets('affiche le nom du voyageur dans l\'AppBar une fois chargé',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(NegotiationLoaded(_thread(travelerName: 'Fatou Ndiaye')));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Fatou Ndiaye'), findsOneWidget);
    });

    testWidgets('affiche la note et les trajets si disponibles', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationLoaded(
        _thread(
          travelerName: 'Fatou Ndiaye',
          travelerRating: 4.9,
          travelerTripsCount: 24,
        ),
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('★4.9'), findsOneWidget);
      expect(find.textContaining('24 trajets'), findsOneWidget);
    });

    testWidgets('affiche "Voyageur" si travelerName est null', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(_thread(travelerName: null)),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voyageur'), findsOneWidget);
    });

    testWidgets('n\'affiche pas la note si travelerRating est null',
        (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(
          _thread(travelerRating: null, travelerTripsCount: null),
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('affiche l\'avatar du voyageur une fois chargé', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(_thread()),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets(
        'hero card cliquable au statut AWAITING_PAYMENT côté expéditeur '
        'avec trajet lié', (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.awaitingPayment,
        currentPriceEur: 68,
        roundsCount: 3,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: const [],
        linkedTrip: const LinkedTripSummary(
          announcementId: 'ann-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        ),
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'sender-1'));
      await tester.pumpAndSettle();

      expect(find.text('Voir le trajet lié'), findsOneWidget);

      await tester.tap(find.text('Voir le trajet lié'));
      await tester.pumpAndSettle();
      expect(find.text('Trajet lié'), findsOneWidget);
    });

    testWidgets(
        'hero card non cliquable côté voyageur même avec trajet lié',
        (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.awaitingPayment,
        currentPriceEur: 68,
        roundsCount: 3,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: const [],
        linkedTrip: const LinkedTripSummary(announcementId: 'ann-1'),
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'tr-1'));
      await tester.pumpAndSettle();

      expect(find.text('Voir le trajet lié'), findsNothing);
    });

    testWidgets('affiche le thread dans NegotiationActionInProgress',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(NegotiationActionInProgress(_thread()));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Fatou Ndiaye'), findsOneWidget);
    });

    testWidgets('affiche les messages quand le thread en contient',
        (tester) async {
      final messages = [
        _msg(fromUserId: 'tr-1', kind: NegotiationMessageKind.proposal,
            proposedPriceEur: 50),
        _msg(id: 'm-2', fromUserId: 'sender-1',
            kind: NegotiationMessageKind.counter, proposedPriceEur: 45),
      ];
      when(() => bloc.state)
          .thenReturn(NegotiationLoaded(_thread(messages: messages)));
      await tester.pumpWidget(wrap(viewerUserId: 'sender-1'));
      await tester.pumpAndSettle();
      // Both messages rendered (ThreadMessageBubble for each)
      expect(find.textContaining('50'), findsWidgets);
    });

    testWidgets('isTripRefusal true pour REJECT dans un thread non-rejected',
        (tester) async {
      final messages = [
        _msg(fromUserId: 'sender-1', kind: NegotiationMessageKind.reject,
            proposedPriceEur: null),
      ];
      when(() => bloc.state).thenReturn(NegotiationLoaded(
        _thread(
          status: NegotiationThreadStatus.awaitingTrip,
          messages: messages,
        ),
      ));
      await tester.pumpWidget(wrap(viewerUserId: 'tr-1'));
      await tester.pumpAndSettle();
      // The REJECT message in non-rejected thread renders as trip refusal banner
      expect(find.textContaining('Trajet refusé par l\'expéditeur'), findsOneWidget);
    });

    testWidgets(
        'affiche Snackbar "Négociation rejetée" quand l\'état est NegotiationRejected',
        (tester) async {
      // Use whenListen helper from bloc_test to properly set up a mock stream.
      // Emit Rejected after the initial state so the listener fires post-build.
      whenListen(
        bloc,
        Stream.fromIterable([
          const NegotiationRejected('t-1'),
        ]),
        initialState: const NegotiationInitial(),
      );

      // Wrap with GoRouter. The screen calls ctx.pop(), which requires at least
      // one page below it on the stack. We push the screen via a ShellRoute or
      // use a Navigator-redirect: simplest is Navigator.canPop guard via popScope
      // workaround — but here the real fix is to use a parent/child route so the
      // sub-route has a page below it.
      final router = GoRouter(
        initialLocation: '/home/thread',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home')),
            routes: [
              GoRoute(
                path: 'thread',
                builder: (_, __) => NegotiationThreadScreen(
                  threadId: 't-1',
                  viewerUserId: 'sender-1',
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ));
      await tester.pump(); // let GoRouter settle

      // Pump to process stream events
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The snackbar should appear before the pop animation completes
      expect(find.text('Négociation rejetée'), findsOneWidget);
    });

    testWidgets(
        'émet NegotiationFetchRequested au refresh de la liste',
        (tester) async {
      final messages = [
        _msg(fromUserId: 'tr-1', kind: NegotiationMessageKind.proposal,
            proposedPriceEur: 50),
      ];
      when(() => bloc.state)
          .thenReturn(NegotiationLoaded(_thread(messages: messages)));
      when(() => bloc.add(any())).thenReturn(null);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Clear previous calls (initial fetch on build)
      clearInteractions(bloc);

      // Pull-to-refresh
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => bloc.add(const NegotiationFetchRequested('t-1'))).called(1);
    });

    testWidgets(
        'message REJECT dans un thread expiré → bulle REJETÉE, pas bandeau',
        (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.expired,
        currentPriceEur: 40,
        roundsCount: 2,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: [
          NegotiationMessage(
            id: 'm-1',
            threadId: 't-1',
            fromUserId: 'sender-1',
            kind: NegotiationMessageKind.reject,
            body: 'Trop tard',
            createdAt: DateTime(2026, 5, 10, 10),
          ),
        ],
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'tr-1'));
      await tester.pumpAndSettle();

      expect(find.text('REJETÉE'), findsOneWidget);
      expect(find.text('Trajet refusé par l\'expéditeur'), findsNothing);
    });

    testWidgets(
        'hero card non cliquable si linkedTrip absent au statut '
        'AWAITING_PAYMENT', (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.awaitingPayment,
        currentPriceEur: 68,
        roundsCount: 3,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: const [],
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'sender-1'));
      await tester.pumpAndSettle();

      expect(find.text('Voir le trajet lié'), findsNothing);
    });
  });
}
