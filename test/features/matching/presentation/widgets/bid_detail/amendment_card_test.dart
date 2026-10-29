import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidAmendment _am({
  String id = 'am-1',
  BidAmendmentStatus status = BidAmendmentStatus.proposed,
  String rail = BidAmendment.railCash,
  Duration? expiresIn = const Duration(hours: 46, minutes: 30),
  double? net = 23.5,
  double? commission = 3.3,
  String? closedReason,
}) => BidAmendment(
  id: id,
  status: status,
  rail: rail,
  addedWeightKg: 3,
  items: [
    BidAmendmentItem(
      label: 'Téléphone',
      quantity: 1,
      grossAmount: 11.4,
      netAmount: net == null ? null : 10,
    ),
  ],
  grossAmount: 26.8,
  netAmount: net,
  commissionAmount: commission,
  expiresAt: expiresIn == null ? null : DateTime.now().toUtc().add(expiresIn),
  closedReason: closedReason,
  blocksHandover: status.isOpen,
);

BidModel _bid(
  BidAmendment? a, {
  String status = 'ACCEPTED',
  List<BidAmendment>? all,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  travelerName: 'Moussa',
  senderName: 'Aïcha',
  weightKg: 12,
  totalWeightKg: 17,
  status: status,
  amendments: all ?? (a == null ? const [] : [a]),
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockRepository repository;
  late _MockBidBloc bidBloc;
  late int authorizations;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    repository = _MockRepository();
    bidBloc = _MockBidBloc();
    authorizations = 0;
    final analytics = _MockAnalytics();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerFactory<AmendmentActionCubit>(
        () => AmendmentActionCubit(repository, analytics),
      )
      ..registerFactory<AmendmentAcceptCubit>(
        () => AmendmentAcceptCubit(
          repository,
          analytics,
          AmendmentCommissionFlow(
            repository,
            analytics,
            nextAction: (_) async {},
          ),
        ),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AmendmentTravelerCard traveler(BidModel bid) => AmendmentTravelerCard(
    bid: bid,
    authorize: (_) async {
      authorizations++;
      return true;
    },
  );

  group('shouldShow', () {
    test('sender_openOrClosedUnaccepted_shown_securedHidden', () {
      for (final s in [
        BidAmendmentStatus.authorizationPending,
        BidAmendmentStatus.proposed,
        BidAmendmentStatus.paymentPending,
        BidAmendmentStatus.declined,
        BidAmendmentStatus.expired,
        BidAmendmentStatus.cancelled,
      ]) {
        expect(AmendmentSenderCard.shouldShow(_bid(_am(status: s))), isTrue);
      }
      for (final s in [
        BidAmendmentStatus.accepted,
        BidAmendmentStatus.paidOut,
        BidAmendmentStatus.unknown,
      ]) {
        expect(AmendmentSenderCard.shouldShow(_bid(_am(status: s))), isFalse);
      }
      expect(AmendmentSenderCard.shouldShow(_bid(null)), isFalse);
    });

    test('sender_needsReply_onlyWhileTheRequestIsOpen', () {
      for (final s in [
        BidAmendmentStatus.authorizationPending,
        BidAmendmentStatus.proposed,
        BidAmendmentStatus.commissionPending,
        BidAmendmentStatus.paymentPending,
      ]) {
        expect(AmendmentSenderCard.needsReply(_bid(_am(status: s))), isTrue);
      }
      for (final s in [
        BidAmendmentStatus.declined,
        BidAmendmentStatus.expired,
        BidAmendmentStatus.cancelled,
        BidAmendmentStatus.accepted,
      ]) {
        expect(AmendmentSenderCard.needsReply(_bid(_am(status: s))), isFalse);
      }
      expect(AmendmentSenderCard.needsReply(_bid(null)), isFalse);
    });

    test('traveler_accepted_shownOnlyWhileAcceptedBid', () {
      final accepted = _am(status: BidAmendmentStatus.accepted);
      expect(AmendmentTravelerCard.shouldShow(_bid(accepted)), isTrue);
      expect(
        AmendmentTravelerCard.shouldShow(_bid(accepted, status: 'IN_TRANSIT')),
        isFalse,
      );
      expect(AmendmentTravelerCard.shouldShow(_bid(_am())), isTrue);
      expect(AmendmentTravelerCard.shouldShow(_bid(null)), isFalse);
    });
  });

  group('expéditeur', () {
    testWidgets('senderPending_showsDeadlineAndCancel', (tester) async {
      await pump(tester, AmendmentSenderCard(bid: _bid(_am())));

      expect(find.text('MODIFICATION DU COLIS'), findsOneWidget);
      expect(find.text('En attente de Moussa'), findsOneWidget);
      expect(find.textContaining('(47 h)'), findsOneWidget);
      expect(find.textContaining('26,80'), findsWidgets);
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Annuler ma demande'), findsOneWidget);
    });

    testWidgets('senderCancel_confirmDialog_callsCancel_reloadsBid', (
      tester,
    ) async {
      when(
        () => repository.cancel('bid-1', 'am-1'),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.cancelled));
      await pump(tester, AmendmentSenderCard(bid: _bid(_am())));

      await tester.tap(find.text('Annuler ma demande'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.cancel(any(), any()));
      expect(find.text('Annuler votre demande ?'), findsOneWidget);

      await tester.tap(find.text('Annuler ma demande').last);
      await tester.pumpAndSettle();

      verify(() => repository.cancel('bid-1', 'am-1')).called(1);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('senderNeverShowsNet', (tester) async {
      // Même si un back fautif laissait passer le net et la commission.
      await pump(tester, AmendmentSenderCard(bid: _bid(_am())));

      expect(find.text('MODIFICATION DU COLIS'), findsOneWidget);
      expect(find.textContaining('23,50'), findsNothing);
      expect(find.textContaining('3,30'), findsNothing);
      expect(find.textContaining('10,00'), findsNothing);
      expect(find.text('Pour vous en plus'), findsNothing);
    });

    testWidgets('senderRefused_showsStatusAndBody_noCancel', (tester) async {
      await pump(
        tester,
        AmendmentSenderCard(
          bid: _bid(
            _am(
              status: BidAmendmentStatus.declined,
              net: null,
              commission: null,
            ),
          ),
        ),
      );

      expect(
        find.text("Moussa n'a pas accepté la modification"),
        findsOneWidget,
      );
      expect(find.textContaining('Votre colis reste à 17 kg'), findsOneWidget);
      expect(find.text('Annuler ma demande'), findsNothing);
    });

    testWidgets('senderExpired_andCancelled_showOwnStatus', (tester) async {
      await pump(
        tester,
        AmendmentSenderCard(bid: _bid(_am(status: BidAmendmentStatus.expired))),
      );
      expect(find.text("Moussa n'a pas répondu à temps"), findsOneWidget);

      await pump(
        tester,
        AmendmentSenderCard(
          bid: _bid(_am(status: BidAmendmentStatus.cancelled)),
        ),
      );
      expect(find.text('Demande annulée'), findsOneWidget);
    });

    testWidgets('senderCaptureFailed_showsPaymentFailed', (tester) async {
      await pump(
        tester,
        AmendmentSenderCard(
          bid: _bid(
            _am(
              status: BidAmendmentStatus.cancelled,
              rail: BidAmendment.railStripe,
              closedReason: 'CAPTURE_FAILED',
            ),
          ),
        ),
      );

      expect(
        find.text('Le paiement de la modification a échoué'),
        findsOneWidget,
      );
    });

    testWidgets('senderMobileMoneyAccepted_saysPayNow', (tester) async {
      await pump(
        tester,
        AmendmentSenderCard(
          bid: _bid(
            _am(
              status: BidAmendmentStatus.paymentPending,
              rail: BidAmendment.railPawapay,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Payez maintenant pour que la modification soit prise en compte.',
        ),
        findsOneWidget,
      );
    });
  });

  group('voyageur', () {
    testWidgets('travelerProposed_showsNetAndButtons', (tester) async {
      await pump(tester, traveler(_bid(_am())));

      expect(find.text('Aïcha veut agrandir son colis'), findsOneWidget);
      expect(find.textContaining('(+23,50'), findsOneWidget);
      expect(find.text('Pour vous en plus'), findsOneWidget);
      expect(find.textContaining('17 → 20 kg'), findsOneWidget);
      expect(find.textContaining('3,30'), findsOneWidget);
      expect(find.textContaining('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('travelerAccept_cash_authorizesThenAccepts_reloadsBid', (
      tester,
    ) async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.accepted));
      await pump(tester, traveler(_bid(_am())));

      await tester.tap(find.textContaining('Accepter'));
      await tester.pumpAndSettle();

      expect(authorizations, 1);
      verify(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ).called(1);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('travelerAccept_card_noAuthNoCommissionNote', (tester) async {
      when(
        () => repository.accept('bid-1', 'am-1'),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.accepted));
      await pump(tester, traveler(_bid(_am(rail: BidAmendment.railStripe))));

      expect(find.textContaining('prélevée sur votre solde'), findsNothing);
      expect(find.textContaining('Payé par carte par Aïcha'), findsOneWidget);
      await tester.tap(find.textContaining('Accepter'));
      await tester.pumpAndSettle();

      expect(authorizations, 0);
      verify(() => repository.accept('bid-1', 'am-1')).called(1);
    });

    testWidgets('travelerAccept_unfunded_showsSourceChoiceAndBanner', (
      tester,
    ) async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ).thenThrow(
        const ValidationException(
          'solde',
          code: 'amendment-commission-unfunded',
          extensions: {
            'availableBalance': 1.0,
            'requiredCommission': 3.3,
            'shortfall': 2.3,
            'hasCard': true,
            'currency': 'EUR',
          },
        ),
      );
      await pump(tester, traveler(_bid(_am())));

      await tester.tap(find.textContaining('Accepter'));
      await tester.pumpAndSettle();

      expect(find.text('Mon solde Yadony'), findsOneWidget);
      expect(find.text('Ma carte des frais de service'), findsOneWidget);
      expect(
        find.textContaining('Choisissez votre carte ou un autre solde'),
        findsOneWidget,
      );
    });

    testWidgets('travelerDecline_confirmThenCalls', (tester) async {
      when(
        () => repository.decline('bid-1', 'am-1'),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.declined));
      await pump(tester, traveler(_bid(_am())));

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.decline(any(), any()));
      await tester.tap(find.text('Refuser').last);
      await tester.pumpAndSettle();

      verify(() => repository.decline('bid-1', 'am-1')).called(1);
    });

    testWidgets('travelerAccepted_beforeHandover_showsNotBrought', (
      tester,
    ) async {
      when(
        () => repository.notBrought('bid-1', 'am-1'),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.cancelled));
      await pump(
        tester,
        traveler(_bid(_am(status: BidAmendmentStatus.accepted))),
      );

      expect(find.text('Modification acceptée'), findsOneWidget);
      expect(find.text('Accepter'), findsNothing);
      await tester.tap(find.text('Les kilos en plus ne sont pas là'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.notBrought(any(), any()));

      await tester.tap(find.text('Les kilos en plus ne sont pas là').last);
      await tester.pumpAndSettle();

      verify(() => repository.notBrought('bid-1', 'am-1')).called(1);
    });

    testWidgets('travelerAccepted_afterHandover_noNotBroughtButton', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _bid(_am(status: BidAmendmentStatus.accepted), status: 'IN_TRANSIT'),
        ),
      );
      // Carte masquée : rien d'actionnable après la remise.
      expect(find.text('Les kilos en plus ne sont pas là'), findsNothing);
    });

    testWidgets('travelerWaitingMobileMoneyPayment_showsStatus', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _bid(
            _am(
              status: BidAmendmentStatus.paymentPending,
              rail: BidAmendment.railPawapay,
            ),
          ),
        ),
      );

      expect(find.text("En attente du paiement d'Aïcha"), findsNothing);
      expect(find.textContaining('En attente du paiement de'), findsOneWidget);
      expect(find.textContaining('Accepter'), findsNothing);
    });
  });

  group('plusieurs modifications', () {
    final declined = _am(status: BidAmendmentStatus.declined);
    final accepted = _am(id: 'am-2', status: BidAmendmentStatus.accepted);

    testWidgets('traveler_declinedThenAccepted_showsNotBrought', (
      tester,
    ) async {
      when(() => repository.notBrought('bid-1', 'am-2')).thenAnswer(
        (_) async => _am(id: 'am-2', status: BidAmendmentStatus.cancelled),
      );
      await pump(tester, traveler(_bid(null, all: [declined, accepted])));

      expect(find.text('Les kilos en plus ne sont pas là'), findsOneWidget);
      expect(find.text('Vous avez refusé la modification'), findsNothing);
      await tester.tap(find.text('Les kilos en plus ne sont pas là'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Les kilos en plus ne sont pas là').last);
      await tester.pumpAndSettle();
      verify(() => repository.notBrought('bid-1', 'am-2')).called(1);
    });

    testWidgets('traveler_acceptedThenDeclined_showsNotBrought', (
      tester,
    ) async {
      final first = _am(status: BidAmendmentStatus.accepted);
      final second = _am(id: 'am-2', status: BidAmendmentStatus.declined);
      await pump(tester, traveler(_bid(null, all: [first, second])));

      expect(find.text('Les kilos en plus ne sont pas là'), findsOneWidget);
      expect(find.text('Vous avez refusé la modification'), findsNothing);
    });

    testWidgets('traveler_twoAccepted_oneButtonEach', (tester) async {
      final first = _am(status: BidAmendmentStatus.accepted);
      await pump(tester, traveler(_bid(null, all: [first, accepted])));

      expect(find.text('Les kilos en plus ne sont pas là'), findsNWidgets(2));
    });

    testWidgets('traveler_openAndAccepted_showsBoth', (tester) async {
      final first = _am(status: BidAmendmentStatus.accepted);
      final open = _am(id: 'am-2');
      await pump(tester, traveler(_bid(null, all: [first, open])));

      expect(find.textContaining('Accepter'), findsOneWidget);
      expect(find.text('Les kilos en plus ne sont pas là'), findsOneWidget);
    });

    test('sender_acceptedHidesEarlierOrLaterClosed_whileAccepted', () {
      expect(
        AmendmentSenderCard.shouldShow(_bid(null, all: [declined, accepted])),
        isFalse,
      );
      expect(
        AmendmentSenderCard.shouldShow(
          _bid(
            null,
            all: [
              _am(status: BidAmendmentStatus.accepted),
              _am(id: 'am-2', status: BidAmendmentStatus.declined),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('sender_openWinsOverAccepted_closedShownWhenNothingSecured', () {
      expect(
        AmendmentSenderCard.shouldShow(
          _bid(
            null,
            all: [
              _am(status: BidAmendmentStatus.accepted),
              _am(id: 'am-2'),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        AmendmentSenderCard.shouldShow(
          _bid(
            null,
            all: [
              declined,
              _am(id: 'am-2', status: BidAmendmentStatus.expired),
            ],
          ),
        ),
        isTrue,
      );
    });

    testWidgets('sender_latestClosedWins_whenNoneSecured', (tester) async {
      await pump(
        tester,
        AmendmentSenderCard(
          bid: _bid(
            null,
            all: [
              declined,
              _am(id: 'am-2', status: BidAmendmentStatus.expired),
            ],
          ),
        ),
      );

      expect(find.text("Moussa n'a pas répondu à temps"), findsOneWidget);
    });
  });

  group('reprise de la commission', () {
    final pending = _am(status: BidAmendmentStatus.commissionPending);

    testWidgets('travelerCommissionPending_finalizeConfirmsCommission', (
      tester,
    ) async {
      when(
        () => repository.confirmCommission('bid-1', 'am-1'),
      ).thenAnswer((_) async => _am(status: BidAmendmentStatus.accepted));
      await pump(tester, traveler(_bid(pending)));

      expect(find.text('Commission en cours de validation'), findsOneWidget);
      expect(find.textContaining('pas encore finalisée'), findsOneWidget);
      await tester.tap(find.text('Finaliser la commission'));
      await tester.pumpAndSettle();

      expect(authorizations, 1);
      verify(() => repository.confirmCommission('bid-1', 'am-1')).called(1);
      verifyNever(() => repository.accept(any(), any()));
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });
  });

  group('textes de fin côté expéditeur', () {
    Future<void> pumpSender(WidgetTester tester, BidAmendment a) =>
        pump(tester, AmendmentSenderCard(bid: _bid(a)));

    testWidgets('notBrought_refunded_card_saysReportedAndRefund', (
      tester,
    ) async {
      await pumpSender(
        tester,
        _am(
          status: BidAmendmentStatus.refunded,
          rail: BidAmendment.railStripe,
          closedReason: 'NOT_BROUGHT',
        ),
      );

      expect(
        find.text("Moussa a signalé que les kilos en plus n'étaient pas là"),
        findsOneWidget,
      );
      expect(find.textContaining('vous est remboursée'), findsOneWidget);
      expect(find.textContaining("n'a pas apporté"), findsNothing);
    });

    testWidgets('refundPending_showsRefundInProgress', (tester) async {
      await pumpSender(
        tester,
        _am(
          status: BidAmendmentStatus.refundPending,
          rail: BidAmendment.railStripe,
        ),
      );

      expect(
        find.text('Remboursement de la modification en cours'),
        findsOneWidget,
      );
      expect(find.textContaining('vous est remboursée'), findsOneWidget);
    });

    testWidgets('refunded_otherReason_saysRefunded', (tester) async {
      await pumpSender(
        tester,
        _am(
          status: BidAmendmentStatus.refunded,
          rail: BidAmendment.railStripe,
          closedReason: 'BID_ENDED',
        ),
      );

      expect(find.text('Modification remboursée'), findsOneWidget);
    });

    testWidgets('cancelledByMe_card_saysAmountReleased', (tester) async {
      await pumpSender(
        tester,
        _am(
          status: BidAmendmentStatus.cancelled,
          rail: BidAmendment.railStripe,
          closedReason: 'CANCELLED_BY_SENDER',
        ),
      );

      expect(find.text('Demande annulée'), findsOneWidget);
      expect(find.textContaining('est libéré'), findsOneWidget);
    });

    testWidgets('expired_cash_saysNothingAsked_noRelease', (tester) async {
      await pumpSender(tester, _am(status: BidAmendmentStatus.expired));

      expect(find.textContaining('Rien ne vous est demandé'), findsOneWidget);
      expect(find.textContaining('est libéré'), findsNothing);
    });

    testWidgets('declined_card_saysAmountReleased', (tester) async {
      await pumpSender(
        tester,
        _am(status: BidAmendmentStatus.declined, rail: BidAmendment.railStripe),
      );

      expect(find.textContaining('est libéré'), findsOneWidget);
    });

    testWidgets('captureFailed_card_saysAmountReleased', (tester) async {
      await pumpSender(
        tester,
        _am(
          status: BidAmendmentStatus.cancelled,
          rail: BidAmendment.railStripe,
          closedReason: 'CAPTURE_FAILED',
        ),
      );

      expect(find.textContaining('est libéré'), findsOneWidget);
    });
  });

  group('détails', () {
    testWidgets('travelerCash_noCommissionAmount_hidesCommissionSentence', (
      tester,
    ) async {
      await pump(tester, traveler(_bid(_am(commission: null))));

      expect(find.textContaining('commission Yadony'), findsNothing);
      expect(find.textContaining('0,00'), findsNothing);
      expect(find.textContaining('Payé en espèces par Aïcha'), findsOneWidget);
    });

    testWidgets('travelerAccept_stillProcessing_noAcceptedSnackbar', (
      tester,
    ) async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ).thenAnswer(
        (_) async => _am(status: BidAmendmentStatus.commissionPending),
      );
      await pump(tester, traveler(_bid(_am())));

      await tester.tap(find.textContaining('Accepter'));
      await tester.pumpAndSettle();

      expect(find.text('Modification acceptée'), findsNothing);
      expect(find.textContaining('en cours de traitement'), findsOneWidget);
    });

    testWidgets('deadline_usesDateAtTimeFormat', (tester) async {
      await pump(tester, AmendmentSenderCard(bid: _bid(_am())));

      expect(
        find.textContaining(RegExp(r'avant le .+ à \d{2}:\d{2}')),
        findsOneWidget,
      );
    });
  });
}
