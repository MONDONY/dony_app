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

  WalletTopupStatusModel statusFor(String status, {String? failureReason}) =>
      WalletTopupStatusModel(
        topupId: 'topup-1',
        status: status,
        amount: 20000,
        currency: 'XOF',
        provider: 'ORANGE_SEN',
        providerLabel: 'Orange Money',
        msisdnMasked: '+221 ** ** 12 34',
        failureReason: failureReason,
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
            properties: {'provider': 'ORANGE_SEN', 'currency': 'XOF'},
          ),
        ).called(1);
      },
    );

    blocTest<WalletTopupMobileMoneyCubit, WalletTopupMobileMoneyState>(
      'initiate() erreur réseau : état Error, aucun event analytics',
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
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );
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
            (s) => s.message,
            'message',
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

        unawaited(cubit.close());
      });
    });

    test(
      'FAILED sans motif serveur -> message générique (jamais de tiret cadratin)',
      () {
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

          final state = cubit.state;
          expect(state, isA<WalletTopupMobileMoneyFailed>());
          final message = (state as WalletTopupMobileMoneyFailed).message;
          expect(message, isNotEmpty);
          expect(message.contains('—'), isFalse);

          unawaited(cubit.close());
        });
      },
    );

    test('expiration après 15 min sans confirmation -> Failed avec le message '
        "d'expiration", () {
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
          WalletTopupMobileMoneyCubit.expiry + const Duration(seconds: 1),
        );

        final state = cubit.state;
        expect(state, isA<WalletTopupMobileMoneyFailed>());
        final message = (state as WalletTopupMobileMoneyFailed).message;
        expect(message, isNotEmpty);
        expect(message.contains('—'), isFalse);
        expect(async.periodicTimerCount, 0);

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
  });
}
