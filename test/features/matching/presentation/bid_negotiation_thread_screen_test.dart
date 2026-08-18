import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

const _kSettle = Duration(milliseconds: 600);

BidNegotiation _thread({
  bool myTurn = true,
  bool canCounter = true,
  double? netEur,
  String status = 'NEGOTIATING',
  int round = 1,
}) => BidNegotiation(
  bidId: 'bid1',
  announcementId: 'ann1',
  status: status,
  round: round,
  maxRounds: 6,
  myTurn: myTurn,
  canCounter: canCounter,
  proposedGrossEur: 42,
  netEur: netEur,
  commissionEur: netEur == null ? null : 5,
  weightKg: 3,
  description: 'Deux paires de chaussures',
  contentCategory: 'Chaussures',
  gridItems: const [
    BidGridLine(
      id: 'g1',
      label: 'Carton moyen',
      unitPriceDisplayEur: 12,
      quantity: 1,
    ),
  ],
  customItems: const [
    BidCustomItem(id: 'c1', label: 'Sac de riz', quantity: 2, amountEur: 9),
  ],
  photoUrls: const ['https://example.test/photo-1.jpg'],
  counterpartyName: 'Mamadou Diallo',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  messages: const [
    BidNegotiationMessage(
      id: 'm1',
      kind: BidNegotiationMessageKind.proposal,
      authorId: 'sender-1',
      proposedGrossEur: 42,
      body: 'Je propose 42 euros pour le tout.',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNegotiationBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
  });

  Widget wrap(BidNegotiationState state) {
    whenListen(
      bloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: state,
    );
    return BlocProvider<BidNegotiationBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const BidNegotiationThreadScreen(bidId: 'bid1'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, BidNegotiationState s) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(s));
    await tester.pump(_kSettle);
  }

  testWidgets('l etat de chargement affiche un indicateur', (tester) async {
    await pumpScreen(tester, const BidNegotiationLoading());

    expect(find.byKey(const Key('nego-loading')), findsOneWidget);
  });

  testWidgets('l etat d erreur propose de reessayer', (tester) async {
    await pumpScreen(tester, const BidNegotiationError(OfflineException()));

    expect(find.byKey(const Key('nego-error')), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump(_kSettle);

    final refetch = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationFetchRequested>().toList();
    expect(refetch, isNotEmpty);
  });

  testWidgets('le fil charge affiche le recapitulatif complet du colis', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    expect(find.textContaining('3 kg'), findsWidgets);
    expect(find.text('Carton moyen'), findsOneWidget);
    expect(find.text('Sac de riz'), findsOneWidget);
    expect(find.text('Deux paires de chaussures'), findsOneWidget);
    expect(find.byKey(const Key('nego-photo-0')), findsOneWidget);
    expect(find.text('Je propose 42 euros pour le tout.'), findsOneWidget);
  });

  testWidgets('les trois actions sont la quand c est mon tour', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    expect(find.byKey(const Key('nego-accept-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-counter-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-reject-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-waiting-hint')), findsNothing);
  });

  testWidgets('les actions disparaissent quand c est le tour de l autre', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

    expect(find.byKey(const Key('nego-accept-btn')), findsNothing);
    expect(find.byKey(const Key('nego-counter-btn')), findsNothing);
    expect(find.byKey(const Key('nego-reject-btn')), findsNothing);
    expect(find.byKey(const Key('nego-waiting-hint')), findsOneWidget);
  });

  testWidgets('au plafond de tours la contre-offre est desactivee', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      BidNegotiationLoaded(_thread(canCounter: false, round: 6)),
    );

    final counter = tester.widget<DonyButton>(
      find.byKey(const Key('nego-counter-btn')),
    );
    expect(counter.onPressed, isNull);
    final accept = tester.widget<DonyButton>(
      find.byKey(const Key('nego-accept-btn')),
    );
    expect(accept.onPressed, isNotNull);
  });

  testWidgets('le voyageur voit son net, jamais le total brut seul', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    expect(find.byKey(const Key('nego-net-amount')), findsOneWidget);
    expect(find.textContaining('37'), findsWidgets);
  });

  testWidgets('l expediteur voit le total, sans ligne de net', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    expect(find.byKey(const Key('nego-net-amount')), findsNothing);
    expect(find.byKey(const Key('nego-total-amount')), findsOneWidget);
  });

  testWidgets('l ouverture marque le fil comme lu', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    final read = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationReadRequested>().toList();
    expect(read, hasLength(1));
    expect(read.single.bidId, 'bid1');
  });

  testWidgets('accepter emet BidNegotiationAcceptRequested', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    await tester.tap(find.byKey(const Key('nego-accept-btn')));
    await tester.pump(_kSettle);

    final accepted = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationAcceptRequested>().toList();
    expect(accepted, hasLength(1));
  });

  testWidgets('refuser emet BidNegotiationRejectRequested', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    await tester.tap(find.byKey(const Key('nego-reject-btn')));
    await tester.pump(_kSettle);

    final rejected = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationRejectRequested>().toList();
    expect(rejected, hasLength(1));
  });

  testWidgets('un fil clos n affiche plus aucune action', (tester) async {
    await pumpScreen(
      tester,
      BidNegotiationLoaded(_thread(status: 'ACCEPTED', myTurn: false)),
    );

    expect(find.byKey(const Key('nego-accept-btn')), findsNothing);
    expect(find.byKey(const Key('nego-closed-hint')), findsOneWidget);
  });
}
