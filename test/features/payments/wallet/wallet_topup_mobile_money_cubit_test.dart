import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  const phoneNumber = '+221771234567';

  const catalog = MobileMoneyProviderCatalog(
    country: 'SN',
    currency: 'XOF',
    msisdnMasked: '+221 ** ** 12 34',
    detected: 'ORANGE_SEN',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_SEN',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_SEN', label: 'Wave'),
    ],
  );

  const topup = WalletTopupModel(
    topupId: 'topup-1',
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
  );

  const topup2 = WalletTopupModel(
    topupId: 'topup-2',
    currency: 'XOF',
    provider: 'WAVE_SEN',
    providerLabel: 'Wave',
    msisdnMasked: '+221 ** ** 56 78',
  );

  WalletTopupStatusModel statusFor(
    String status, {
    String topupId = 'topup-1',
    String? failureReason,
    String? failureCode,
    DateTime? expiresAt,
  }) => WalletTopupStatusModel(
    topupId: topupId,
    status: status,
    amount: 20000,
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
    failureReason: failureReason,
    failureCode: failureCode,
    expiresAt: expiresAt,
  );

  group('loadProviders / initiate (sans minuterie)', () {
    late MockWalletRepository repo;
    late MockAnalyticsService analytics;
    late WalletTopupMobileMoneyCubit cubit;

    setUp(() {
      repo = MockWalletRepository();
      analytics = MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      cubit = WalletTopupMobileMoneyCubit(repo, analytics);
    });

    tearDown(() => cubit.close());

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      'loadProviders() succès : ProvidersReady avec selectedProvider = détecté',
      build: () {
        when(
          () => repo.topupProviders(phoneNumber),
        ).thenAnswer((_) async => catalog);
        return cubit;
      },
      act: (c) => c.loadProviders(phoneNumber),
      expect: () => [
        isA<WalletTopupMobileMoneyProvidersLoading>(),
        isA<WalletTopupMobileMoneyProvidersReady>()
            .having((s) => s.catalog, 'catalog', catalog)
            .having(
              (s) => s.selectedProvider,
              'selectedProvider',
              'ORANGE_SEN',
            ),
      ],
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      'loadProviders() erreur réseau : état Error',
      build: () {
        when(
          () => repo.topupProviders(phoneNumber),
        ).thenThrow(Exception('network'));
        return cubit;
      },
      act: (c) => c.loadProviders(phoneNumber),
      expect: () => [
        isA<WalletTopupMobileMoneyProvidersLoading>(),
        isA<WalletTopupMobileMoneyError>(),
      ],
    );

    test(
      "useOperator() : sans catalogue chargé, l'opérateur choisi sur l'écran "
      '« Recharger » part au back',
      () async {
        when(
          () => repo.topupMobileMoney(
            amount: 5000,
            phoneNumber: phoneNumber,
            provider: 'WAVE_SEN',
          ),
        ).thenAnswer((_) async => topup2);

        cubit.useOperator('WAVE_SEN');
        await cubit.initiate(amount: 5000, phoneNumber: phoneNumber);
        cubit.stopPolling();

        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
        verify(
          () => repo.topupMobileMoney(
            amount: 5000,
            phoneNumber: phoneNumber,
            provider: 'WAVE_SEN',
          ),
        ).called(1);
      },
    );

    test(
      "useOperator() : le catalogue de l'ancien parcours garde la main",
      () async {
        when(
          () => repo.topupProviders(phoneNumber),
        ).thenAnswer((_) async => catalog);
        when(
          () => repo.topupMobileMoney(
            amount: 5000,
            phoneNumber: phoneNumber,
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async => topup);

        cubit.useOperator('WAVE_SEN');
        await cubit.loadProviders(phoneNumber);
        await cubit.initiate(amount: 5000, phoneNumber: phoneNumber);
        cubit.stopPolling();

        verify(
          () => repo.topupMobileMoney(
            amount: 5000,
            phoneNumber: phoneNumber,
            provider: 'ORANGE_SEN',
          ),
        ).called(1);
      },
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      'selectProvider(null) efface la sélection (décochée dans la checklist)',
      build: () {
        when(
          () => repo.topupProviders(phoneNumber),
        ).thenAnswer((_) async => catalog);
        return cubit;
      },
      act: (c) async {
        await c.loadProviders(phoneNumber);
        c.selectProvider(null);
      },
      expect: () => [
        isA<WalletTopupMobileMoneyProvidersLoading>(),
        isA<WalletTopupMobileMoneyProvidersReady>().having(
          (s) => s.selectedProvider,
          'selectedProvider',
          'ORANGE_SEN',
        ),
        isA<WalletTopupMobileMoneyProvidersReady>().having(
          (s) => s.selectedProvider,
          'selectedProvider',
          isNull,
        ),
      ],
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      "initiate() : Initiating puis Awaiting, event 'initiated' avec "
      'exactement provider et currency',
      build: () {
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async => topup);
        // Le sondage démarré par initiate() ne doit pas planter le test :
        // statut PENDING indéfiniment, jamais atteint sans avancer le temps.
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));
        return cubit;
      },
      act: (c) => c.initiate(amount: 20000, phoneNumber: phoneNumber),
      expect: () => [
        isA<WalletTopupMobileMoneyInitiating>(),
        isA<WalletTopupMobileMoneyAwaiting>().having(
          (s) => s.topup.topupId,
          'topup.topupId',
          'topup-1',
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyInitiated,
            properties: {
              'provider': 'ORANGE_SEN',
              'currency': 'XOF',
              'custom': false,
            },
          ),
        ).called(1);
      },
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      "initiate(custom: true) : « Autre montant » marqué dans l'event, "
      'jamais le montant (FLUTTER-CF)',
      build: () {
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async => topup);
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));
        return cubit;
      },
      act: (c) =>
          c.initiate(amount: 12500, phoneNumber: phoneNumber, custom: true),
      skip: 2,
      expect: () => <WalletTopupMobileMoneyState>[],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyInitiated,
            properties: {
              'provider': 'ORANGE_SEN',
              'currency': 'XOF',
              'custom': true,
            },
          ),
        ).called(1);
      },
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      'initiate() erreur réseau : état Error, échec tracé, pas d\'initiation',
      build: () {
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenThrow(Exception('network'));
        return cubit;
      },
      act: (c) => c.initiate(amount: 20000, phoneNumber: phoneNumber),
      expect: () => [
        isA<WalletTopupMobileMoneyInitiating>(),
        isA<WalletTopupMobileMoneyError>(),
      ],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyInitiated,
            properties: any(named: 'properties'),
          ),
        );
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupFailed,
            properties: {
              'method': 'mobile_money',
              'amount_bracket': '>100',
              'reason': 'initiate_failed',
              'error_code': 'unknown',
            },
          ),
        ).called(1);
      },
    );
  });

  group('garde anti double tap sur « Payer »', () {
    late MockWalletRepository repo;
    late MockAnalyticsService analytics;
    late WalletTopupMobileMoneyCubit cubit;

    setUp(() {
      repo = MockWalletRepository();
      analytics = MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      cubit = WalletTopupMobileMoneyCubit(repo, analytics);
    });

    tearDown(() {
      cubit.stopPolling();
      return cubit.close();
    });

    test('deux initiate() dans la même frame n\'ouvrent qu\'UN dépôt côté '
        'serveur (sinon deux débits)', () async {
      final gate = Completer<WalletTopupModel>();
      when(
        () => repo.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) => gate.future);

      final first = cubit.initiate(amount: 20000, phoneNumber: phoneNumber);
      final second = cubit.initiate(amount: 20000, phoneNumber: phoneNumber);

      gate.complete(topup);
      await Future.wait([first, second]);

      verify(
        () => repo.topupMobileMoney(amount: 20000, phoneNumber: phoneNumber),
      ).called(1);
      expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
    });

    test('le verrou est relâché : une reprise après coup fonctionne', () async {
      when(
        () => repo.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => topup);

      await cubit.initiate(amount: 20000, phoneNumber: phoneNumber);
      cubit.reset();
      await cubit.initiate(amount: 20000, phoneNumber: phoneNumber);

      verify(
        () => repo.topupMobileMoney(amount: 20000, phoneNumber: phoneNumber),
      ).called(2);
    });
  });

  group('sondage (fakeAsync)', () {
    late MockWalletRepository repo;
    late MockAnalyticsService analytics;

    setUp(() {
      repo = MockWalletRepository();
      analytics = MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(
        () => repo.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => topup);
    });

    test('PENDING, PENDING, CONFIRMED -> Confirmed, timer stoppé, event '
        'confirmed une seule fois', () {
      fakeAsync((async) {
        var call = 0;
        when(() => repo.topupStatus('topup-1')).thenAnswer((_) async {
          call++;
          return call < 3 ? statusFor('PENDING') : statusFor('CONFIRMED');
        });

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

        async.elapse(WalletTopupMobileMoneyCubit.pollInterval); // PENDING
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval); // PENDING
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval); // CONFIRMED
        expect(cubit.state, isA<WalletTopupMobileMoneyConfirmed>());

        // Timer arrêté : aucun autre appel de statut après confirmation,
        // même en laissant le temps s'écouler largement.
        expect(async.periodicTimerCount, 0);
        final callsAtConfirmation = call;
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval * 5);
        expect(call, callsAtConfirmation);

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyConfirmed,
            properties: {'provider': 'ORANGE_SEN', 'currency': 'XOF'},
          ),
        ).called(1);
        // Famille commune des recharges et des paiements, tous moyens.
        const completed = {
          'method': 'mobile_money',
          'currency': 'XOF',
          'amount_bracket': '>100',
          'provider': 'ORANGE_SEN',
        };
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupCompleted,
            properties: completed,
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentSucceeded,
            properties: {...completed, 'context': 'wallet_topup'},
          ),
        ).called(1);

        unawaited(cubit.close());
      });
    });

    test('FAILED -> Failed(failureReason), timer stoppé', () {
      fakeAsync((async) {
        when(() => repo.topupStatus('topup-1')).thenAnswer(
          (_) async => statusFor('FAILED', failureReason: 'Solde insuffisant'),
        );

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();

        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyFailed>().having(
            (s) => s.failureReason,
            'failureReason',
            'Solde insuffisant',
          ),
        );
        expect(async.periodicTimerCount, 0);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyConfirmed,
            properties: any(named: 'properties'),
          ),
        );
        // Refus de l'opérateur : tracé, sans jamais son motif (texte libre).
        const failed = {
          'method': 'mobile_money',
          'currency': 'XOF',
          'amount_bracket': '>100',
          'provider': 'ORANGE_SEN',
          'reason': 'declined',
        };
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupFailed,
            properties: failed,
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentFailed,
            properties: {...failed, 'context': 'wallet_topup'},
          ),
        ).called(1);

        unawaited(cubit.close());
      });
    });

    test('FAILED sans motif ni code serveur : aucun texte gardé '
        '(l\'écran affiche le message générique)', () {
      fakeAsync((async) {
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('FAILED'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyFailed>()
              .having((s) => s.failureReason, 'failureReason', isNull)
              .having((s) => s.failureCode, 'failureCode', isNull),
        );

        unawaited(cubit.close());
      });
    });

    test('sans expiresAt du back : repli à 15 min, puis Overdue et sondage '
        'maintenu (jamais un échec déclaré par l\'app)', () {
      fakeAsync((async) {
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();

        async.elapse(
          WalletTopupMobileMoneyCubit.expiry - const Duration(seconds: 3),
        );
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

        async.elapse(const Duration(seconds: 6));

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyOverdue>().having(
            (s) => s.topup.topupId,
            'topupId',
            'topup-1',
          ),
        );
        expect(async.periodicTimerCount, 1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupFailed,
            properties: any(named: 'properties'),
          ),
        );

        unawaited(cubit.close());
      });
    });

    test('poll_pastExpiresAt_stillPending_emitsOverdue_keepsPolling', () {
      fakeAsync((async) {
        final expiresAt = clock.now().add(const Duration(seconds: 5));
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer(
          (_) async => WalletTopupModel(
            topupId: 'topup-1',
            currency: 'XOF',
            provider: 'ORANGE_SEN',
            providerLabel: 'Orange Money',
            msisdnMasked: '+221 ** ** 12 34',
            expiresAt: expiresAt,
          ),
        );
        var calls = 0;
        when(() => repo.topupStatus('topup-1')).thenAnswer((_) async {
          calls++;
          return statusFor('PENDING');
        });

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );
        final states = <WalletTopupMobileMoneyState>[];
        final sub = cubit.stream.listen(states.add);

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval); // 3 s
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

        async.elapse(WalletTopupMobileMoneyCubit.pollInterval); // 6 s
        expect(cubit.state, isA<WalletTopupMobileMoneyOverdue>());

        // Le sondage continue : l'opérateur peut encore valider.
        final callsAtOverdue = calls;
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval * 2);
        expect(calls, greaterThan(callsAtOverdue));
        expect(async.periodicTimerCount, 1);
        // Un seul passage en Overdue, jamais réémis à chaque tick.
        expect(states.whereType<WalletTopupMobileMoneyOverdue>(), hasLength(1));

        unawaited(sub.cancel());
        unawaited(cubit.close());
      });
    });

    test('poll_confirmedWhileOverdue_emitsConfirmed', () {
      fakeAsync((async) {
        final expiresAt = clock.now().add(const Duration(seconds: 2));
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer(
          (_) async => WalletTopupModel(
            topupId: 'topup-1',
            currency: 'XOF',
            provider: 'ORANGE_SEN',
            providerLabel: 'Orange Money',
            msisdnMasked: '+221 ** ** 12 34',
            expiresAt: expiresAt,
          ),
        );
        var call = 0;
        when(() => repo.topupStatus('topup-1')).thenAnswer((_) async {
          call++;
          return call < 2 ? statusFor('PENDING') : statusFor('CONFIRMED');
        });

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);
        expect(cubit.state, isA<WalletTopupMobileMoneyOverdue>());

        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);
        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyConfirmed>().having(
            (s) => s.resumed,
            'resumed',
            isFalse,
          ),
        );
        expect(async.periodicTimerCount, 0);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupCompleted,
            properties: any(named: 'properties'),
          ),
        ).called(1);

        unawaited(cubit.close());
      });
    });

    test('poll_failed_carriesFailureCode', () {
      fakeAsync((async) {
        when(() => repo.topupStatus('topup-1')).thenAnswer(
          (_) async => statusFor(
            'FAILED',
            failureCode: 'insufficient-balance',
            failureReason: 'Solde insuffisant sur votre compte mobile money.',
          ),
        );

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyFailed>()
              .having(
                (s) => s.failureCode,
                'failureCode',
                'insufficient-balance',
              )
              .having(
                (s) => s.failureReason,
                'failureReason',
                'Solde insuffisant sur votre compte mobile money.',
              ),
        );
        // Le code Yadony part dans l'analytics (jamais le texte).
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupFailed,
            properties: any(
              named: 'properties',
              that: containsPair('error_code', 'insufficient-balance'),
            ),
          ),
        ).called(1);

        unawaited(cubit.close());
      });
    });

    test('detach_stopsPolling_withoutCancelledEvent', () {
      fakeAsync((async) {
        final expiresAt = clock.now().add(const Duration(minutes: 10));
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer(
          (_) async => WalletTopupModel(
            topupId: 'topup-1',
            currency: 'XOF',
            provider: 'ORANGE_SEN',
            providerLabel: 'Orange Money',
            msisdnMasked: '+221 ** ** 12 34',
            expiresAt: expiresAt,
          ),
        );
        var calls = 0;
        when(() => repo.topupStatus('topup-1')).thenAnswer((_) async {
          calls++;
          return statusFor('PENDING');
        });

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));

        cubit.detach();
        // Le ✕ et le PopScope appellent tous deux detach() : sans effet la
        // seconde fois.
        cubit.detach();

        expect(async.periodicTimerCount, 0);
        // La recharge n'est pas abandonnée : l'état reste celui de l'attente.
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
        final callsAtDetach = calls;
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval * 3);
        expect(calls, callsAtDetach);

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupAwaitingClosed,
            properties: {'remaining_s': 540},
          ),
        ).called(1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupCancelled,
            properties: any(named: 'properties'),
          ),
        );

        unawaited(cubit.close());
      });
    });

    test('reset() pendant Overdue (« Payer avec un autre numéro ») : '
        'wallet_topup_cancelled, retour à Idle', () {
      fakeAsync((async) {
        final expiresAt = clock.now().add(const Duration(seconds: 1));
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer(
          (_) async => WalletTopupModel(
            topupId: 'topup-1',
            currency: 'XOF',
            provider: 'ORANGE_SEN',
            providerLabel: 'Orange Money',
            msisdnMasked: '+221 ** ** 12 34',
            expiresAt: expiresAt,
          ),
        );
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);
        expect(cubit.state, isA<WalletTopupMobileMoneyOverdue>());

        cubit.reset();

        expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
        expect(async.periodicTimerCount, 0);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupCancelled,
            properties: {'method': 'mobile_money'},
          ),
        ).called(1);

        unawaited(cubit.close());
      });
    });

    test('resumePending_withOpenTopup_emitsAwaiting_andPolls', () {
      fakeAsync((async) {
        final expiresAt = clock.now().add(const Duration(minutes: 12));
        when(
          () => repo.pendingTopup(),
        ).thenAnswer((_) async => statusFor('PENDING', expiresAt: expiresAt));
        var call = 0;
        when(() => repo.topupStatus('topup-1')).thenAnswer((_) async {
          call++;
          return call < 2 ? statusFor('PENDING') : statusFor('CONFIRMED');
        });

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        bool? resumed;
        unawaited(cubit.resumePending().then((r) => resumed = r));
        async.flushMicrotasks();

        expect(resumed, isTrue);
        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyAwaiting>()
              .having((s) => s.topup.topupId, 'topupId', 'topup-1')
              .having((s) => s.topup.expiresAt, 'expiresAt', expiresAt)
              .having((s) => s.amount, 'amount', 20000),
        );
        expect(async.periodicTimerCount, 1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupResumed,
            properties: {'provider': 'ORANGE_SEN', 'currency': 'XOF'},
          ),
        ).called(1);

        async.elapse(WalletTopupMobileMoneyCubit.pollInterval * 2);
        // Confirmation d'une recharge reprise : signalée comme telle, le
        // numéro (masqué) n'est jamais mémorisé.
        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyConfirmed>().having(
            (s) => s.resumed,
            'resumed',
            isTrue,
          ),
        );

        unawaited(cubit.close());
      });
    });

    test('resumePending_none_returnsFalse', () async {
      when(() => repo.pendingTopup()).thenAnswer((_) async => null);
      final cubit = WalletTopupMobileMoneyCubit(repo, analytics);

      expect(await cubit.resumePending(), isFalse);
      expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.walletTopupResumed,
          properties: any(named: 'properties'),
        ),
      );
      await cubit.close();
    });

    test('resumePending : erreur réseau -> false, rien ne change', () async {
      when(() => repo.pendingTopup()).thenThrow(Exception('network'));
      final cubit = WalletTopupMobileMoneyCubit(repo, analytics);

      expect(await cubit.resumePending(), isFalse);
      expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
      await cubit.close();
    });

    test('resumePending : une recharge lancée entre-temps garde la main', () {
      fakeAsync((async) {
        final pending = Completer<WalletTopupStatusModel?>();
        when(() => repo.pendingTopup()).thenAnswer((_) => pending.future);
        when(
          () => repo.topupStatus(any()),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        bool? resumed;
        unawaited(cubit.resumePending().then((r) => resumed = r));
        unawaited(cubit.initiate(amount: 5000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        pending.complete(statusFor('PENDING', topupId: 'topup-old'));
        async.flushMicrotasks();

        expect(resumed, isFalse);
        expect(
          (cubit.state as WalletTopupMobileMoneyAwaiting).topup.topupId,
          'topup-1',
        );

        unawaited(cubit.close());
      });
    });

    test(
      'close() pendant le sondage : aucun emit ultérieur, aucun timer ne survit',
      () {
        fakeAsync((async) {
          when(
            () => repo.topupStatus('topup-1'),
          ).thenAnswer((_) async => statusFor('PENDING'));

          final cubit = WalletTopupMobileMoneyCubit(
            repo,
            analytics,
            now: () => clock.now(),
          );
          final states = <WalletTopupMobileMoneyState>[];
          final sub = cubit.stream.listen(states.add);

          unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
          async.flushMicrotasks();

          unawaited(cubit.close());
          expect(async.periodicTimerCount, 0);

          final statesAtClose = List.of(states);
          // Le temps qui aurait déclenché l'expiration (ou une confirmation)
          // ne doit produire aucun nouvel état : le cubit est fermé.
          async.elapse(
            WalletTopupMobileMoneyCubit.expiry + const Duration(minutes: 1),
          );

          expect(states, statesAtClose);
          expect(async.periodicTimerCount, 0);

          unawaited(sub.cancel());
        });
      },
    );

    test('close() pendant une requête topupStatus EN VOL : aucun emit '
        'ultérieur, aucun timer ne survit', () {
      fakeAsync((async) {
        final slowStatus = Completer<WalletTopupStatusModel>();
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) => slowStatus.future);

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );
        final states = <WalletTopupMobileMoneyState>[];
        final sub = cubit.stream.listen(states.add);

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();

        // Le tick fait partir la requête de statut, qui reste en vol
        // (le Completer n'est jamais résolu avant la fermeture).
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        unawaited(cubit.close());
        expect(async.periodicTimerCount, 0);

        final statesAtClose = List.of(states);

        // La réponse tardive arrive après la fermeture : aucun effet.
        slowStatus.complete(statusFor('CONFIRMED'));
        async.flushMicrotasks();

        expect(states, statesAtClose);
        expect(async.periodicTimerCount, 0);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyConfirmed,
            properties: any(named: 'properties'),
          ),
        );

        unawaited(sub.cancel());
      });
    });

    test("motif d'échec entouré d'espaces : nettoyé avant affichage", () {
      fakeAsync((async) {
        when(() => repo.topupStatus('topup-1')).thenAnswer(
          (_) async =>
              statusFor('FAILED', failureReason: '   Solde insuffisant   '),
        );

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyFailed>().having(
            (s) => s.failureReason,
            'failureReason',
            'Solde insuffisant',
          ),
        );

        unawaited(cubit.close());
      });
    });

    test("motif d'échec composé uniquement d'espaces : traité comme absent, "
        'aucun failureReason (l\'écran affiche le message générique)', () {
      fakeAsync((async) {
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('FAILED', failureReason: '   '));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        expect(
          cubit.state,
          isA<WalletTopupMobileMoneyFailed>()
              .having((s) => s.failureReason, 'failureReason', isNull)
              .having((s) => s.failureCode, 'failureCode', isNull),
        );

        unawaited(cubit.close());
      });
    });

    test('IMPORTANT — sondage obsolète : initiate() n°2 pendant qu\'une '
        'réponse de sondage de la session n°1 est encore en vol ne doit ni '
        "écraser l'état de la session 2, ni tuer son timer, ni émettre "
        'confirmed pour la session 1', () {
      fakeAsync((async) {
        var topupCall = 0;
        when(
          () => repo.topupMobileMoney(
            amount: any(named: 'amount'),
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async {
          topupCall++;
          return topupCall == 1 ? topup : topup2;
        });

        final slowStatus1 = Completer<WalletTopupStatusModel>();
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) => slowStatus1.future);

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        // Session 1 : initiée, son sondage démarre.
        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        expect(
          (cubit.state as WalletTopupMobileMoneyAwaiting).topup.topupId,
          'topup-1',
        );

        // Premier tick : la requête de statut de la session 1 part et
        // reste en vol (le Completer n'est résolu que plus bas).
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        // Pendant que la session 1 attend toujours sa réponse, une
        // nouvelle recharge démarre (relance depuis l'écran, par ex.).
        unawaited(cubit.initiate(amount: 15000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        expect(
          (cubit.state as WalletTopupMobileMoneyAwaiting).topup.topupId,
          'topup-2',
        );
        // Le timer de la session 1 a bien été coupé par le nouvel
        // initiate(), remplacé par celui de la session 2 : un seul timer
        // actif.
        expect(async.periodicTimerCount, 1);

        // La réponse tardive de la session 1 arrive enfin : CONFIRMED.
        slowStatus1.complete(statusFor('CONFIRMED'));
        async.flushMicrotasks();

        // L'état reste celui de la session 2, jamais écrasé par la
        // réponse obsolète de la session 1.
        expect(
          (cubit.state as WalletTopupMobileMoneyAwaiting).topup.topupId,
          'topup-2',
        );
        // Le timer de la session 2 est toujours actif : la réponse
        // obsolète n'a pas appelé stopPolling().
        expect(async.periodicTimerCount, 1);
        // Aucun event confirmed n'est parti pour la recharge abandonnée.
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyConfirmed,
            properties: any(named: 'properties'),
          ),
        );

        unawaited(cubit.close());
      });
    });

    test('IMPORTANT — garde par génération sur loadProviders : une réponse de '
        'catalogue en vol (numéro changé juste avant un « Payer ») ne doit '
        "jamais écraser l'Awaiting déjà en cours de sondage", () {
      fakeAsync((async) {
        final slowProviders = Completer<MobileMoneyProviderCatalog>();
        when(
          () => repo.topupProviders(phoneNumber),
        ).thenAnswer((_) => slowProviders.future);
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        // Le catalogue est demandé mais ne répond pas encore.
        unawaited(cubit.loadProviders(phoneNumber));
        async.flushMicrotasks();
        expect(cubit.state, isA<WalletTopupMobileMoneyProvidersLoading>());

        // Avant que la réponse n'arrive, la recharge est initiée (ex :
        // l'utilisateur avait déjà un opérateur détecté) et son sondage
        // démarre.
        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

        // La réponse tardive du catalogue arrive enfin : elle ne doit ni
        // écraser l'Awaiting, ni relancer quoi que ce soit.
        slowProviders.complete(catalog);
        async.flushMicrotasks();

        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
        expect(async.periodicTimerCount, 1);

        unawaited(cubit.close());
      });
    });

    test('reset() pendant Awaiting : arrête le sondage, revient à Idle', () {
      fakeAsync((async) {
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();
        expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

        cubit.reset();

        expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
        expect(async.periodicTimerCount, 0);

        unawaited(cubit.close());
      });
    });

    test('IMPORTANT — reset() pendant un sondage EN VOL : la réponse tardive '
        '(même CONFIRMED) ne ressuscite pas la recharge abandonnée, aucun '
        'event confirmed', () {
      fakeAsync((async) {
        final slowStatus = Completer<WalletTopupStatusModel>();
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) => slowStatus.future);

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();

        // Le tick fait partir la requête de statut, encore en vol quand
        // l'utilisateur abandonne (« Payer avec un autre numéro »).
        async.elapse(WalletTopupMobileMoneyCubit.pollInterval);

        cubit.reset();
        expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
        expect(async.periodicTimerCount, 0);

        // La réponse tardive arrive enfin, en CONFIRMED : elle ne doit
        // rien changer, l'état reste Idle.
        slowStatus.complete(statusFor('CONFIRMED'));
        async.flushMicrotasks();

        expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
        expect(async.periodicTimerCount, 0);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.walletTopupMobileMoneyConfirmed,
            properties: any(named: 'properties'),
          ),
        );

        unawaited(cubit.close());
      });
    });

    test('reset() après close() : sans effet, aucune exception', () {
      fakeAsync((async) {
        when(
          () => repo.topupStatus('topup-1'),
        ).thenAnswer((_) async => statusFor('PENDING'));

        final cubit = WalletTopupMobileMoneyCubit(
          repo,
          analytics,
          now: () => clock.now(),
        );

        unawaited(cubit.initiate(amount: 20000, phoneNumber: phoneNumber));
        async.flushMicrotasks();

        unawaited(cubit.close());
        expect(() => cubit.reset(), returnsNormally);
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}
