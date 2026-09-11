import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

const String _viewerSender = 'sender-viewer';
const String _viewerTraveler = 'traveler-1';

NegotiationThread _thread({
  required NegotiationThreadStatus status,
  bool lastFromViewer = false,
  String viewer = _viewerSender,
  bool canAccept = false,
  bool canCounter = true,
  PaymentMethod? paymentMethod,
  String? materializedBidId,
  bool canNudge = false,
  DateTime? depositExpiresAt,
}) {
  final messages = <NegotiationMessage>[
    NegotiationMessage(
      id: 'm1',
      threadId: 't1',
      fromUserId: lastFromViewer ? viewer : 'other-user',
      kind: NegotiationMessageKind.counter,
      proposedPriceEur: 38,
      createdAt: DateTime(2026, 5, 11, 10),
    ),
  ];
  return NegotiationThread(
    id: 't1',
    packageRequestId: 'pr1',
    travelerId: 'traveler-1',
    travelerTravelDate: DateTime(2026, 6, 15),
    travelerAvailableKg: 10,
    status: status,
    currentPriceEur: 38,
    roundsCount: 1,
    canAccept: canAccept,
    canCounter: canCounter,
    lastActivityAt: DateTime(2026, 5, 11, 10),
    createdAt: DateTime(2026, 5, 11, 9),
    messages: messages,
    paymentMethod: paymentMethod,
    materializedBidId: materializedBidId,
    canNudge: canNudge,
    depositExpiresAt: depositExpiresAt,
  );
}

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() {
    setDonyCommissionRate(0.12);
    // `verifyNever(bloc.add(any()))` a besoin d'une valeur de repli typée.
    registerFallbackValue(const NegotiationFetchRequested('fallback'));
  });
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Widget wrap(NegotiationThread thread, String viewerUserId) => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<NegotiationBloc>.value(
      value: bloc,
      child: Scaffold(
        body: ThreadStateCtaBar(
          thread: thread,
          viewerUserId: viewerUserId,
          actionInProgress: false,
        ),
      ),
    ),
  );

  // Variante avec GoRouter pour vérifier la navigation vers /bids/:bidId.
  String? lastPushedLocation;
  Widget wrapRouter(NegotiationThread thread, String viewerUserId) {
    lastPushedLocation = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<NegotiationBloc>.value(
            value: bloc,
            child: Scaffold(
              body: ThreadStateCtaBar(
                thread: thread,
                viewerUserId: viewerUserId,
                actionInProgress: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/bids/:bidId',
          builder: (context, state) {
            lastPushedLocation = state.uri.toString();
            return const Scaffold(body: Text('Bid detail'));
          },
        ),
        GoRoute(
          path: '/negotiations/:id/mobile-money/awaiting',
          builder: (context, state) {
            lastPushedLocation = state.uri.toString();
            return const Scaffold(body: Text('Awaiting stub'));
          },
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
  }

  group('ThreadStateCtaBar matrix', () {
    testWidgets(
      'OPEN · sender · !lastFromMe → 3 boutons (Accepter — Tu paies / Contre / Rejeter)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.open, canAccept: true),
            _viewerSender,
          ),
        );
        // Sender sees gross exact: 38 * 1.12 = 42.56 → "42,56 €"
        expect(find.text('Accepter : Tu paies 42,56 €'), findsOneWidget);
        expect(find.text('Contre-offre'), findsOneWidget);
        expect(find.text('Rejeter'), findsOneWidget);
      },
    );

    testWidgets(
      'OPEN · traveler · !lastFromMe · canAccept=false → Rejeter + Contre uniquement',
      (tester) async {
        await tester.pumpWidget(
          wrap(_thread(status: NegotiationThreadStatus.open), _viewerTraveler),
        );
        expect(find.textContaining('Accepter : Tu reçois'), findsNothing);
        expect(find.text('Contre-offre'), findsOneWidget);
        expect(find.text('Rejeter'), findsOneWidget);
      },
    );

    testWidgets(
      'OPEN · traveler · !lastFromMe · canAccept=true → Accepter + Rejeter + Contre',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.open, canAccept: true),
            _viewerTraveler,
          ),
        );
        // Traveler sees net: "Accepter — Tu reçois 38 €"
        expect(find.textContaining('Accepter : Tu reçois 38'), findsOneWidget);
        expect(find.text('Contre-offre'), findsOneWidget);
        expect(find.text('Rejeter'), findsOneWidget);
      },
    );

    testWidgets(
      'OPEN · traveler · !lastFromMe · canCounter=false → Rejeter uniquement (dernier round)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.open,
              canAccept: true,
              canCounter: false,
            ),
            _viewerTraveler,
          ),
        );
        expect(find.textContaining('Accepter : Tu reçois 38'), findsOneWidget);
        expect(find.text('Contre-offre'), findsNothing);
        expect(find.text('Rejeter'), findsOneWidget);
      },
    );

    testWidgets('OPEN · lastFromMe → banner "En attente de la réponse"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(status: NegotiationThreadStatus.open, lastFromViewer: true),
          _viewerSender,
        ),
      );
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text('En attente de la réponse'), findsOneWidget);
      expect(find.textContaining('Accepter'), findsNothing);
    });

    testWidgets(
      'AWAITING_TRIP · sender → banner "Le voyageur prépare son trajet"',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.awaitingTrip),
            _viewerSender,
          ),
        );
        expect(find.byType(ThreadStateBanner), findsOneWidget);
        expect(find.text('Le voyageur prépare son trajet'), findsOneWidget);
      },
    );

    testWidgets(
      'AWAITING_TRIP · traveler → boutons "Lier un trajet" + "Créer un trajet dédié"',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.awaitingTrip),
            _viewerTraveler,
          ),
        );
        expect(find.text('Lier un trajet à cette offre'), findsOneWidget);
        expect(find.text('Créer un trajet dédié'), findsOneWidget);
      },
    );

    testWidgets(
      'AWAITING_PAYMENT · sender → bouton "Compléter & payer X €" avec gross',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.awaitingPayment),
            _viewerSender,
          ),
        );
        // Sender sees gross exact: 38 * 1.12 = 42.56 → "42,56 €"
        expect(find.text('Compléter & payer 42,56 €'), findsOneWidget);
      },
    );

    testWidgets(
      'AWAITING_PAYMENT · traveler → banner "En attente du paiement"',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.awaitingPayment),
            _viewerTraveler,
          ),
        );
        expect(find.byType(ThreadStateBanner), findsOneWidget);
        expect(
          find.text('En attente du paiement de l\'expéditeur'),
          findsOneWidget,
        );
      },
    );

    testWidgets('ACCEPTED → banner "Demande acceptée et payée"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(_thread(status: NegotiationThreadStatus.accepted), _viewerSender),
      );
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text('Demande acceptée et payée'), findsOneWidget);
    });

    testWidgets(
      'ACCEPTED · mobileMoney → "Demande acceptée et payée" (réglé en ligne)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.accepted,
              paymentMethod: PaymentMethod.mobileMoney,
            ),
            _viewerSender,
          ),
        );
        expect(find.text('Demande acceptée et payée'), findsOneWidget);
        expect(
          find.text('Tu peux passer aux étapes suivantes du suivi.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ACCEPTED · cash → "Demande acceptée" (pas "payée") + paiement à la remise',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.accepted,
              paymentMethod: PaymentMethod.cash,
            ),
            _viewerSender,
          ),
        );
        expect(find.text('Demande acceptée'), findsOneWidget);
        expect(find.text('Demande acceptée et payée'), findsNothing);
        expect(
          find.text('Le paiement se fait en espèces à la remise du colis.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ACCEPTED · materializedBidId présent → bouton "Voir mon envoi" visible',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.accepted,
              materializedBidId: 'bid-123',
            ),
            _viewerSender,
          ),
        );
        expect(find.byType(ThreadStateBanner), findsOneWidget);
        expect(find.text('Voir mon envoi'), findsOneWidget);
      },
    );

    testWidgets(
      'ACCEPTED · materializedBidId absent → bouton "Voir mon envoi" caché',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.accepted),
            _viewerSender,
          ),
        );
        expect(find.byType(ThreadStateBanner), findsOneWidget);
        expect(find.text('Voir mon envoi'), findsNothing);
      },
    );

    testWidgets('ACCEPTED · tap "Voir mon envoi" → navigue vers /bids/{id}', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapRouter(
          _thread(
            status: NegotiationThreadStatus.accepted,
            materializedBidId: 'bid-123',
          ),
          _viewerSender,
        ),
      );
      await tester.tap(find.text('Voir mon envoi'));
      await tester.pumpAndSettle();
      expect(lastPushedLocation, '/bids/bid-123');
      expect(find.text('Bid detail'), findsOneWidget);
    });

    testWidgets('REJECTED → rien (SizedBox.shrink)', (tester) async {
      await tester.pumpWidget(
        wrap(_thread(status: NegotiationThreadStatus.rejected), _viewerSender),
      );
      expect(find.byType(ThreadStateBanner), findsNothing);
      expect(find.textContaining('Accepter'), findsNothing);
      expect(find.text('Contre-offre'), findsNothing);
    });
  });

  group('AWAITING_DEPOSIT (dépôt mobile money en cours)', () {
    testWidgets(
      'sender · échéance future → banner + « Expire dans N min » + deux boutons',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingDeposit,
              depositExpiresAt: DateTime.now().toUtc().add(
                const Duration(minutes: 20),
              ),
            ),
            _viewerSender,
          ),
        );
        expect(find.byType(ThreadStateBanner), findsOneWidget);
        expect(find.text('Dépôt mobile money en cours'), findsOneWidget);
        expect(find.textContaining('Expire dans'), findsOneWidget);
        expect(find.textContaining(' min.'), findsOneWidget);
        expect(find.text('Reprendre le paiement'), findsOneWidget);
        expect(find.text('Changer de moyen de paiement'), findsOneWidget);
        // Plus de bouton « payer » classique : le dépôt est déjà lancé.
        expect(find.textContaining('Compléter & payer'), findsNothing);
      },
    );

    testWidgets(
      'sender · échéance passée → sous-titre « délai écoulé », boutons présents',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingDeposit,
              depositExpiresAt: DateTime.now().toUtc().subtract(
                const Duration(minutes: 2),
              ),
            ),
            _viewerSender,
          ),
        );
        expect(find.textContaining('Le délai est écoulé'), findsOneWidget);
        expect(find.textContaining('Expire dans'), findsNothing);
        expect(find.text('Reprendre le paiement'), findsOneWidget);
        expect(find.text('Changer de moyen de paiement'), findsOneWidget);
      },
    );

    testWidgets(
      'sender · échéance absente → traité comme écoulé (pas de plantage)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(status: NegotiationThreadStatus.awaitingDeposit),
            _viewerSender,
          ),
        );
        expect(find.textContaining('Le délai est écoulé'), findsOneWidget);
      },
    );

    testWidgets('sender · tap « Changer de moyen de paiement » → '
        'NegotiationCancelDepositRequested(thread.id)', (tester) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingDeposit,
            depositExpiresAt: DateTime.now().toUtc().add(
              const Duration(minutes: 20),
            ),
          ),
          _viewerSender,
        ),
      );
      await tester.tap(find.text('Changer de moyen de paiement'));
      await tester.pump();
      verify(
        () => bloc.add(const NegotiationCancelDepositRequested('t1')),
      ).called(1);
    });

    testWidgets(
      'sender · tap « Reprendre le paiement » → pousse la route d\'attente '
      'mobile money du fil',
      (tester) async {
        await tester.pumpWidget(
          wrapRouter(
            _thread(
              status: NegotiationThreadStatus.awaitingDeposit,
              depositExpiresAt: DateTime.now().toUtc().add(
                const Duration(minutes: 20),
              ),
            ),
            _viewerSender,
          ),
        );
        await tester.tap(find.text('Reprendre le paiement'));
        await tester.pumpAndSettle();
        expect(lastPushedLocation, '/negotiations/t1/mobile-money/awaiting');
        expect(find.text('Awaiting stub'), findsOneWidget);
      },
    );

    testWidgets(
      'sender · actionInProgress → les deux boutons sont désactivés',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: BlocProvider<NegotiationBloc>.value(
              value: bloc,
              child: Scaffold(
                body: ThreadStateCtaBar(
                  thread: _thread(
                    status: NegotiationThreadStatus.awaitingDeposit,
                    depositExpiresAt: DateTime.now().toUtc().add(
                      const Duration(minutes: 20),
                    ),
                  ),
                  viewerUserId: _viewerSender,
                  actionInProgress: true,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Changer de moyen de paiement'));
        await tester.pump();
        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets('traveler → banner seul, aucun bouton', (tester) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingDeposit,
            depositExpiresAt: DateTime.now().toUtc().add(
              const Duration(minutes: 20),
            ),
          ),
          _viewerTraveler,
        ),
      );
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text("L'expéditeur règle par mobile money"), findsOneWidget);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.text('Reprendre le paiement'), findsNothing);
      expect(find.text('Changer de moyen de paiement'), findsNothing);
    });
  });

  group('Bouton Relancer (nudge)', () {
    testWidgets('canNudge=false → bouton "Relancer" absent', (tester) async {
      await tester.pumpWidget(
        wrap(_thread(status: NegotiationThreadStatus.open), _viewerSender),
      );
      expect(find.text('Relancer'), findsNothing);
    });

    testWidgets('canNudge=true → bouton "Relancer" visible', (tester) async {
      await tester.pumpWidget(
        wrap(
          _thread(status: NegotiationThreadStatus.awaitingTrip, canNudge: true),
          _viewerSender,
        ),
      );
      expect(find.text('Relancer'), findsOneWidget);
    });

    testWidgets(
      'canNudge=true → tap "Relancer" dispatch NegotiationNudgeRequested(thread.id)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingTrip,
              canNudge: true,
            ),
            _viewerSender,
          ),
        );
        await tester.tap(find.text('Relancer'));
        await tester.pump();

        verify(() => bloc.add(const NegotiationNudgeRequested('t1'))).called(1);
      },
    );
  });
}
