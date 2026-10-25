import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_pay_button.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidAmendment _amendment({
  String id = 'am-1',
  BidAmendmentStatus status = BidAmendmentStatus.paymentPending,
  String? rail = BidAmendment.railPawapay,
}) => BidAmendment(
  id: id,
  status: status,
  rail: rail,
  grossAmount: 26.8,
  blocksHandover: status == BidAmendmentStatus.paymentPending,
);

BidModel _bid(List<BidAmendment> amendments) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  amendments: amendments,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
  });

  Future<void> pump(
    WidgetTester tester,
    BidModel bid, {
    AmendmentMobileMoneyOpener? opener,
    bool withBidBloc = true,
  }) async {
    final button = AmendmentPayButton(
      bid: bid,
      openMobileMoney: opener ?? (_, _) async => true,
      analytics: analytics,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: withBidBloc
              ? BlocProvider<BidBloc>.value(value: bidBloc, child: button)
              : button,
        ),
      ),
    );
    await tester.pump();
  }

  group('canPay', () {
    test('payableBy : mobile money en attente de dépôt seulement', () {
      expect(AmendmentPayButton.canPay(_bid([_amendment()])), isTrue);
      expect(AmendmentPayButton.payable(_bid([_amendment()]))?.id, 'am-1');
    });

    test('ni carte, ni espèces, même en attente', () {
      expect(
        AmendmentPayButton.canPay(
          _bid([_amendment(rail: BidAmendment.railStripe)]),
        ),
        isFalse,
      );
      expect(
        AmendmentPayButton.canPay(
          _bid([_amendment(rail: BidAmendment.railCash)]),
        ),
        isFalse,
      );
    });

    test('ni proposée, ni acceptée, ni close, ni rail inconnu', () {
      for (final s in [
        BidAmendmentStatus.proposed,
        BidAmendmentStatus.accepted,
        BidAmendmentStatus.cancelled,
        BidAmendmentStatus.expired,
      ]) {
        expect(
          AmendmentPayButton.canPay(_bid([_amendment(status: s)])),
          isFalse,
        );
      }
      expect(
        AmendmentPayButton.canPay(_bid([_amendment(rail: null)])),
        isFalse,
      );
    });

    test('colis sans modification (ancien contrat) : rien à payer', () {
      expect(AmendmentPayButton.canPay(_bid(const [])), isFalse);
    });

    test('choisit la modification à payer parmi plusieurs', () {
      final bid = _bid([
        _amendment(id: 'old', status: BidAmendmentStatus.accepted),
        _amendment(id: 'to-pay'),
      ]);
      expect(AmendmentPayButton.payable(bid)?.id, 'to-pay');
    });
  });

  testWidgets('affiche « Payer {brut} », jamais le net', (tester) async {
    await pump(tester, _bid([_amendment()]));

    expect(find.byKey(const Key('amendment-pay-btn')), findsOneWidget);
    final label = tester
        .widget<DonyButton>(find.byKey(const Key('amendment-pay-btn')))
        .label
        .replaceAll(RegExp('[\\u00A0\\u202F]'), ' ');
    expect(label, 'Payer 26,80 €');
  });

  testWidgets('tap : ouvre l\'écran d\'attente de la modification et trace '
      'le début du paiement', (tester) async {
    String? opened;
    await pump(
      tester,
      _bid([_amendment()]),
      opener: (_, route) async {
        opened = route;
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('amendment-pay-btn')));
    await tester.pump();

    expect(opened, '/bids/bid-1/amendments/am-1/mobile-money/awaiting');
    verify(
      () => backend.capture(AnalyticsEvents.bidAmendmentPaymentStarted, {
        'method': 'mobile_money',
      }),
    ).called(1);
  });

  for (final result in <bool?>[true, false, null]) {
    testWidgets('retour de l\'écran d\'attente ($result) : le colis est relu', (
      tester,
    ) async {
      await pump(tester, _bid([_amendment()]), opener: (_, _) async => result);

      await tester.tap(find.byKey(const Key('amendment-pay-btn')));
      await tester.pump();

      final reload = verify(() => bidBloc.add(captureAny())).captured.single;
      expect(reload, isA<BidDetailRequested>());
      expect((reload as BidDetailRequested).bidId, 'bid-1');
    });
  }

  testWidgets('hors de l\'écran de détail (pas de BidBloc) : ne plante pas', (
    tester,
  ) async {
    await pump(tester, _bid([_amendment()]), withBidBloc: false);

    await tester.tap(find.byKey(const Key('amendment-pay-btn')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
