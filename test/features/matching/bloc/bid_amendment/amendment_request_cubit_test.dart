import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _options = AmendmentOptions(
  currency: 'EUR',
  availableKg: 6,
  pricePerKgDisplay: 5.13,
  gridItems: [
    AmendmentGridItemOption(
      id: 'g1',
      label: 'Téléphone',
      unitPriceDisplay: 11.4,
    ),
  ],
  paymentMethods: [BidPaymentMethod.cash, BidPaymentMethod.stripe],
  minAmount: 1,
  maxAmount: 300,
);

const _amendment = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'CASH',
  grossAmount: 22.4,
);

const _cashCheckout = AmendmentCheckout(amendment: _amendment);

const _cardCheckout = AmendmentCheckout(
  amendment: BidAmendment(
    id: 'am-1',
    status: BidAmendmentStatus.authorizationPending,
    rail: 'STRIPE',
    grossAmount: 22.4,
  ),
  clientSecret: 'pi_1_secret_2',
  paymentMethodTypes: ['card'],
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(BidPaymentMethod.cash);
  });

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options('bid-1')).thenAnswer((_) async => _options);
    when(
      () => repository.quote(
        'bid-1',
        addedKg: any(named: 'addedKg'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async => 22.4);
  });

  AmendmentRequestCubit build() => AmendmentRequestCubit(
    repository,
    analytics,
    quoteDebounce: const Duration(milliseconds: 10),
  );

  const settle = Duration(milliseconds: 60);

  /// Charge, ajoute 3 kg et attend le devis : trois émissions.
  Future<void> prepare(AmendmentRequestCubit c) async {
    await c.load(_bid);
    c.setKg(3);
    await Future<void>.delayed(settle);
  }

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'load_emitsEditingWithOptions',
    build: build,
    act: (c) => c.load(_bid),
    expect: () => [
      isA<AmendmentRequestState>()
          .having((s) => s.status, 'status', AmendmentRequestStatus.editing)
          .having((s) => s.options, 'options', _options)
          .having((s) => s.method, 'method', BidPaymentMethod.cash),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentSheetOpened,
        properties: {'rails_count': 2},
      ),
    ).called(1),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'load_failure_emitsLoadFailed',
    build: () {
      when(
        () => repository.options('bid-1'),
      ).thenThrow(const NetworkException('x'));
      return build();
    },
    act: (c) => c.load(_bid),
    expect: () => [
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.loadFailed,
      ),
    ],
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'setKg_clampedToAvailable',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setKg(9);
    },
    wait: settle,
    verify: (c) => expect(c.state.addedKg, 6),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'setKg_roundsToHalfKgAndFloorsAtZero',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setKg(2.7);
      expect(c.state.addedKg, 2.5);
      c.setKg(-1);
      expect(c.state.addedKg, 0);
    },
    wait: settle,
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'setItemQuantity_addsAndRemovesLine',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setItemQuantity('g1', 2);
      expect(c.state.items, {'g1': 2});
      c.setItemQuantity('g1', 0);
      expect(c.state.items, isEmpty);
    },
    wait: settle,
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'quote_debounced_singleCall',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setKg(1);
      c.setKg(2);
      c.setKg(3);
    },
    wait: settle,
    verify: (c) {
      verify(
        () => repository.quote('bid-1', addedKg: 3, items: const {}),
      ).called(1);
      verifyNever(
        () => repository.quote('bid-1', addedKg: 1, items: any(named: 'items')),
      );
      expect(c.state.grossQuote, 22.4);
      expect(c.state.status, AmendmentRequestStatus.editing);
      expect(c.state.canSubmit, isTrue);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'quote_whileQuoting_cannotSubmit',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setKg(3);
    },
    verify: (c) {
      expect(c.state.status, AmendmentRequestStatus.quoting);
      expect(c.state.grossQuote, isNull);
      expect(c.state.canSubmit, isFalse);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'emptyForm_cannotSubmitAndNoQuote',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.setKg(0);
    },
    wait: settle,
    verify: (c) {
      expect(c.state.canSubmit, isFalse);
      verifyNever(
        () => repository.quote(
          any(),
          addedKg: any(named: 'addedKg'),
          items: any(named: 'items'),
        ),
      );
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'quote_failure_emitsFailureWithError',
    build: () {
      when(
        () => repository.quote(
          'bid-1',
          addedKg: any(named: 'addedKg'),
          items: any(named: 'items'),
        ),
      ).thenThrow(const ValidationException('x', code: 'amendment-empty'));
      return build();
    },
    act: (c) async {
      await c.load(_bid);
      c.setKg(3);
    },
    wait: settle,
    verify: (c) {
      expect(c.state.status, AmendmentRequestStatus.failure);
      expect(c.state.error?.code, 'amendment-empty');
      expect(c.state.canSubmit, isFalse);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'selectMethod_changesMethod',
    build: build,
    act: (c) async {
      await c.load(_bid);
      c.selectMethod(BidPaymentMethod.stripe);
    },
    verify: (c) => expect(c.state.method, BidPaymentMethod.stripe),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'submit_cash_emitsSent_logsRequested',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.cash,
        ),
      ).thenAnswer((_) async => _cashCheckout);
      return build();
    },
    act: (c) async {
      await prepare(c);
      await c.submit();
    },
    skip: 3,
    expect: () => [
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.submitting,
      ),
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.sent,
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentRequested,
        properties: {
          'method': 'cash',
          'added_kg': 3.0,
          'items_count': 0,
          'amount_bracket': '20-50',
          'currency': 'EUR',
        },
      ),
    ).called(1),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'submit_card_emitsReadyToAuthorize',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.stripe,
        ),
      ).thenAnswer((_) async => _cardCheckout);
      return build();
    },
    act: (c) async {
      await prepare(c);
      c.selectMethod(BidPaymentMethod.stripe);
      await c.submit();
    },
    skip: 4,
    expect: () => [
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.submitting,
      ),
      isA<AmendmentRequestState>()
          .having(
            (s) => s.status,
            'status',
            AmendmentRequestStatus.readyToAuthorize,
          )
          .having((s) => s.checkout, 'checkout', _cardCheckout),
    ],
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentPaymentStarted,
          properties: {'method': 'card'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentRequested,
          properties: any(named: 'properties'),
        ),
      );
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'cardAuthorized_confirmsThenSent_logsRequested',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.stripe,
        ),
      ).thenAnswer((_) async => _cardCheckout);
      when(
        () => repository.confirmAuthorization('bid-1', 'am-1'),
      ).thenAnswer((_) async => _amendment);
      return build();
    },
    act: (c) async {
      await prepare(c);
      c.selectMethod(BidPaymentMethod.stripe);
      await c.submit();
      await c.cardAuthorized();
    },
    skip: 6,
    expect: () => [
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.confirming,
      ),
      isA<AmendmentRequestState>().having(
        (s) => s.status,
        'status',
        AmendmentRequestStatus.sent,
      ),
    ],
    verify: (_) {
      verify(() => repository.confirmAuthorization('bid-1', 'am-1')).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentRequested,
          properties: any(named: 'properties'),
        ),
      ).called(1);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'cardAuthorized_confirmFails_emitsFailureAndLogsActionFailed',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.stripe,
        ),
      ).thenAnswer((_) async => _cardCheckout);
      when(() => repository.confirmAuthorization('bid-1', 'am-1')).thenThrow(
        const ConflictException('x', code: 'amendment-payment-in-progress'),
      );
      return build();
    },
    act: (c) async {
      await prepare(c);
      c.selectMethod(BidPaymentMethod.stripe);
      await c.submit();
      await c.cardAuthorized();
    },
    verify: (c) {
      expect(c.state.status, AmendmentRequestStatus.failure);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentActionFailed,
          properties: {
            'action': 'confirm_authorization',
            'error_code': 'amendment-payment-in-progress',
          },
        ),
      ).called(1);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'authorizationAbandoned_cancelsAndReturnsToEditing',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.stripe,
        ),
      ).thenAnswer((_) async => _cardCheckout);
      when(
        () => repository.cancel('bid-1', 'am-1'),
      ).thenAnswer((_) async => _amendment);
      return build();
    },
    act: (c) async {
      await prepare(c);
      c.selectMethod(BidPaymentMethod.stripe);
      await c.submit();
      await c.authorizationAbandoned();
    },
    verify: (c) {
      verify(() => repository.cancel('bid-1', 'am-1')).called(1);
      expect(c.state.status, AmendmentRequestStatus.editing);
      expect(c.state.checkout, isNull);
      expect(c.state.canSubmit, isTrue);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'submit_capacity409_emitsFailure_logsRequestFailed',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.cash,
        ),
      ).thenThrow(
        const ConflictException('x', code: 'amendment-capacity-unavailable'),
      );
      return build();
    },
    act: (c) async {
      await prepare(c);
      await c.submit();
    },
    verify: (c) {
      expect(c.state.status, AmendmentRequestStatus.failure);
      expect(c.state.error?.code, 'amendment-capacity-unavailable');
      expect(c.state.canSubmit, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentRequestFailed,
          properties: {'error_code': 'amendment-capacity-unavailable'},
        ),
      ).called(1);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'submit_closingCode_emitsClosed',
    build: () {
      when(
        () => repository.create(
          'bid-1',
          addedKg: 3,
          items: const {},
          method: BidPaymentMethod.cash,
        ),
      ).thenThrow(const ConflictException('x', code: 'amendment-already-open'));
      return build();
    },
    act: (c) async {
      await prepare(c);
      await c.submit();
    },
    verify: (c) {
      expect(c.state.status, AmendmentRequestStatus.closed);
      expect(c.state.error?.code, 'amendment-already-open');
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'beginAuthorization_refusesWhenNothingToSubmit',
    build: build,
    act: (c) async {
      await c.load(_bid);
      expect(c.beginAuthorization(), isFalse);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'beginAuthorization_locksThenDeniedUnlocks',
    build: build,
    act: (c) async {
      await prepare(c);
      expect(c.beginAuthorization(), isTrue);
      expect(c.state.status, AmendmentRequestStatus.submitting);
      expect(c.state.isBusy, isTrue);
      expect(c.beginAuthorization(), isFalse);
      c.authorizationDenied();
      expect(c.state.status, AmendmentRequestStatus.editing);
      expect(c.state.canSubmit, isTrue);
    },
  );
}
