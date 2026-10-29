import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'PENDING',
  String? cancellationNoShowStatus,
  DateTime? contestationDeadline,
  DateTime? handoverDeadline,
  String? handoverLocation,
  String? travelerName,
  String? recipientName,
  String? arrivalCity,
  String? arrivalTime,
  String? confirmationCode,
  double? totalAmountEur,
  DateTime? departureDate,
  String? deliveryNoShowStatus,
  bool? deliveryNoShowReportedByTraveler,
  String? arrivalInstructions,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  bool pickupCodeRenewalNeeded = false,
}) => BidModel(
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  paymentMethod: paymentMethod,
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  cancellationNoShowStatus: cancellationNoShowStatus,
  contestationDeadline: contestationDeadline,
  handoverDeadline: handoverDeadline,
  handoverLocation: handoverLocation,
  travelerName: travelerName,
  recipientName: recipientName,
  arrivalCity: arrivalCity,
  arrivalTime: arrivalTime,
  confirmationCode: confirmationCode,
  totalAmountEur: totalAmountEur,
  departureDate: departureDate,
  deliveryNoShowStatus: deliveryNoShowStatus,
  deliveryNoShowReportedByTraveler: deliveryNoShowReportedByTraveler,
  arrivalInstructions: arrivalInstructions,
);

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(BidModel bid, _MockCancellationBloc cancellationBloc) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider<CancellationBloc>.value(
        value: cancellationBloc,
        child: SenderHeroCard(bid: bid),
      ),
    ),
  );
}

// ── statusLine ────────────────────────────────────────────────────────────────

/// Lit `SenderHeroCard.statusLine` dans un vrai contexte (traductions).
Future<String?> _statusLine(WidgetTester tester, BidModel bid) async {
  String? line;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          line = SenderHeroCard.statusLine(context, bid);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return line;
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(TravelerNoShowReportRequested('bid-001'));
    registerFallbackValue(BidCancelRequested('bid-001', actor: 'sender'));
    registerFallbackValue(NoShowContestRequested('bid-001'));
    registerFallbackValue(DeliveryNoShowContestRequested('bid-001'));
  });

  late _MockCancellationBloc cancellationBloc;

  setUp(() {
    cancellationBloc = _MockCancellationBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
  });

  // ── Priorité 3 : la bannière d'information n'existe plus ────────────────────
  // Les anciens tests de rendu (statuts PENDING à DELIVERED) deviennent des
  // tests de `statusLine`, le sous-titre repris par les tuiles Suivi et Lieux.

  testWidgets('1 · PENDING cash → statusLine "notifié"', (tester) async {
    final bid = _bid(paymentMethod: BidPaymentMethod.cash);
    final line = await _statusLine(tester, bid);

    expect(line, contains('notifié'));
  });

  testWidgets(
    '1b · PENDING carte non payé → statusLine du paiement séquestré, pas '
    'd\'attente du voyageur (FLUTTER-G7)',
    (tester) async {
      final bid = _bid(totalAmountEur: 45.0);
      final line = await _statusLine(tester, bid);

      expect(line, contains('séquestré'));
      expect(line, isNot(contains('notifié')));
    },
  );

  // ── Test 2: PAYMENT_ESCROWED ─────────────────────────────────────────────────

  testWidgets('2 · PAYMENT_ESCROWED → statusLine "réponse du voyageur"', (
    tester,
  ) async {
    final bid = _bid(status: 'PAYMENT_ESCROWED', totalAmountEur: 45.0);
    final line = await _statusLine(tester, bid);

    // FLUTTER-E5 : payé mais pas encore accepté, on attend le voyageur et
    // non la remise (qui n'a de sens qu'après acceptation, statut ACCEPTED).
    expect(line, contains('En attente de la réponse du voyageur'));
    expect(line, isNot(contains('En attente de remise')));
  });

  testWidgets('2 bis · montant payé : supplément payé compris', (tester) async {
    final bid = BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'PAYMENT_ESCROWED',
      totalAmountEur: 45,
      totalSenderAmountEur: 50,
      totalSenderAmountWithSupplementEur: 66.8,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains(formatPriceIn(66.8, 'EUR')));
    expect(line, isNot(contains(formatPriceIn(50, 'EUR'))));
  });

  // ── Test 3: ACCEPTED fenêtre future ─────────────────────────────────────────

  testWidgets('3 · statusLine for ACCEPTED contains the handover location', (
    tester,
  ) async {
    final now = DateTime.now();
    final bid = _bid(
      status: 'ACCEPTED',
      handoverDeadline: now.add(const Duration(days: 1, hours: 2)),
      handoverLocation: 'Gare de Lyon, Paris',
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains('Gare de Lyon'));
    expect(line, contains("jusqu'au"));
    expect(line, contains('Présentez le QR'));
  });

  testWidgets('3 bis · ACCEPTED sans fenêtre ni lieu → consigne seule', (
    tester,
  ) async {
    final line = await _statusLine(tester, _bid(status: 'ACCEPTED'));

    expect(line, 'Présentez le QR, ou collez-le sur le colis.');
  });

  // ── Test 4: ACCEPTED fenêtre passée ─────────────────────────────────────────

  testWidgets(
    '4 · ACCEPTED fenêtre passée → "Fenêtre de remise dépassée" + bouton signalement',
    (tester) async {
      final now = DateTime.now();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverDeadline: now.subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Fenêtre de remise dépassée'), findsOneWidget);
      expect(
        find.textContaining("Signaler l'absence du voyageur"),
        findsOneWidget,
      );
    },
  );

  // ── Test 5: tap "Signaler" → sheet → confirmation → event dispatched ─────────

  testWidgets(
    '5 · tap "Signaler l\'absence du voyageur" → sheet → bouton → TravelerNoShowReportRequested dispatched',
    (tester) async {
      final now = DateTime.now();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverDeadline: now.subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      // Tap the "Signaler l'absence du voyageur" button in the hero
      await tester.tap(find.textContaining("Signaler l'absence du voyageur"));
      await tester.pumpAndSettle();

      // The confirmation sheet should be visible
      expect(find.textContaining("Signaler l'absence"), findsWidgets);
      // Le back annule et rembourse aussitôt, sans contestation (FLUTTER-E3).
      expect(
        find.text(
          'Votre envoi sera annulé immédiatement. Si vous avez payé en ligne, '
          'vous serez remboursé intégralement.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('pour contester'), findsNothing);

      // Tap the confirmation button in stickyBottom (the DonyButton in the sheet)
      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining("Signaler l'absence"),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      // Verify the event was dispatched exactly once
      verify(
        () => cancellationBloc.add(
          any(that: isA<TravelerNoShowReportRequested>()),
        ),
      ).called(1);
    },
  );

  testWidgets(
    '5 bis · feuille de signalement en anglais : annulation immédiate, '
    'pas de délai de contestation (FLUTTER-E3)',
    (tester) async {
      useEnglish();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.text("Report the traveler's no-show"));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your shipment will be canceled right away. If you paid online, '
          "you'll get a full refund.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('contest'), findsNothing);
    },
  );

  // ── Test 5b/5c : annulation sans faute depuis la fenêtre dépassée ──────────
  // FLUTTER-46/47 : une demande faite après la date limite naissait « fenêtre
  // dépassée » et le seul bouton accusait le voyageur. L'annulation (remboursée,
  // déjà possible via « … ») est désormais proposée sur la carte, en premier.

  testWidgets(
    '5b · fenêtre passée → bouton "Annuler la demande" au-dessus du signalement',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      final cancel = find.text('Annuler la demande');
      final report = find.textContaining("Signaler l'absence du voyageur");
      expect(cancel, findsOneWidget);
      expect(report, findsOneWidget);
      expect(
        tester.getTopLeft(cancel).dy,
        lessThan(tester.getTopLeft(report).dy),
      );
      expect(
        find.textContaining('annuler votre demande sans frais'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '5c · tap "Annuler la demande" → confirmation → BidCancelRequested dispatched',
    (tester) async {
      final bidBloc = _MockBidBloc();
      whenListen<BidState>(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidInitial(),
      );
      final bid = _bid(
        status: 'ACCEPTED',
        handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
      );
      // La confirmation se ferme via GoRouter (ctx.pop()), comme dans l'app.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<CancellationBloc>.value(value: cancellationBloc),
                  BlocProvider<BidBloc>.value(value: bidBloc),
                ],
                child: SenderHeroCard(bid: bid),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Oui, annuler'));
      await tester.pumpAndSettle();

      verify(
        () => bidBloc.add(
          any(
            that: isA<BidCancelRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid-001',
            ),
          ),
        ),
      ).called(1);
      verifyNever(
        () => cancellationBloc.add(
          any(that: isA<TravelerNoShowReportRequested>()),
        ),
      );
    },
  );

  // ── Test 6: PENDING_CONFIRMATION → contestation hero ────────────────────────

  testWidgets(
    '6 · cancellationNoShowStatus PENDING_CONFIRMATION → "Absence signalée" + "Je conteste" + "Je confirme"',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(
          const Duration(hours: 46, minutes: 12),
        ),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(find.textContaining('Je conteste'), findsOneWidget);
      expect(find.textContaining('Je confirme'), findsOneWidget);

      // Kill the timer by replacing the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 7: HANDED_OVER ──────────────────────────────────────────────────────

  testWidgets('7 · HANDED_OVER avant le départ → "Embarquement prévu"', (
    tester,
  ) async {
    final bid = _bid(
      status: 'HANDED_OVER',
      travelerName: 'Mamadou',
      departureDate: DateTime.now().add(const Duration(days: 2)),
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains('Embarquement prévu'));
  });

  testWidgets(
    '7b · HANDED_OVER après le départ, sans scan Transit → en route, plus '
    '« Embarquement prévu »',
    (tester) async {
      final bid = _bid(
        status: 'HANDED_OVER',
        travelerName: 'Mamadou',
        arrivalCity: 'Dakar',
        departureDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      final line = await _statusLine(tester, bid);

      expect(line, contains('En route vers Dakar'));
      expect(line, isNot(contains('Embarquement prévu')));
    },
  );

  // ── Test 8: IN_TRANSIT with confirmationCode ─────────────────────────────────

  testWidgets(
    '8 · IN_TRANSIT avec confirmationCode → arrivée prévue + renvoi au billet',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        confirmationCode: '4829',
        arrivalTime: '14:30',
        arrivalCity: 'Dakar',
        recipientName: 'Fatou',
      );
      final line = await _statusLine(tester, bid);

      expect(line, contains('Arrivée prévue 14:30 à Dakar'));
      // La ligne renvoie au talon (« CODE DE RETRAIT ») sans dire « à qui » —
      // l'instruction de transmission fait autorité sur le talon.
      expect(line, contains('code de retrait'));
      expect(line, contains('billet'));
    },
  );

  // ── Test 8b: ARRIVED avec instructions de retrait ────────────────────────────

  testWidgets(
    '8b · ARRIVED avec arrivalInstructions → renvoi vers l\'encart, sans '
    'doublon du texte',
    (tester) async {
      final bid = _bid(
        status: 'ARRIVED',
        arrivalInstructions: 'Métro Châtelet',
        confirmationCode: '482913',
      );
      final line = await _statusLine(tester, bid);

      // Le texte vit dans ArrivalInstructionsCard : la ligne n'y renvoie que
      // par une phrase.
      expect(line, isNot(contains('Métro Châtelet')));
      expect(
        line,
        'Le voyageur est arrivé. Ses instructions de retrait sont juste en '
        'dessous.',
      );
    },
  );

  // ── Test 8c: ARRIVED sans instructions de retrait ────────────────────────────

  testWidgets(
    '8c · ARRIVED sans arrivalInstructions → message d\'attente générique',
    (tester) async {
      final bid = _bid(status: 'ARRIVED', confirmationCode: '482913');
      final line = await _statusLine(tester, bid);

      expect(line, contains('instructions de retrait arrivent bientôt'));
    },
  );

  // ── Test 9: COMPLETED ────────────────────────────────────────────────────────

  testWidgets('9 · COMPLETED → statusLine "Paiement libéré"', (tester) async {
    final bid = _bid(status: 'COMPLETED', recipientName: 'Drissa');
    final line = await _statusLine(tester, bid);

    expect(line, contains('libéré'));
  });

  testWidgets('14 · DELIVERED → statusLine "Paiement libéré"', (tester) async {
    final bid = _bid(status: 'DELIVERED', recipientName: 'Karim');
    final line = await _statusLine(tester, bid);

    expect(line, contains('libéré'));
  });

  // ── Test 11: AWAITING_PAYMENT ────────────────────────────────────────────────

  testWidgets('11 · AWAITING_PAYMENT → statusLine avec le montant', (
    tester,
  ) async {
    final bid = _bid(status: 'AWAITING_PAYMENT', totalAmountEur: 120.50);
    final line = await _statusLine(tester, bid);

    expect(line, contains('120,50'));
    expect(line, contains('séquestré'));
  });

  // ── Test 12: IN_TRANSIT sans confirmationCode ─────────────────────────────────

  testWidgets('12 · IN_TRANSIT sans confirmationCode → "En route vers"', (
    tester,
  ) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      arrivalCity: 'Dakar',
      arrivalTime: '',
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains('En route vers Dakar'));
    // FLUTTER-G1 : colis remis sans code → le code a été bloqué.
    expect(line, contains('code de retrait a été bloqué'));
  });

  // FLUTTER-G2 : code encore présent mais expiré → on parle d'expiration.
  testWidgets('12c · IN_TRANSIT, code expiré → « a expiré », pas le billet', (
    tester,
  ) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      arrivalCity: 'Dakar',
      arrivalTime: '',
      confirmationCode: '123456',
      pickupCodeRenewalNeeded: true,
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains('Le code de retrait a expiré'));
    expect(line, isNot(contains('a été bloqué')));
  });

  testWidgets('12d · ARRIVED, code expiré → « a expiré » en priorité', (
    tester,
  ) async {
    final bid = _bid(
      status: 'ARRIVED',
      confirmationCode: '123456',
      pickupCodeRenewalNeeded: true,
      arrivalInstructions: 'Gare routière',
    );
    final line = await _statusLine(tester, bid);

    expect(line, contains('Le code de retrait a expiré'));
    expect(line, isNot(contains('a été bloqué')));
  });

  testWidgets('12b · ARRIVED sans confirmationCode → code bloqué en priorité', (
    tester,
  ) async {
    final bid = _bid(status: 'ARRIVED', arrivalCity: 'Dakar');
    final line = await _statusLine(tester, bid);

    expect(line, contains('code de retrait a été bloqué'));
  });

  // ── Test 13: HANDED_OVER departureDate null → "Colis remis." ──────────────────

  testWidgets('13 · HANDED_OVER departureDate=null → "Colis remis."', (
    tester,
  ) async {
    final bid = _bid(status: 'HANDED_OVER', travelerName: 'Amadou');
    final line = await _statusLine(tester, bid);

    expect(line, contains('Colis remis.'));
  });

  // ── Test 10 / 15 : statuts terminaux → pas de ligne ─────────────────────────

  testWidgets('10/15 · statuts terminaux → statusLine null', (tester) async {
    for (final status in [
      'CANCELLED',
      'REJECTED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ]) {
      final line = await _statusLine(tester, _bid(status: status));
      expect(line, isNull, reason: status);
    }
  });

  // ── hasAction : seules les variantes d'action restent ────────────────────────

  group('SenderHeroCard.hasAction', () {
    test('true pour la contestation d\'une absence du voyageur', () {
      expect(
        SenderHeroCard.hasAction(
          _bid(
            status: 'ACCEPTED',
            cancellationNoShowStatus: 'PENDING_CONFIRMATION',
          ),
        ),
        isTrue,
      );
    });

    test('true pour une absence à la livraison en attente ou contestée', () {
      for (final status in ['PENDING_CONFIRMATION', 'CONTESTED']) {
        expect(
          SenderHeroCard.hasAction(
            _bid(status: 'IN_TRANSIT', deliveryNoShowStatus: status),
          ),
          isTrue,
          reason: status,
        );
      }
    });

    test('true pour une fenêtre de dépôt dépassée', () {
      expect(
        SenderHeroCard.hasAction(
          _bid(
            status: 'ACCEPTED',
            handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ),
        isTrue,
      );
    });

    test('false pour une fenêtre de dépôt à venir', () {
      expect(
        SenderHeroCard.hasAction(
          _bid(
            status: 'ACCEPTED',
            handoverDeadline: DateTime.now().add(const Duration(hours: 2)),
          ),
        ),
        isFalse,
      );
    });

    test('false pour une fenêtre dépassée hors ACCEPTED', () {
      expect(
        SenderHeroCard.hasAction(
          _bid(
            status: 'IN_TRANSIT',
            handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ),
        isFalse,
      );
    });

    test('false pour un IN_TRANSIT ordinaire et pour une absence résolue', () {
      expect(SenderHeroCard.hasAction(_bid(status: 'IN_TRANSIT')), isFalse);
      expect(
        SenderHeroCard.hasAction(
          _bid(status: 'IN_TRANSIT', deliveryNoShowStatus: 'RESOLVED'),
        ),
        isFalse,
      );
    });
  });

  testWidgets('hero renders nothing for plain IN_TRANSIT', (tester) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      confirmationCode: '4829',
      arrivalCity: 'Dakar',
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(SenderHeroCard)), Size.zero);
  });

  testWidgets('hero renders nothing for every status without action', (
    tester,
  ) async {
    for (final status in [
      'PENDING',
      'AWAITING_PAYMENT',
      'PAYMENT_ESCROWED',
      'ACCEPTED',
      'HANDED_OVER',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
      'CANCELLED',
    ]) {
      await tester.pumpWidget(_host(_bid(status: status), cancellationBloc));
      await tester.pump();
      expect(find.byType(Text), findsNothing, reason: status);
    }
  });

  // ── Test 16: PENDING_CONFIRMATION deadline null → pas de countdown ────────────

  testWidgets(
    '16 · PENDING_CONFIRMATION deadline=null → "Absence signalée" sans "Temps pour contester"',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(find.textContaining('Temps pour contester'), findsNothing);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 17: PENDING_CONFIRMATION deadline passée → "Délai expiré" ───────────

  testWidgets(
    '17 · PENDING_CONFIRMATION deadline passée → "Délai expiré" affiché',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Délai expiré'), findsOneWidget);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 17b: bannière absence livraison — je suis l'auteur (sender) ───────

  testWidgets(
    'bannière "Absence signalée" si deliveryNoShowReportedByTraveler=false (je suis l\'auteur, expéditeur)',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: false,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence signalée'), findsOneWidget);
    },
  );

  // ── Test 17c: bannière absence livraison — je suis l'adversaire (sender) ───

  testWidgets(
    'bannière "Une absence est signalée" + Contester si deliveryNoShowReportedByTraveler=true (je suis l\'adversaire, expéditeur)',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: true,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Une absence est signalée'), findsOneWidget);
      expect(find.text('Contester ce signalement'), findsOneWidget);
    },
  );

  // ── Test 17d: bannière absence livraison contestée (sender, auteur) ────────

  testWidgets(
    'bannière deliveryNoShowStatus=CONTESTED (auteur, expéditeur) → "Absence contestée"',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        deliveryNoShowStatus: 'CONTESTED',
        deliveryNoShowReportedByTraveler: false,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence contestée'), findsOneWidget);
    },
  );

  // ── Test 17f: bannière absence livraison contestée (sender, adversaire) ────

  testWidgets(
    'bannière deliveryNoShowStatus=CONTESTED (adversaire, expéditeur, je viens de contester) → "Contestation envoyée", pas de bouton',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        deliveryNoShowStatus: 'CONTESTED',
        deliveryNoShowReportedByTraveler: true,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Contestation envoyée'), findsOneWidget);
      expect(find.textContaining('Une absence est signalée'), findsNothing);
      expect(find.text('Contester ce signalement'), findsNothing);
    },
  );

  // ── Test 17e: tap "Contester ce signalement" (sender) → dispatch ───────────

  testWidgets(
    'tap "Contester ce signalement" (expéditeur) → DeliveryNoShowContestRequested émis',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: true,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.text('Contester ce signalement'));
      await tester.pump();

      verify(
        () => cancellationBloc.add(
          any(that: isA<DeliveryNoShowContestRequested>()),
        ),
      ).called(1);
    },
  );

  // ── Test 18: tap "Je conteste" → sheet → annuler (no dispatch) ───────────────

  testWidgets(
    '18 · tap "Je conteste" → sheet s\'ouvre → appuyer barrière → aucun dispatch',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je conteste'));
      await tester.pumpAndSettle();

      // Sheet is open — close by tapping outside
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      // NoShowContestRequested must NOT have been dispatched
      verifyNever(
        () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
      );

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 19: tap "Je conteste" → confirmer → NoShowContestRequested ──────────

  testWidgets(
    '19 · tap "Je conteste" → "Confirmer la contestation" → NoShowContestRequested dispatched',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je conteste'));
      await tester.pumpAndSettle();

      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining('Confirmer la contestation'),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      verify(
        () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
      ).called(1);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 20: tap "Je confirme" → confirmer → NoShowConfirmRequested ──────────

  testWidgets(
    '20 · tap "Je confirme" → "Confirmer mon absence" → NoShowConfirmRequested dispatched',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je confirme'));
      await tester.pumpAndSettle();

      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining('Confirmer mon absence'),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      verify(
        () => cancellationBloc.add(any(that: isA<NoShowConfirmRequested>())),
      ).called(1);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );
}
