import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NegotiationThread _thread({
  required NegotiationThreadStatus status,
  double price = 42,
  int rounds = 1,
}) =>
    NegotiationThread(
      id: 't1',
      packageRequestId: 'pr1',
      travelerId: 'traveler-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: status,
      currentPriceEur: price,
      roundsCount: rounds,
      lastActivityAt: DateTime(2026, 5, 11, 10),
      createdAt: DateTime(2026, 5, 11, 9),
      messages: const [],
    );

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ThreadStatusVariant.fromThread', () {
    test('mappe les 7 statuts vers les 5 variants', () {
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.open),
        ThreadStatusVariant.open,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.awaitingTrip),
        ThreadStatusVariant.awaitingTrip,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.awaitingPayment),
        ThreadStatusVariant.awaitingPayment,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.accepted),
        ThreadStatusVariant.accepted,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.rejected),
        ThreadStatusVariant.terminal,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.autoRejected),
        ThreadStatusVariant.terminal,
      );
      expect(
        ThreadStatusVariant.fromThread(NegotiationThreadStatus.expired),
        ThreadStatusVariant.terminal,
      );
    });
  });

  group('ThreadHeroCard rendering', () {
    testWidgets('affiche prix + label "EN COURS" + Round X/5 pour OPEN',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.open, price: 42, rounds: 1),
        statusVariant: ThreadStatusVariant.open,
      )));
      expect(find.text('42 €'), findsOneWidget);
      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('Round 1/5'), findsOneWidget);
      expect(find.text('PRIX ACTUEL'), findsOneWidget);
    });

    testWidgets('label "ATT. TRAJET" pour AWAITING_TRIP', (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread:
            _thread(status: NegotiationThreadStatus.awaitingTrip, rounds: 3),
        statusVariant: ThreadStatusVariant.awaitingTrip,
      )));
      expect(find.text('ATT. TRAJET'), findsOneWidget);
      expect(find.text('ACCORD TROUVÉ'), findsOneWidget);
      expect(find.text('Round 3/5'), findsOneWidget);
    });

    testWidgets('label "PAIEMENT" pour AWAITING_PAYMENT', (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.awaitingPayment),
        statusVariant: ThreadStatusVariant.awaitingPayment,
      )));
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(find.text('À RÉGLER'), findsOneWidget);
    });

    testWidgets('label "ACCEPTÉE" pour ACCEPTED', (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.accepted),
        statusVariant: ThreadStatusVariant.accepted,
      )));
      expect(find.text('ACCEPTÉE'), findsOneWidget);
      expect(find.text('DEMANDE ACCEPTÉE'), findsOneWidget);
    });

    testWidgets('label "TERMINÉ" pour rejected', (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.rejected),
        statusVariant: ThreadStatusVariant.terminal,
      )));
      expect(find.text('TERMINÉ'), findsOneWidget);
      expect(find.text('PRIX FINAL'), findsOneWidget);
    });
  });

  group('ThreadHeroCard onTap', () {
    testWidgets('sans onTap → pas d\'affordance "Voir le trajet lié"',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.awaitingPayment),
        statusVariant: ThreadStatusVariant.awaitingPayment,
      )));
      expect(find.text('Voir le trajet lié'), findsNothing);
    });

    testWidgets('avec onTap → affordance affichée et tap déclenché',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.awaitingPayment),
        statusVariant: ThreadStatusVariant.awaitingPayment,
        onTap: () => tapped = true,
      )));
      expect(find.text('Voir le trajet lié'), findsOneWidget);

      await tester.tap(find.text('Voir le trajet lié'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
