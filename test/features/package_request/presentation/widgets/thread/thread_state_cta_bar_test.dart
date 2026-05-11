import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

const String _viewerSender = 'sender-viewer';
const String _viewerTraveler = 'traveler-1';

NegotiationThread _thread({
  required NegotiationThreadStatus status,
  bool lastFromViewer = false,
  String viewer = _viewerSender,
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
    lastActivityAt: DateTime(2026, 5, 11, 10),
    createdAt: DateTime(2026, 5, 11, 9),
    messages: messages,
  );
}

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Widget wrap(NegotiationThread thread, String viewerUserId) => MaterialApp(
        theme: AppTheme.light,
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

  group('ThreadStateCtaBar matrix', () {
    testWidgets(
        'OPEN · sender · !lastFromMe → 3 boutons (Accepter / Contre / Rejeter)',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.open),
        _viewerSender,
      ));
      expect(find.text('Accepter 38 €'), findsOneWidget);
      expect(find.text('Contre-offre'), findsOneWidget);
      expect(find.text('Rejeter'), findsOneWidget);
    });

    testWidgets('OPEN · traveler · !lastFromMe → 2 boutons (Rejeter / Contre)',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.open),
        _viewerTraveler,
      ));
      expect(find.text('Accepter 38 €'), findsNothing);
      expect(find.text('Contre-offre'), findsOneWidget);
      expect(find.text('Rejeter'), findsOneWidget);
    });

    testWidgets('OPEN · lastFromMe → banner "En attente de la réponse"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(
          status: NegotiationThreadStatus.open,
          lastFromViewer: true,
        ),
        _viewerSender,
      ));
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text('En attente de la réponse'), findsOneWidget);
      expect(find.text('Accepter 38 €'), findsNothing);
    });

    testWidgets(
        'AWAITING_TRIP · sender → banner "Le voyageur prépare son trajet"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.awaitingTrip),
        _viewerSender,
      ));
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text('Le voyageur prépare son trajet'), findsOneWidget);
    });

    testWidgets('AWAITING_TRIP · traveler → bouton "Lier un trajet"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.awaitingTrip),
        _viewerTraveler,
      ));
      expect(find.text('Lier un trajet à cette offre'), findsOneWidget);
    });

    testWidgets('AWAITING_PAYMENT · sender → bouton "Payer X €"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.awaitingPayment),
        _viewerSender,
      ));
      expect(find.text('Payer 38 €'), findsOneWidget);
    });

    testWidgets('AWAITING_PAYMENT · traveler → banner "En attente du paiement"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.awaitingPayment),
        _viewerTraveler,
      ));
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(
          find.text('En attente du paiement de l\'expéditeur'), findsOneWidget);
    });

    testWidgets('ACCEPTED → banner "Demande acceptée et payée"',
        (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.accepted),
        _viewerSender,
      ));
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(find.text('Demande acceptée et payée'), findsOneWidget);
    });

    testWidgets('REJECTED → rien (SizedBox.shrink)', (tester) async {
      await tester.pumpWidget(wrap(
        _thread(status: NegotiationThreadStatus.rejected),
        _viewerSender,
      ));
      expect(find.byType(ThreadStateBanner), findsNothing);
      expect(find.text('Accepter 38 €'), findsNothing);
      expect(find.text('Contre-offre'), findsNothing);
    });
  });
}
