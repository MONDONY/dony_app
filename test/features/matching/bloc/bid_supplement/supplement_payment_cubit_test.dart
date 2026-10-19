import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
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

BidSupplement _with(BidSupplementStatus status) => BidSupplement(
  id: 'sup-1',
  status: status,
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
    'confirmPayment : statut payé rendu → confirming puis paid',
    setUp: () => when(
      () => repository.confirmPayment('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _with(BidSupplementStatus.paid)),
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
    'confirmPayment : échec rapporté et tracé, jamais « payé » : '
    'confirmation en attente (le webhook prend le relais)',
    setUp: () => when(() => repository.confirmPayment(any(), any())).thenThrow(
      const ConflictException('d', code: 'supplement-payment-processing'),
    ),
    build: build,
    act: (c) => c.confirmPayment(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(status: SupplementPaymentStatus.confirming),
      SupplementPaymentState(
        status: SupplementPaymentStatus.confirmationPending,
      ),
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

  for (final status in [
    BidSupplementStatus.paymentPending,
    BidSupplementStatus.proposed,
  ]) {
    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'confirmPayment : statut ${status.name} rendu → confirmation en '
      'attente, jamais « payé »',
      setUp: () => when(
        () => repository.confirmPayment(any(), any()),
      ).thenAnswer((_) async => _with(status)),
      build: build,
      act: (c) => c.confirmPayment(_bid, _supplement),
      expect: () => const [
        SupplementPaymentState(status: SupplementPaymentStatus.confirming),
        SupplementPaymentState(
          status: SupplementPaymentStatus.confirmationPending,
        ),
      ],
    );
  }

  blocTest<SupplementPaymentCubit, SupplementPaymentState>(
    'confirmPayment : versé compte aussi comme payé',
    setUp: () => when(
      () => repository.confirmPayment(any(), any()),
    ).thenAnswer((_) async => _with(BidSupplementStatus.paidOut)),
    build: build,
    act: (c) => c.confirmPayment(_bid, _supplement),
    expect: () => const [
      SupplementPaymentState(status: SupplementPaymentStatus.confirming),
      SupplementPaymentState(status: SupplementPaymentStatus.paid),
    ],
  );

  group('autorisation locale', () {
    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'beginAuthorization : authorizing, le bouton est occupé',
      build: build,
      act: (c) => expect(c.beginAuthorization(), isTrue),
      expect: () => const [
        SupplementPaymentState(status: SupplementPaymentStatus.authorizing),
      ],
      verify: (c) => expect(c.state.isBusy, isTrue),
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'beginAuthorization : refusé si une invite est déjà ouverte',
      build: build,
      seed: () => const SupplementPaymentState(
        status: SupplementPaymentStatus.authorizing,
      ),
      act: (c) => expect(c.beginAuthorization(), isFalse),
      expect: () => const <SupplementPaymentState>[],
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'authorizationDenied : retour à idle',
      build: build,
      seed: () => const SupplementPaymentState(
        status: SupplementPaymentStatus.authorizing,
      ),
      act: (c) => c.authorizationDenied(),
      expect: () => const [SupplementPaymentState()],
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'authorizationDenied : sans effet hors autorisation',
      build: build,
      seed: () => const SupplementPaymentState(
        status: SupplementPaymentStatus.accepting,
      ),
      act: (c) => c.authorizationDenied(),
      expect: () => const <SupplementPaymentState>[],
    );

    test('beginAuthorization / authorizationDenied : cubit fermé', () async {
      final cubit = build();
      await cubit.close();
      expect(cubit.beginAuthorization(), isFalse);
      cubit.authorizationDenied();
      expect(cubit.state.status, SupplementPaymentStatus.idle);
    });

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'pay après autorisation : accepting puis readyToPay',
      setUp: () => when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => _checkout),
      build: build,
      seed: () => const SupplementPaymentState(
        status: SupplementPaymentStatus.authorizing,
      ),
      act: (c) => c.pay(_bid, _supplement),
      expect: () => const [
        SupplementPaymentState(status: SupplementPaymentStatus.accepting),
        SupplementPaymentState(
          status: SupplementPaymentStatus.readyToPay,
          checkout: _checkout,
        ),
      ],
    );
  });

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

  test('isBusy pendant acceptation, feuille, attente mobile money et '
      'confirmation', () {
    for (final status in SupplementPaymentStatus.values) {
      expect(
        SupplementPaymentState(status: status).isBusy,
        status == SupplementPaymentStatus.authorizing ||
            status == SupplementPaymentStatus.accepting ||
            status == SupplementPaymentStatus.readyToPay ||
            status == SupplementPaymentStatus.awaitingMobileMoney ||
            status == SupplementPaymentStatus.confirming,
        reason: status.name,
      );
    }
  });

  group('mobile money (PR A3)', () {
    const mmSupplement = BidSupplement(
      id: 'sup-1',
      status: BidSupplementStatus.proposed,
      rail: 'PAWAPAY',
      grossAmount: 1500,
      currency: 'XOF',
    );
    const mmCheckout = SupplementCheckout(
      supplement: BidSupplement(
        id: 'sup-1',
        status: BidSupplementStatus.paymentPending,
        rail: 'PAWAPAY',
        grossAmount: 1500,
        currency: 'XOF',
      ),
      rail: 'PAWAPAY',
      amount: 1500,
      currency: 'XOF',
    );
    const mmPaid = SupplementCheckout(
      supplement: BidSupplement(
        id: 'sup-1',
        status: BidSupplementStatus.paid,
        rail: 'PAWAPAY',
        grossAmount: 1500,
        currency: 'XOF',
      ),
      rail: 'PAWAPAY',
      amount: 1500,
      currency: 'XOF',
    );
    const awaiting = SupplementPaymentState(
      status: SupplementPaymentStatus.awaitingMobileMoney,
      checkout: mmCheckout,
    );

    test('awaitingMobileMoney occupe le bouton', () {
      expect(awaiting.isBusy, isTrue);
      expect(
        const SupplementPaymentState(
          status: SupplementPaymentStatus.mobileMoneyNotConfirmed,
        ).isBusy,
        isFalse,
      );
    });

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'pay : accept puis écran d\'attente, paiement lancé tracé en '
      'mobile_money, jamais de feuille ni de confirm-payment',
      setUp: () => when(
        () => repository.accept('bid-1', 'sup-1'),
      ).thenAnswer((_) async => mmCheckout),
      build: build,
      act: (c) => c.pay(_bid, mmSupplement),
      expect: () => const [
        SupplementPaymentState(status: SupplementPaymentStatus.accepting),
        awaiting,
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.bidSupplementPaymentStarted,
            properties: {
              'method': 'mobile_money',
              'currency': 'XOF',
              'amount_bracket': analyticsAmountBracket(1500),
            },
          ),
        ).called(1);
        verifyNever(() => repository.confirmPayment(any(), any()));
      },
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'pay : supplément déjà payé à l\'acceptation → paid, pas d\'attente',
      setUp: () => when(
        () => repository.accept(any(), any()),
      ).thenAnswer((_) async => mmPaid),
      build: build,
      act: (c) => c.pay(_bid, mmSupplement),
      expect: () => const [
        SupplementPaymentState(status: SupplementPaymentStatus.accepting),
        SupplementPaymentState(
          status: SupplementPaymentStatus.paid,
          checkout: mmPaid,
        ),
      ],
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'retour payé → paid',
      build: build,
      seed: () => awaiting,
      act: (c) => c.mobileMoneyReturned(true),
      expect: () => const [
        SupplementPaymentState(
          status: SupplementPaymentStatus.paid,
          checkout: mmCheckout,
        ),
      ],
    );

    for (final result in [false, null]) {
      blocTest<SupplementPaymentCubit, SupplementPaymentState>(
        'retour sans paiement ($result) → mobileMoneyNotConfirmed',
        build: build,
        seed: () => awaiting,
        act: (c) => c.mobileMoneyReturned(result),
        expect: () => const [
          SupplementPaymentState(
            status: SupplementPaymentStatus.mobileMoneyNotConfirmed,
            checkout: mmCheckout,
          ),
        ],
      );
    }

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'retour hors attente : sans effet',
      build: build,
      act: (c) => c.mobileMoneyReturned(true),
      expect: () => const <SupplementPaymentState>[],
    );

    blocTest<SupplementPaymentCubit, SupplementPaymentState>(
      'retour après fermeture du cubit : sans effet ni erreur',
      build: build,
      seed: () => awaiting,
      act: (c) async {
        await c.close();
        c.mobileMoneyReturned(true);
      },
      expect: () => const <SupplementPaymentState>[],
    );
  });
}
