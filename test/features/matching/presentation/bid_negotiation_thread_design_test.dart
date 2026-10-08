import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/nego_archive_actions.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockRepo extends Mock implements BidNegotiationRepository {}

const _kSettle = Duration(milliseconds: 600);

const _proposal = BidNegotiationMessage(
  id: 'm1',
  kind: BidNegotiationMessageKind.proposal,
  authorId: 'sender-1',
  proposedGrossEur: 42,
  body: 'Je propose 42 euros.',
);

const _counter = BidNegotiationMessage(
  id: 'm2',
  kind: BidNegotiationMessageKind.counter,
  authorId: 'traveler-1',
  proposedGrossEur: 50,
  body: 'Plutôt 50.',
);

const _reject = BidNegotiationMessage(
  id: 'm3',
  kind: BidNegotiationMessageKind.reject,
  authorId: 'traveler-1',
);

BidNegotiation _thread({
  String status = 'NEGOTIATING',
  String role = 'SENDER',
  bool myTurn = true,
  bool canCounter = true,
  bool archived = false,
  BidPaymentMethod? paymentMethod,
  List<BidNegotiationMessage> messages = const [_proposal, _counter],
}) => BidNegotiation(
  bidId: 'bid1',
  announcementId: 'ann1',
  status: status,
  role: role,
  round: 2,
  maxRounds: 6,
  myTurn: myTurn,
  canCounter: canCounter,
  proposedGrossEur: 50,
  netEur: role == 'TRAVELER' ? 44 : null,
  weightKg: 3,
  contentCategory: 'Chaussures',
  counterpartyName: 'Awa Diop',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 3),
  messages: messages,
  paymentMethod: paymentMethod,
  archived: archived,
);

/// Fil de prix d'un trajet aligné sur le fil « demande de colis »
/// (FLUTTER-BM) : carte héros, bulles, bandeau d'état, qui doit jouer.
void main() {
  late _MockNegotiationBloc bloc;
  late _MockPaymentBloc paymentBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    paymentBloc = _MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => paymentBloc.close()).thenAnswer((_) async {});
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    getIt.registerFactory<PaymentBloc>(() => paymentBloc);
    final repo = _MockRepo();
    when(() => repo.myNegotiations()).thenAnswer((_) async => []);
    if (getIt.isRegistered<BidNegotiationListBloc>()) {
      getIt.unregister<BidNegotiationListBloc>();
    }
    getIt.registerSingleton<BidNegotiationListBloc>(
      BidNegotiationListBloc(repo),
    );
  });

  tearDown(() async {
    await getIt.unregister<PaymentBloc>();
    await getIt.unregister<BidNegotiationListBloc>();
  });

  Future<void> pump(
    WidgetTester tester,
    BidNegotiation thread, {
    String? viewerUserId,
    bool archived = false,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    whenListen(
      bloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: BidNegotiationLoaded(thread),
    );
    await tester.pumpWidget(
      BlocProvider<BidNegotiationBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => BidNegotiationThreadScreen(
                  bidId: 'bid1',
                  viewerUserId: viewerUserId,
                  archived: archived,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(_kSettle);
  }

  DonyNegoHeroCard hero(WidgetTester tester) =>
      tester.widget<DonyNegoHeroCard>(find.byType(DonyNegoHeroCard));

  DonyNegoBubble bubble(WidgetTester tester, String id) =>
      tester.widget<DonyNegoBubble>(find.byKey(Key('nego-bubble-$id')));

  group('tripNegoVariant', () {
    test('suit le statut et le mode de paiement', () {
      expect(tripNegoVariant(_thread()), ThreadStatusVariant.open);
      expect(
        tripNegoVariant(_thread(status: 'AWAITING_PAYMENT')),
        ThreadStatusVariant.awaitingPayment,
      );
      expect(
        tripNegoVariant(
          _thread(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        ThreadStatusVariant.awaitingDeposit,
      );
      expect(
        tripNegoVariant(_thread(status: 'PENDING')),
        ThreadStatusVariant.awaitingCommission,
      );
      expect(
        tripNegoVariant(_thread(status: 'ACCEPTED')),
        ThreadStatusVariant.accepted,
      );
      expect(
        tripNegoVariant(_thread(status: 'NEGOTIATION_CLOSED')),
        ThreadStatusVariant.terminal,
      );
    });
  });

  testWidgets('mon tour : héros en cours, pastille pleine, offre reçue '
      'mise en avant, actions disponibles', (tester) async {
    await pump(tester, _thread(), viewerUserId: 'sender-1');

    final h = hero(tester);
    expect(h.badgeLabel, 'EN COURS');
    expect(h.gradient, ThreadStatusVariant.open.gradient);
    expect(h.myTurn, isTrue);
    expect(find.byKey(const Key('nego-hero-my-turn')), findsOneWidget);
    expect(find.text('À vous de jouer'), findsOneWidget);
    expect(find.text('Tour 2 sur 6'), findsOneWidget);
    expect(find.byKey(const Key('nego-total-amount')), findsOneWidget);

    // Ma proposition à droite, la contre-offre reçue à gauche et marquée.
    expect(bubble(tester, 'm1').mine, isTrue);
    expect(bubble(tester, 'm2').mine, isFalse);
    expect(bubble(tester, 'm2').highlight, isTrue);
    expect(find.text('NOUVEAU'), findsOneWidget);
    expect(find.text('PROPOSITION'), findsOneWidget);
    expect(find.text('CONTRE-OFFRE'), findsOneWidget);

    expect(find.byKey(const Key('nego-accept-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-counter-btn')), findsOneWidget);
    // Le contexte du trajet et de l'interlocuteur est en tête du fil.
    expect(find.byKey(const Key('nego-trip-context')), findsOneWidget);
    expect(find.text('Awa Diop'), findsOneWidget);
  });

  testWidgets(
    'tour de l autre : pastille d attente nommée, bandeau d attente',
    (tester) async {
      await pump(
        tester,
        _thread(myTurn: false, messages: const [_proposal]),
        viewerUserId: 'sender-1',
      );

      expect(find.byKey(const Key('nego-hero-their-turn')), findsOneWidget);
      expect(find.text('Au tour de Awa Diop'), findsOneWidget);
      expect(hero(tester).myTurn, isFalse);
      expect(bubble(tester, 'm1').highlight, isFalse);
      expect(find.text('NOUVEAU'), findsNothing);

      final banner = tester.widget<DonyNegoStateBanner>(
        find.byKey(const Key('nego-waiting-hint')),
      );
      expect(banner.iconAsset, 'hourglass');
      expect(find.byKey(const Key('nego-cancel-btn')), findsOneWidget);
    },
  );

  testWidgets('dernier tour : avertissement dans le héros', (tester) async {
    await pump(tester, _thread(canCounter: false), viewerUserId: 'sender-1');

    expect(
      find.text('⚠ Dernier round : Accepter ou Refuser uniquement'),
      findsOneWidget,
    );
  });

  testWidgets('accepté : héros vert, pas de tour à jouer, bandeau validé', (
    tester,
  ) async {
    await pump(tester, _thread(status: 'ACCEPTED', myTurn: false));

    final h = hero(tester);
    expect(h.badgeLabel, 'ACCEPTÉE');
    expect(h.gradient, ThreadStatusVariant.accepted.gradient);
    expect(h.turnLabel, isNull);
    expect(find.byKey(const Key('nego-hero-my-turn')), findsNothing);
    expect(find.byKey(const Key('nego-hero-their-turn')), findsNothing);

    final banner = tester.widget<DonyNegoStateBanner>(
      find.byKey(const Key('nego-closed-hint')),
    );
    expect(banner.iconAsset, 'circle-check');
    expect(find.byKey(const Key('nego-accept-btn')), findsNothing);
  });

  testWidgets('refusé : héros terminé, bulle de refus, bandeau refusé', (
    tester,
  ) async {
    await pump(
      tester,
      _thread(
        status: 'NEGOTIATION_CLOSED',
        myTurn: false,
        messages: const [_proposal, _counter, _reject],
      ),
      viewerUserId: 'sender-1',
    );

    final h = hero(tester);
    expect(h.badgeLabel, 'TERMINÉ');
    expect(h.gradient, ThreadStatusVariant.terminal.gradient);
    expect(h.turnLabel, isNull);
    expect(find.text('REJETÉE'), findsOneWidget);
    expect(bubble(tester, 'm3').mine, isFalse);

    final banner = tester.widget<DonyNegoStateBanner>(
      find.byKey(const Key('nego-closed-hint')),
    );
    expect(banner.iconAsset, 'circle-x');
    expect(find.text('Proposition refusée.'), findsOneWidget);
    // Fil terminé : le menu d'archivage (FLUTTER-EJ) reste là.
    expect(find.byType(NegoArchiveMenuButton), findsOneWidget);
  });

  testWidgets('archivé : même rendu terminé, menu d archivage conservé', (
    tester,
  ) async {
    await pump(
      tester,
      _thread(status: 'NEGOTIATION_CLOSED', myTurn: false, archived: true),
      archived: true,
    );

    expect(hero(tester).badgeLabel, 'TERMINÉ');
    final menu = tester.widget<NegoArchiveMenuButton>(
      find.byType(NegoArchiveMenuButton),
    );
    expect(menu.archived, isTrue);
    expect(find.byKey(const Key('nego-closed-hint')), findsOneWidget);
  });

  testWidgets('voyageur sans utilisateur connu : côté des bulles déduit du '
      'rôle et de l auteur de la proposition', (tester) async {
    await pump(tester, _thread(role: 'TRAVELER'));

    expect(bubble(tester, 'm1').mine, isFalse);
    expect(bubble(tester, 'm2').mine, isTrue);
    expect(find.byKey(const Key('nego-net-amount')), findsOneWidget);
    expect(hero(tester).caption, 'Vous recevriez');
  });

  testWidgets('expéditeur sans utilisateur connu : sa proposition à droite', (
    tester,
  ) async {
    await pump(tester, _thread());

    expect(bubble(tester, 'm1').mine, isTrue);
    expect(bubble(tester, 'm2').mine, isFalse);
  });

  testWidgets('sans proposition connue, aucune bulle n est attribuée', (
    tester,
  ) async {
    await pump(tester, _thread(messages: const [_counter]));

    expect(bubble(tester, 'm2').mine, isFalse);
  });

  testWidgets('paiement carte attendu : bandeau violet et bouton Payer', (
    tester,
  ) async {
    await pump(tester, _thread(status: 'AWAITING_PAYMENT', myTurn: false));

    expect(hero(tester).badgeLabel, 'PAIEMENT');
    final banner = tester.widget<DonyNegoStateBanner>(
      find.byKey(const Key('nego-pay-hint')),
    );
    expect(banner.iconAsset, 'credit-card');
    expect(banner.tint, DonyColors.threadStatusViolet);
    expect(find.byKey(const Key('nego-pay-btn')), findsOneWidget);
  });

  testWidgets('espèces côté voyageur : bandeau commission orange', (
    tester,
  ) async {
    await pump(
      tester,
      _thread(status: 'PENDING', role: 'TRAVELER', myTurn: false),
    );

    final banner = tester.widget<DonyNegoStateBanner>(
      find.byKey(const Key('nego-awaiting-traveler-hint')),
    );
    expect(banner.iconAsset, 'banknote');
    expect(banner.tint, DonyColors.threadStatusOrange);
  });
}
