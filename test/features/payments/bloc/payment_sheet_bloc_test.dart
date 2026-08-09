import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentGateway extends Mock implements PaymentGateway {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

const _ephemeralKey = EphemeralKeyModel(
  ephemeralKeySecret: 'ek_test_secret',
  customerId: 'cus_123',
);

void main() {
  late MockPaymentGateway gateway;
  late MockPaymentRepository repository;

  const config = PaymentSheetConfig(
    clientSecret: 'pi_123_secret_abc',
    amountEur: 56.0,
    paymentMethodTypes: ['card', 'paypal'],
  );

  setUp(() {
    gateway = MockPaymentGateway();
    repository = MockPaymentRepository();
  });

  PaymentSheetBloc buildBloc({PaymentSheetConfig cfg = config}) =>
      PaymentSheetBloc(gateway: gateway, repository: repository, config: cfg);

  void stubResolution({bool wallet = false}) {
    when(
      () => gateway.isPlatformPaySupported(),
    ).thenAnswer((_) async => wallet);
  }

  group('paymentIntentId', () {
    test('dérivé du clientSecret', () {
      expect(config.paymentIntentId, 'pi_123');
    });
  });

  group('PaymentSheetStarted — résolution des moyens disponibles', () {
    // Les 4 combinaisons wallet × paypal.
    for (final wallet in [true, false]) {
      for (final paypal in [true, false]) {
        blocTest<PaymentSheetBloc, PaymentSheetState>(
          'wallet=$wallet paypal=$paypal',
          build: () {
            stubResolution(wallet: wallet);
            return buildBloc(
              cfg: PaymentSheetConfig(
                clientSecret: 'pi_123_secret_abc',
                amountEur: 56.0,
                paymentMethodTypes: paypal
                    ? const ['card', 'paypal']
                    : const ['card'],
              ),
            );
          },
          act: (bloc) => bloc.add(const PaymentSheetStarted()),
          expect: () => [
            PaymentSheetResolved(
              walletAvailable: wallet,
              paypalAvailable: paypal,
            ),
          ],
        );
      }
    }

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec isPlatformPaySupported → wallet indisponible, sheet fonctionnelle',
      build: () {
        when(
          () => gateway.isPlatformPaySupported(),
        ).thenThrow(Exception('platform'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PaymentSheetStarted()),
      expect: () => [
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: true,
        ),
      ],
    );
  });

  group('Wallet', () {
    const ready = PaymentSheetResolved(
      walletAvailable: true,
      paypalAvailable: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'succès → processing puis success',
      build: () {
        when(
          () => gateway.confirmPlatformPay(
            clientSecret: any(named: 'clientSecret'),
            amountEur: any(named: 'amountEur'),
          ),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetWalletPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.wallet,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.wallet),
      ],
      verify: (_) {
        verify(
          () => gateway.confirmPlatformPay(
            clientSecret: 'pi_123_secret_abc',
            amountEur: 56.0,
          ),
        ).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'propage la devise CAD au paiement wallet',
      build: () {
        when(
          () => gateway.confirmPlatformPay(
            clientSecret: any(named: 'clientSecret'),
            amountEur: any(named: 'amountEur'),
            currencyCode: any(named: 'currencyCode'),
          ),
        ).thenAnswer((_) async {});
        return buildBloc(
          cfg: const PaymentSheetConfig(
            clientSecret: 'pi_123_secret_abc',
            amountEur: 56.0,
            currencyCode: 'CAD',
            paymentMethodTypes: ['card'],
          ),
        );
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetWalletPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.wallet,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.wallet),
      ],
      verify: (_) {
        verify(
          () => gateway.confirmPlatformPay(
            clientSecret: 'pi_123_secret_abc',
            amountEur: 56.0,
            currencyCode: 'CAD',
          ),
        ).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'annulation → retour ready sans failure',
      build: () {
        when(
          () => gateway.confirmPlatformPay(
            clientSecret: any(named: 'clientSecret'),
            amountEur: any(named: 'amountEur'),
          ),
        ).thenThrow(const PaymentCancelledException());
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetWalletPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.wallet,
        ),
        ready,
      ],
    );
  });

  group('PayPal', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec → failure transitoire puis ready ré-armé',
      build: () {
        when(
          () => gateway.confirmPayPal(any()),
        ).thenThrow(const PaymentConfirmationException('refusé'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.paypal,
        ),
        const PaymentSheetFailure(message: 'refusé', ready: ready),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'succès → success',
      build: () {
        when(() => gateway.confirmPayPal(any())).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.paypal,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.paypal),
      ],
      verify: (_) {
        verify(() => gateway.confirmPayPal('pi_123_secret_abc')).called(1);
      },
    );
  });

  group('Carte — PaymentSheet native Stripe', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: false,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'tap → clé éphémère + initPaymentSheet + presentPaymentSheet → success',
      build: () {
        when(
          () => repository.createEphemeralKey(),
        ).thenAnswer((_) async => _ephemeralKey);
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.presentPaymentSheet()).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.card),
      ],
      verify: (_) {
        verify(() => repository.createEphemeralKey()).called(1);
        verify(
          () => gateway.initPaymentSheet(
            clientSecret: 'pi_123_secret_abc',
            customerId: 'cus_123',
            customerEphemeralKeySecret: 'ek_test_secret',
          ),
        ).called(1);
        verify(() => gateway.presentPaymentSheet()).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'annulation de la PaymentSheet native → retour ready sans erreur',
      build: () {
        when(
          () => repository.createEphemeralKey(),
        ).thenAnswer((_) async => _ephemeralKey);
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(
          () => gateway.presentPaymentSheet(),
        ).thenThrow(const PaymentCancelledException());
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec de confirmation → le message Stripe localisé remonte tel quel, '
      'comme pour wallet/PayPal, puis ready ré-armé',
      build: () {
        when(
          () => repository.createEphemeralKey(),
        ).thenAnswer((_) async => _ephemeralKey);
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(
          () => gateway.presentPaymentSheet(),
        ).thenThrow(const PaymentConfirmationException('carte refusée'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(message: 'carte refusée', ready: ready),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'erreur inattendue (non mappée par le gateway) → message générique, '
      'jamais le toString brut',
      build: () {
        when(
          () => repository.createEphemeralKey(),
        ).thenAnswer((_) async => _ephemeralKey);
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(
          () => gateway.presentPaymentSheet(),
        ).thenThrow(StateError('bug interne'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          message: PaymentSheetBloc.genericFailureMessage,
          ready: ready,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec réseau sur la clé éphémère → failure avec message carte lisible '
      'puis ready ré-armé (jamais le toString brut)',
      build: () {
        when(
          () => repository.createEphemeralKey(),
        ).thenThrow(Exception('réseau'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          message: PaymentSheetBloc.cardUnavailableMessage,
          ready: ready,
        ),
        ready,
      ],
      verify: (_) {
        verifyNever(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        );
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'double tap pendant le vol → une seule requête ephemeral-key',
      build: () {
        when(() => repository.createEphemeralKey()).thenAnswer((_) async {
          // Laisse le second événement se glisser pendant le premier vol.
          await Future<void>.delayed(Duration.zero);
          return _ephemeralKey;
        });
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.presentPaymentSheet()).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc
        ..add(const PaymentSheetCardPressed())
        ..add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.card),
      ],
      verify: (_) {
        verify(() => repository.createEphemeralKey()).called(1);
        verify(() => gateway.presentPaymentSheet()).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'annulation puis nouveau tap → clé éphémère mémoïsée (un seul fetch)',
      build: () {
        var presentCalls = 0;
        when(
          () => repository.createEphemeralKey(),
        ).thenAnswer((_) async => _ephemeralKey);
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.presentPaymentSheet()).thenAnswer((_) async {
          presentCalls++;
          if (presentCalls == 1) throw const PaymentCancelledException();
        });
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) async {
        bloc.add(const PaymentSheetCardPressed());
        await Future<void>.delayed(Duration.zero); // laisse la 1re chaîne finir
        bloc.add(const PaymentSheetCardPressed());
      },
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        ready, // annulation silencieuse
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.card),
      ],
      verify: (_) {
        verify(() => repository.createEphemeralKey()).called(1);
        verify(() => gateway.presentPaymentSheet()).called(2);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec de la clé éphémère non mémoïsé → nouveau tap re-tente le fetch',
      build: () {
        var keyCalls = 0;
        when(() => repository.createEphemeralKey()).thenAnswer((_) async {
          keyCalls++;
          if (keyCalls == 1) throw Exception('réseau');
          return _ephemeralKey;
        });
        when(
          () => gateway.initPaymentSheet(
            clientSecret: any(named: 'clientSecret'),
            customerId: any(named: 'customerId'),
            customerEphemeralKeySecret: any(
              named: 'customerEphemeralKeySecret',
            ),
          ),
        ).thenAnswer((_) async {});
        when(() => gateway.presentPaymentSheet()).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) async {
        bloc.add(const PaymentSheetCardPressed());
        await Future<void>.delayed(Duration.zero); // laisse la 1re chaîne finir
        bloc.add(const PaymentSheetCardPressed());
      },
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          message: PaymentSheetBloc.cardUnavailableMessage,
          ready: ready,
        ),
        ready,
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.card),
      ],
      verify: (_) {
        verify(() => repository.createEphemeralKey()).called(2);
      },
    );
  });
}
