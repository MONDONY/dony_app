import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockErrorReporting extends Mock implements ErrorReportingService {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _supplement = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  rail: 'STRIPE',
  grossAmount: 16.8,
);

const _checkout = SupplementCheckout(
  rail: 'STRIPE',
  clientSecret: 'pi_1_secret_2',
  paymentMethodTypes: ['card', 'paypal'],
  amount: 16.8,
  currency: 'EUR',
);

const _alreadyPaid = SupplementCheckout(
  rail: 'STRIPE',
  amount: 16.8,
  currency: 'EUR',
);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;
  late _MockErrorReporting reporter;

  setUpAll(() => registerFallbackValue(StackTrace.empty));

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    reporter = _MockErrorReporting();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => reporter.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  });

  SupplementPaymentCubit build() =>
      SupplementPaymentCubit(repository, analytics, errorReporter: reporter);

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'pay : accepting puis readyToPay, paiement lancé tracé sans montant exact',
    setUp: () => when(
      () => repository.accept('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _checkout),
    build: build,
    act: (c) => c.pay(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(status: SupplementPaymentStatus.accepting),
      SupplementPaymentState(
        status: SupplementPaymentStatus.readyToPay,
        checkout: _checkout,
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementPaymentStarted,
        properties: {
          'method': 'card',
          'currency': 'EUR',
          'amount_bracket': '<20',
        },
      ),
    ).called(1),
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'pay : déjà payé (clientSecret nul) → paid directement, sans feuille',
    setUp: () => when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => _alreadyPaid),
    build: build,
    act: (c) => c.pay(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(status: SupplementPaymentStatus.accepting),
      SupplementPaymentState(
        status: SupplementPaymentStatus.paid,
        checkout: _alreadyPaid,
      ),
    ],
    verify: (_) => verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementPaymentStarted,
        properties: any(named: 'properties'),
      ),
    ),
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'pay : erreur du serveur → failure avec le code, tracée',
    setUp: () => when(
      () => repository.accept(any(), any()),
    ).thenThrow(const ConflictException('d', code: 'supplement-expired')),
    build: build,
    act: (c) => c.pay(_bid, _supplement),
    expect: () => [
      const SupplementPaymentState(status: SupplementPaymentStatus.accepting),
      isA<SupplementPaymentState>()
          .having((s) => s.status, 'status', SupplementPaymentStatus.failure)
          .having((s) => s.error?.code, 'code', 'supplement-expired'),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementActionFailed,
        properties: {'action': 'pay', 'error_code': 'supplement-expired'},
      ),
    ).called(1),
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'pay : ignoré pendant un paiement en cours',
    build: build,
    seed: () => const SupplementPaymentState(
      status: SupplementPaymentStatus.readyToPay,
      checkout: _checkout,
    ),
    act: (c) => c.pay(_bid, _supplement),
    expect: () => const <SupplementPaymentState>[],
    verify: (_) => verifyNever(() => repository.accept(any(), any())),
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'sheetClosed : feuille fermée sans payer → retour à idle',
    build: build,
    seed: () => const SupplementPaymentState(
      status: SupplementPaymentStatus.readyToPay,
      checkout: _checkout,
    ),
    act: (c) => c.sheetClosed(),
    expect: () => const [SupplementPaymentState()],
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'sheetClosed : sans effet après le succès',
    build: build,
    seed: () => const SupplementPaymentState(
      status: SupplementPaymentStatus.confirming,
      checkout: _checkout,
    ),
    act: (c) => c.sheetClosed(),
    expect: () => const <SupplementPaymentState>[],
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'confirmPayment : confirming puis paid',
    setUp: () => when(
      () => repository.confirmPayment('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _supplement),
    build: build,
    seed: () => const SupplementPaymentState(
      status: SupplementPaymentStatus.readyToPay,
      checkout: _checkout,
    ),
    act: (c) => c.confirmPayment(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(
        status: SupplementPaymentStatus.confirming,
        checkout: _checkout,
      ),
      SupplementPaymentState(
        status: SupplementPaymentStatus.paid,
        checkout: _checkout,
      ),
    ],
    verify: (_) => verifyNever(
      () => reporter.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ),
  );

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'confirmPayment : échec rapporté et tracé, jamais montré (le webhook '
    'prend le relais)',
    setUp: () => when(() => repository.confirmPayment(any(), any())).thenThrow(
      const ConflictException('d', code: 'supplement-payment-processing'),
    ),
    build: build,
    act: (c) => c.confirmPayment(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(status: SupplementPaymentStatus.confirming),
      SupplementPaymentState(status: SupplementPaymentStatus.paid),
    ],
    verify: (_) {
      verify(
        () => reporter.report(
          any(),
          operation: 'bid.supplement.confirmPayment',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementActionFailed,
          properties: {
            'action': 'confirm_payment',
            'error_code': 'supplement-payment-processing',
          },
        ),
      ).called(1);
    },
  );

  test('confirmPayment : la requête part même cubit fermé', () async {
    when(
      () => repository.confirmPayment(any(), any()),
    ).thenAnswer((_) async => _supplement);
    final cubit = build();
    await cubit.close();

    await cubit.confirmPayment(_bid, _supplement);

    verify(() => repository.confirmPayment('bid-1', 'sup-1')).called(1);
  });

  test('pay : cubit fermé pendant l\'appel, aucun état émis', () async {
    when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => _checkout);
    final cubit = build();
    final future = cubit.pay(_bid, _supplement);
    await cubit.close();
    await future;
    expect(cubit.state.status, SupplementPaymentStatus.accepting);
  });

  test('pay : cubit fermé pendant un échec, rien n\'est émis', () async {
    when(
      () => repository.accept(any(), any()),
    ).thenAnswer((_) async => throw const ServerException('boom'));
    final cubit = build();
    final future = cubit.pay(_bid, _supplement);
    await cubit.close();
    await future;
    expect(cubit.state.status, SupplementPaymentStatus.accepting);
  });

  test('sheetClosed : sans effet cubit fermé', () async {
    final cubit = build();
    await cubit.close();
    cubit.sheetClosed();
    expect(cubit.state.status, SupplementPaymentStatus.idle);
  });

  test('isBusy pendant acceptation, feuille et confirmation', () {
    for (final status in SupplementPaymentStatus.values) {
      expect(
        SupplementPaymentState(status: status).isBusy,
        status == SupplementPaymentStatus.accepting ||
            status == SupplementPaymentStatus.readyToPay ||
            status == SupplementPaymentStatus.confirming,
        reason: status.name,
      );
    }
  });
}
