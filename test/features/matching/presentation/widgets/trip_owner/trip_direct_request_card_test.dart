// Carte « réponse directe » de « À traiter » sur l'écran du trajet vu par son
// voyageur, et sa réponse (TripBidAnswerScope) : 1, 2 et 8 demandes,
// Refuser et Accepter par les parcours habituels (carte, espèces avec
// commission, mobile money, solde insuffisant, carte refusée, refus du
// serveur), chargement, passage à la suivante, disparition après la
// dernière, mesure de la tuile `requests`, textes FR et EN à 360 dp × 1,3.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_answer_harness.dart';

/// Laisse passer les animations des feuilles sans attendre la fin d'un
/// indicateur de chargement (qui tourne tant que la réponse court).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AnswerHarness h;
  late int seeAll;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
    seeAll = 0;
  });

  tearDown(() => h.tearDown());

  /// La carte comme la posera le corps : sur les dernières données de
  /// l'écran (`TripTodoLive`), sous le scope de réponse.
  Future<List<AnswerPushedRoute>> pumpCard(
    WidgetTester tester, {
    String status = 'ACTIVE',
    List<BidModel>? bids,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 1000),
  }) => h.pump(
    tester,
    trip: answerTrip(status: status),
    bids: bids,
    locale: locale,
    textScale: textScale,
    size: size,
    body: (context) => TripTodoLive(
      trip: answerTrip(status: status),
      blocs: TripTodoBlocs.of(context),
      builder: (context, live) =>
          TripDirectRequestCard(bids: live.bids, onSeeAll: () => seeAll++),
    ),
  );

  Finder card() => find.byKey(const Key('trip-direct-request-card'));
  Finder accept(String id) => find.byKey(Key('trip-request-accept-$id'));
  Finder reject(String id) => find.byKey(Key('trip-request-reject-$id'));
  DonyButton button(WidgetTester tester, Finder f) =>
      tester.widget<DonyButton>(f);

  group('contenu', () {
    testWidgets('1 demande : « Demande 1 sur 1 », identité, sans lien', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bids: [
          answerBid('r1', senderName: 'Awa Diop', category: 'CLOTHES', net: 42),
          answerBid('a1', status: 'ACCEPTED'),
        ],
      );
      expect(card(), findsOneWidget);
      expect(find.text('Demande 1 sur 1'), findsOneWidget);
      expect(find.text('Awa Diop'), findsOneWidget);
      expect(find.textContaining('· 3 kg'), findsOneWidget);
      expect(find.text(formatPriceIn(42, 'EUR')), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
      expect(find.text('Accepter'), findsOneWidget);
      expect(
        find.byKey(const Key('trip-direct-request-see-all')),
        findsNothing,
      );
    });

    testWidgets('2 demandes : la première, « Voir les 2 demandes »', (
      tester,
    ) async {
      await pumpCard(tester, bids: answerRequests(2));
      expect(find.text('Demande 1 sur 2'), findsOneWidget);
      expect(find.text('Expéditeur r1'), findsOneWidget);
      expect(find.text('Expéditeur r2'), findsNothing);
      expect(find.text('Voir les 2 demandes'), findsOneWidget);
      await tester.tap(find.text('Voir les 2 demandes'));
      expect(seeAll, 1);
    });

    testWidgets('8 demandes : ordre reçu, « Voir les 8 demandes »', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bids: [
          answerBid('done', status: 'REJECTED'),
          ...answerRequests(8),
        ],
      );
      expect(find.text('Demande 1 sur 8'), findsOneWidget);
      expect(find.byKey(const Key('trip-direct-request-r1')), findsOneWidget);
      expect(find.text('Voir les 8 demandes'), findsOneWidget);
    });

    testWidgets('PAYMENT_ESCROWED compte comme une demande à traiter', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bids: [
          answerBid('e1', status: 'PAYMENT_ESCROWED'),
          ...answerRequests(1),
        ],
      );
      expect(find.text('Demande 1 sur 2'), findsOneWidget);
      expect(find.byKey(const Key('trip-direct-request-e1')), findsOneWidget);
    });

    testWidgets('aucune demande, ou liste pas chargée : rien', (tester) async {
      await pumpCard(tester, bids: [answerBid('a', status: 'ACCEPTED')]);
      expect(card(), findsNothing);
    });

    testWidgets('liste pas encore chargée : rien', (tester) async {
      await pumpCard(tester);
      expect(card(), findsNothing);
    });

    testWidgets('contenu vide, sans poids ni montant : « Colis » seul', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bids: [answerBid('r1', description: '  ', weightKg: null)],
      );
      expect(find.text('Colis'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(3),
        locale: const Locale('en'),
      );
      expect(find.text('Request 1 of 3'), findsOneWidget);
      expect(find.text('See all 3 requests'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
    });
  });

  group('Accepter', () {
    testWidgets('carte : BidAcceptRequested sur le bloc de réponse, '
        'chargement, puis demande suivante et relecture silencieuse', (
      tester,
    ) async {
      await pumpCard(tester, bids: answerRequests(2));
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();

      expect(h.answerEvents.single, isA<BidAcceptRequested>());
      expect((h.answerEvents.single as BidAcceptRequested).bidId, 'r1');
      // Jamais sur le bloc des colis de l'écran.
      expect(h.screenEvents, isEmpty);
      expect(button(tester, accept('r1')).isLoading, isTrue);
      expect(button(tester, reject('r1')).onPressed, isNull);

      h.answerStates.add(BidAccepted(answerRequests(1).first));
      await tester.pump();
      await tester.pump();

      // La carte passe aussitôt à la suivante, sans attendre la relecture.
      expect(find.text('Demande 1 sur 1'), findsOneWidget);
      expect(find.byKey(const Key('trip-direct-request-r2')), findsOneWidget);
      expect(button(tester, accept('r2')).onPressed, isNotNull);
      expect(find.text('Demande acceptée !'), findsOneWidget);
      final reload = h.screenEvents.single as BidListRequested;
      expect(reload.announcementId, 'trip-1');
      expect(reload.silent, isTrue);
      final tripReload = h.annEvents.single as AnnouncementDetailRequested;
      expect(tripReload.silent, isTrue);
      verify(() => h.consent.onParcelAccepted(any())).called(1);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('mobile money : BidAcceptMobileMoneyRequested', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.mobileMoney),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      expect(h.answerEvents.single, isA<BidAcceptMobileMoneyRequested>());
      expect(h.acceptanceEvents, isEmpty);
    });

    testWidgets('espèces : commission par BidAcceptanceBloc, la dernière '
        'demande disparaît', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      verify(() => h.repository.previewCommissionAllocation('r1')).called(1);
      final event = h.acceptanceEvents.single as ace.BidAcceptRequested;
      expect(event.bidId, 'r1');
      expect(event.fundingCurrency, isNull);
      expect(h.answerEvents, isEmpty);

      h.acceptanceStates
        ..add(acs.BidAccepting())
        ..add(acs.BidAccepted());
      await tester.pump();
      await tester.pump();
      expect(card(), findsNothing);
      expect(find.text('Demande acceptée !'), findsOneWidget);
      expect(h.screenEvents.single, isA<BidListRequested>());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('espèces réparties : explication avant d\'accepter, '
        'fermée sans confirmer, rien ne part', (tester) async {
      when(
        () => h.repository.previewCommissionAllocation(any()),
      ).thenAnswer((_) async => splitWalletPreview);
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await settle(tester);
      expect(find.text('Comment vos frais seront réglés'), findsOneWidget);
      // Fermée d'un geste : aucune acceptation.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(h.acceptanceEvents, isEmpty);
      expect(button(tester, accept('r1')).onPressed, isNotNull);
    });

    testWidgets('espèces réparties : confirmée, l\'acceptation part', (
      tester,
    ) async {
      when(
        () => h.repository.previewCommissionAllocation(any()),
      ).thenAnswer((_) async => splitWalletPreview);
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await settle(tester);
      await tester.tap(find.byType(DonyButton).last);
      await settle(tester);
      expect(h.acceptanceEvents.single, isA<ace.BidAcceptRequested>());
    });

    testWidgets('solde insuffisant : feuille de recharge, la demande reste ; '
        'payer par carte relance sur la commission par carte', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(2, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: true,
          bidId: 'r1',
          currency: 'EUR',
        ),
      );
      await settle(tester);
      expect(find.text('Solde insuffisant'), findsOneWidget);
      // La demande reste, boutons rallumés derrière la feuille.
      expect(find.text('Demande 1 sur 2', skipOffstage: false), findsOneWidget);
      expect(button(tester, accept('r1')).isLoading, isFalse);

      await tester.tap(find.text('Payer par carte'));
      await settle(tester);
      expect(
        h.acceptanceEvents.last,
        isA<ace.BidAcceptWithCardRequested>().having(
          (e) => e.bidId,
          'bidId',
          'r1',
        ),
      );
      expect(button(tester, accept('r1')).isLoading, isTrue);
      h.acceptanceStates.add(acs.BidAccepted());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('trip-direct-request-r2')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('solde insuffisant : recharge réussie, relance sur le '
        'portefeuille', (tester) async {
      final pushed = await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: false,
          bidId: 'r1',
          currency: 'EUR',
        ),
      );
      await settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('donyBottomSheetFooter')),
              matching: find.byType(DonyButton),
            )
            .first,
      );
      await settle(tester);
      expect(pushed.last.location, '/payments/wallet/topup/method');
      await tester.tap(find.text('back-true'));
      await settle(tester);
      expect(h.acceptanceEvents.last, isA<ace.BidAcceptRequested>());
      expect(h.acceptanceEvents, hasLength(2));
    });

    testWidgets('solde insuffisant sans carte : ajouter une carte, puis '
        'relecture au retour', (tester) async {
      final pushed = await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: false,
          bidId: 'r1',
          currency: 'EUR',
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Ajouter une carte'));
      await settle(tester);
      expect(pushed.last.location, '/payments/commission-method');
      expect(h.screenEvents, isEmpty);
      await tester.tap(find.text('back'));
      await settle(tester);
      expect(h.screenEvents.single, isA<BidListRequested>());
    });

    testWidgets('carte de commission refusée : feuille pour en changer', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.bankAuthInterrupted,
          cardDeclined: true,
        ),
      );
      await settle(tester);
      expect(
        find.text('Changer ma carte des frais de service'),
        findsOneWidget,
      );
      expect(card(), findsOneWidget);
    });

    testWidgets('refus définitif (trajet complet) : message, la demande '
        'reste, « Accepter » éteint avec le motif, liste relue', (
      tester,
    ) async {
      const refusal = ConflictException(
        'capacity',
        code: 'capacity-insufficient',
      );
      await pumpCard(
        tester,
        bids: answerRequests(2, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.refused,
          bidId: 'r1',
          definitive: true,
          error: refusal,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(card(), findsOneWidget);
      // Comme la liste des demandes (`DemandesScreen`) : le bloc rejouerait
      // le même refus, « Accepter » s'éteint et le motif reste affiché ;
      // « Refuser » reste possible.
      expect(button(tester, accept('r1')).onPressed, isNull);
      expect(button(tester, reject('r1')).onPressed, isNotNull);
      final message = ErrorCatalog.lookup(
        refusal,
        l10n: lookupAppLocalizations(const Locale('fr')),
      ).message;
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-request-refused-r1')),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(h.screenEvents.single, isA<BidListRequested>());
      // Un nouvel appui ne relance rien.
      await tester.tap(accept('r1'), warnIfMissed: false);
      await tester.pump();
      expect(h.acceptanceEvents, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
    });

    group('refus définitif mémorisé', () {
      Future<void> refuseR1(WidgetTester tester) async {
        await pumpCard(
          tester,
          bids: answerRequests(2, method: BidPaymentMethod.cash),
        );
        await tester.tap(accept('r1'));
        await tester.pump();
        await tester.pump();
        h.acceptanceStates.add(
          acs.BidFailed(
            reason: acs.BidFailureReason.refused,
            bidId: 'r1',
            definitive: true,
            error: const ConflictException('x', code: 'capacity-insufficient'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(button(tester, accept('r1')).onPressed, isNull);
      }

      testWidgets('relecture identique : le refus reste', (tester) async {
        await refuseR1(tester);
        h.screenStates.add(
          BidListLoaded(answerRequests(2, method: BidPaymentMethod.cash)),
        );
        h.annStates.add(AnnouncementDetailLoaded(answerTrip()));
        await tester.pump();
        await tester.pump();
        expect(button(tester, accept('r1')).onPressed, isNull);
        expect(
          h.acceptanceEvents.whereType<ace.BidAcceptanceRefusalsCleared>(),
          isEmpty,
        );
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('un colis annulé dans la relecture : refus oublié, ici et '
          'dans le bloc d\'acceptation', (tester) async {
        await refuseR1(tester);
        h.screenStates.add(
          BidListLoaded([
            ...answerRequests(2, method: BidPaymentMethod.cash),
            answerBid('a1', status: 'CANCELLED'),
          ]),
        );
        await tester.pump();
        await tester.pump();
        expect(button(tester, accept('r1')).onPressed, isNotNull);
        expect(find.byKey(const Key('trip-request-refused-r1')), findsNothing);
        expect(
          h.acceptanceEvents.whereType<ace.BidAcceptanceRefusalsCleared>(),
          hasLength(1),
        );
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('kilos libérés dans le trajet relu : refus oublié', (
        tester,
      ) async {
        await refuseR1(tester);
        h.annStates.add(AnnouncementDetailLoaded(answerTrip(availableKg: 25)));
        await tester.pump();
        await tester.pump();
        expect(button(tester, accept('r1')).onPressed, isNotNull);
        await tester.pump(const Duration(seconds: 5));
      });
    });

    testWidgets('refus définitif, liste relue sans la demande : la suivante '
        'garde « Accepter »', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(2, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.refused,
          bidId: 'r1',
          definitive: true,
          error: const ConflictException('x', code: 'bid-not-found'),
        ),
      );
      await tester.pump();
      await tester.pump();
      // La relecture retire la demande refusée (expirée côté serveur).
      h.screenStates.add(
        BidListLoaded(
          answerRequests(2, method: BidPaymentMethod.cash).sublist(1),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('trip-direct-request-r2')), findsOneWidget);
      expect(button(tester, accept('r2')).onPressed, isNotNull);
      expect(find.byKey(const Key('trip-request-refused-r2')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('refus non définitif (solde, réseau) : « Accepter » reste '
        'actif', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(1, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.refused,
          bidId: 'r1',
          error: const ConflictException('x', code: 'something-transient'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(button(tester, accept('r1')).onPressed, isNotNull);
      expect(find.byKey(const Key('trip-request-refused-r1')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    for (final (name, error) in [
      (
        '409 n\'est plus en attente',
        const ConflictException('x', code: 'bid-not-pending'),
      ),
      ('404 introuvable', const NotFoundException()),
      ('422 refusée en l\'état', const ValidationException('x')),
    ]) {
      testWidgets('demande changée ailleurs ($name) : message, colis et '
          'trajet relus en silence, la carte passe à la suivante', (
        tester,
      ) async {
        await pumpCard(tester, bids: answerRequests(2));
        await tester.tap(accept('r1'));
        await tester.pump();
        await tester.pump();
        h.answerStates.add(BidError(error));
        await tester.pump();
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(button(tester, accept('r1')).isLoading, isFalse);
        final reload = h.screenEvents.single as BidListRequested;
        expect(reload.silent, isTrue);
        expect(
          h.annEvents.whereType<AnnouncementDetailRequested>().single.silent,
          isTrue,
        );
        // La relecture ne montre plus r1 : la carte passe à r2.
        h.screenStates.add(BidListLoaded(answerRequests(2).sublist(1)));
        await tester.pump();
        expect(find.byKey(const Key('trip-direct-request-r2')), findsOneWidget);
        expect(find.text('Demande 1 sur 1'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    }

    testWidgets('erreur réseau : message, la demande reste, rien n\'est '
        'relu', (tester) async {
      await pumpCard(tester, bids: answerRequests(1));
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.answerStates.add(BidError(const NetworkException('offline')));
      await tester.pump();
      await tester.pump();
      expect(card(), findsOneWidget);
      expect(button(tester, accept('r1')).onPressed, isNotNull);
      expect(h.screenEvents, isEmpty);
      expect(h.annEvents, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('espèces, refus non définitif du serveur (409) : relecture ; '
        'sans erreur du serveur : rien relu', (tester) async {
      await pumpCard(
        tester,
        bids: answerRequests(2, method: BidPaymentMethod.cash),
      );
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(reason: acs.BidFailureReason.confirmFailed),
      );
      await tester.pump();
      await tester.pump();
      expect(h.screenEvents, isEmpty);

      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      h.acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.refused,
          bidId: 'r1',
          error: const ConflictException('x', code: 'bid-not-pending'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect((h.screenEvents.single as BidListRequested).silent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('double appui : une seule acceptation', (tester) async {
      await pumpCard(tester, bids: answerRequests(1));
      await tester.tap(accept('r1'));
      await tester.tap(accept('r1'), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      await tester.tap(accept('r1'), warnIfMissed: false);
      await tester.pump();
      expect(h.answerEvents, hasLength(1));
    });
  });

  group('Refuser', () {
    testWidgets('feuille du motif, BidRejectRequested avec le code, puis '
        'demande suivante', (tester) async {
      await pumpCard(tester, bids: answerRequests(2));
      await tester.tap(reject('r1'));
      await settle(tester);
      expect(find.byKey(const Key('reject-reason-confirm')), findsOneWidget);
      await tester.tap(find.text('Plus assez de place'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('reject-reason-confirm')));
      await settle(tester);

      final event = h.answerEvents.single as BidRejectRequested;
      expect(event.bidId, 'r1');
      expect(event.reason, 'NO_CAPACITY');
      expect(button(tester, reject('r1')).isLoading, isTrue);
      expect(button(tester, accept('r1')).onPressed, isNull);

      h.answerStates.add(BidRejected(answerRequests(1).first));
      await tester.pump();
      await tester.pump();
      expect(find.text('Demande 1 sur 1'), findsOneWidget);
      expect(find.text('Demande refusée.'), findsOneWidget);
      expect(h.screenEvents.single, isA<BidListRequested>());
      verifyNever(() => h.consent.onParcelAccepted(any()));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('feuille du motif fermée : rien ne part', (tester) async {
      await pumpCard(tester, bids: answerRequests(1));
      await tester.tap(reject('r1'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(h.answerEvents, isEmpty);
      expect(button(tester, reject('r1')).onPressed, isNotNull);
    });

    testWidgets('échec du refus : message, la demande reste', (tester) async {
      await pumpCard(tester, bids: answerRequests(1));
      await tester.tap(reject('r1'));
      await settle(tester);
      await tester.tap(find.text('Plus assez de place'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('reject-reason-confirm')));
      await settle(tester);
      h.answerStates.add(BidError(const NetworkException('offline')));
      await tester.pump();
      await tester.pump();
      expect(card(), findsOneWidget);
      expect(button(tester, reject('r1')).isLoading, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  // Lignes reprises par le sheet des demandes : même identité
  // (`TripRequestIdentity`, `tripRequestDetails`), cas hors nominal.
  group('identité d\'une demande hors cas nominal', () {
    BidModel bid(
      String id, {
      String? senderName,
      String? category,
      String? description,
      double? weightKg,
      double? net,
      double? pricePerKg,
      String currency = 'EUR',
    }) => BidModel(
      id: id,
      announcementId: 'trip-1',
      senderId: 'sender-$id',
      senderName: senderName,
      status: 'PENDING',
      contentCategory: category,
      description: description,
      weightKg: weightKg,
      totalAmountEur: net,
      pricePerKg: pricePerKg,
      currency: currency,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

    Future<void> pumpIdentity(
      WidgetTester tester,
      List<BidModel> bids, {
      Locale locale = const Locale('fr'),
    }) => h.pump(
      tester,
      trip: answerTrip(),
      bids: bids,
      locale: locale,
      body: (_) => Column(
        children: [
          for (final b in bids)
            TripRequestIdentity(key: Key('identity-${b.id}'), bid: b),
        ],
      ),
    );

    /// Textes de l'identité, sans les initiales de l'avatar.
    String text(WidgetTester tester, String id) {
      final identity = find.byKey(Key('identity-$id'));
      final initials = tester
          .widgetList<Text>(
            find.descendant(
              of: find.descendant(
                of: identity,
                matching: find.byType(DonyAvatar),
              ),
              matching: find.byType(Text),
            ),
          )
          .toSet();
      return tester
          .widgetList<Text>(
            find.descendant(of: identity, matching: find.byType(Text)),
          )
          .where((t) => !initials.contains(t))
          .map((t) => t.data)
          .join(' | ');
    }

    testWidgets('catégories traduites, prioritaires sur la description', (
      tester,
    ) async {
      await pumpIdentity(tester, locale: const Locale('en'), [
        bid(
          'c1',
          senderName: 'Awa',
          category: 'Documents & administratif,Vêtements & tissus',
          description: 'Mes papiers',
        ),
      ]);
      expect(
        text(tester, 'c1'),
        'Awa | Documents & paperwork, Clothing & fabrics',
      );
      expect(find.text('Mes papiers'), findsNothing);
    });

    testWidgets('ni catégorie ni description (ou vides) : « Colis »', (
      tester,
    ) async {
      await pumpIdentity(tester, [
        bid('d1', senderName: 'Awa'),
        bid('d2', senderName: 'Awa', category: '', description: '  '),
      ]);
      expect(text(tester, 'd1'), 'Awa | Colis');
      expect(text(tester, 'd2'), 'Awa | Colis');
    });

    testWidgets('expéditeur nommé ou anonyme, poids absent ou décimal', (
      tester,
    ) async {
      await pumpIdentity(tester, [
        bid('s1', senderName: 'Awa', description: 'Livres', weightKg: 2.5),
        bid('s2', description: 'Livres'),
      ]);
      expect(text(tester, 's1'), 'Awa | Livres · 2.5 kg');
      // Sans nom : le libellé générique ; sans poids : pas de « · ».
      expect(text(tester, 's2'), 'Expéditeur | Livres');
    });

    testWidgets('net : servi, sinon prix au kilo × poids, sinon rien', (
      tester,
    ) async {
      await pumpIdentity(tester, [
        bid('n1', senderName: 'A', net: 42, pricePerKg: 99, weightKg: 1),
        bid('n2', senderName: 'A', pricePerKg: 8, weightKg: 3),
        bid('n3', senderName: 'A', weightKg: 3),
      ]);
      expect(text(tester, 'n1'), endsWith(formatPriceIn(42, 'EUR')));
      // Même repli que la liste des demandes (`travelerNetAmount`).
      expect(text(tester, 'n2'), endsWith(formatPriceIn(24, 'EUR')));
      expect(text(tester, 'n3'), endsWith('3 kg'));
    });

    testWidgets('devise du colis (XOF)', (tester) async {
      await pumpIdentity(tester, [
        bid('x1', senderName: 'A', net: 25000, weightKg: 5, currency: 'XOF'),
      ]);
      expect(text(tester, 'x1'), endsWith(formatPriceIn(25000, 'XOF')));
      expect(text(tester, 'x1'), contains('CFA'));
    });
  });

  group('360 dp × 1,3, vraies polices', () {
    for (final (locale, labels) in [
      (const Locale('fr'), ['Refuser', 'Accepter', 'Voir les 8 demandes']),
      (const Locale('en'), ['Decline', 'Accept', 'See all 8 requests']),
    ]) {
      testWidgets('${locale.languageCode} : libellés sur une ligne, à taille '
          'nominale, boutons de 52 dp', (tester) async {
        await pumpCard(
          tester,
          bids: [
            answerBid(
              'r1',
              senderName: 'Marie-Christine Ouédraogo-Diabaté',
              description: 'Vêtements, chaussures et produits de beauté',
              weightKg: 22.5,
              net: 1234.5,
            ),
            ...answerRequests(8).skip(1),
          ],
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 1000),
        );
        expect(tester.takeException(), isNull);
        for (final label in labels.take(2)) {
          final text = find.text(label);
          final fitted = find.ancestor(
            of: text,
            matching: find.byType(FittedBox),
          );
          final scale =
              tester.getSize(fitted.first).width / tester.getSize(text).width;
          expect(scale, closeTo(1, 0.01), reason: label);
          final btn = find.ancestor(
            of: text,
            matching: find.byType(DonyButton),
          );
          expect(tester.getSize(btn).height, inInclusiveRange(46, 52));
        }
        // Lien sur une ligne.
        expect(tester.getSize(find.text(labels[2])).height, lessThan(30));
        // Les deux boutons partagent la ligne à parts égales.
        expect(
          tester.getSize(reject('r1')).width,
          closeTo(tester.getSize(accept('r1')).width, 1),
        );
      });
    }
  });

  test('tripRequestsToAnswer : à traiter, ordre reçu, sans les traitées', () {
    final bids = [
      answerBid('a', status: 'ACCEPTED'),
      answerBid('p1'),
      answerBid('e1', status: 'PAYMENT_ESCROWED'),
      answerBid('p2'),
      answerBid('x', status: 'CANCELLED'),
    ];
    expect(tripRequestsToAnswer(bids)!.map((b) => b.id), ['p1', 'e1', 'p2']);
    expect(tripRequestsToAnswer(bids, {'e1'})!.map((b) => b.id), ['p1', 'p2']);
    expect(tripRequestsToAnswer(null), isNull);
  });
}
