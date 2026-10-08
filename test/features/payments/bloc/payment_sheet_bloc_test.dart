import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show FailureCode, LocalizedErrorMessage, StripeException;
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
      'échec → failure transitoire (reason declined, providerMessage du gateway) puis ready ré-armé',
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
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.declined,
          providerMessage: 'refusé',
          ready: ready,
        ),
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
      'échec de confirmation → reason declined, providerMessage = message Stripe localisé, '
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
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.declined,
          providerMessage: 'carte refusée',
          ready: ready,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'PaymentConfirmationException() sans message → reason declined, '
      'providerMessage null (repli sur le libellé générique côté UI)',
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
        ).thenThrow(const PaymentConfirmationException());
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
          reason: PaymentSheetFailureReason.declined,
          ready: ready,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'erreur inattendue (non mappée par le gateway) → reason generic, '
      'jamais le toString brut ni un providerMessage',
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
          reason: PaymentSheetFailureReason.generic,
          ready: ready,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec réseau sur la clé éphémère → reason cardUnavailable '
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
          reason: PaymentSheetFailureReason.cardUnavailable,
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
          reason: PaymentSheetFailureReason.cardUnavailable,
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

  // Sentry FLUTTER-7S : un échec Stripe ne laissait aucune trace, seul le
  // message générique s'affichait.
  group('remontée des échecs Stripe', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: true,
    );
    late _RecordingSink sink;

    setUp(() => sink = _RecordingSink());

    PaymentSheetBloc buildReportingBloc() => PaymentSheetBloc(
      gateway: gateway,
      repository: repository,
      config: config,
      errorReporter: ErrorReportingService(sink),
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec du SDK → Sentry reçoit codes, type et message, l\'UI garde son '
      'message',
      build: () {
        when(() => gateway.confirmPayPal(any())).thenThrow(
          const PaymentConfirmationException.fromStripe(
            'Votre carte a été refusée.',
            stripeCode: 'Failed',
            stripeErrorCode: 'card_declined',
            declineCode: 'insufficient_funds',
            stripeErrorType: 'card_error',
            stripeMessage: 'Your card was declined.',
          ),
        );
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.paypal,
        ),
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.declined,
          providerMessage: 'Votre carte a été refusée.',
          ready: ready,
        ),
        ready,
      ],
      verify: (_) {
        expect(sink.contexts, hasLength(1));
        expect(sink.contexts.single, {
          'operation': 'payment.stripe_confirm',
          'error_type': 'PaymentConfirmationException',
          'feature': 'payments',
          'method': 'paypal',
          'stripe_code': 'Failed',
          'stripe_error_code': 'card_declined',
          'decline_code': 'insufficient_funds',
          'stripe_error_type': 'card_error',
          'stripe_message': 'Your card was declined.',
        });
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'annulation par l\'utilisateur → rien n\'est remonté',
      build: () {
        when(
          () => gateway.confirmPayPal(any()),
        ).thenThrow(const PaymentCancelledException());
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      verify: (_) => expect(sink.contexts, isEmpty),
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec hors SDK (sans codes Stripe) → rien n\'est remonté',
      build: () {
        when(
          () => gateway.confirmPayPal(any()),
        ).thenThrow(const PaymentConfirmationException('refusé'));
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      verify: (_) => expect(sink.contexts, isEmpty),
    );
  });

  // FLUTTER-CJ : toute erreur d'initPaymentSheet était classée « carte
  // refusée » et son texte technique affiché tel quel.
  group('classement des échecs Stripe (FLUTTER-CJ)', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: true,
    );
    late _RecordingSink sink;

    setUp(() => sink = _RecordingSink());

    PaymentSheetBloc buildReportingBloc() => PaymentSheetBloc(
      gateway: gateway,
      repository: repository,
      config: config,
      errorReporter: ErrorReportingService(sink),
    );

    const fragmentDestroyed = PaymentConfirmationException.fromStripe(
      null,
      stripeCode: 'Failed',
      stripeMessage: 'FragmentManager has been destroyed',
    );

    void stubCardFlow({Object? initError, Object? presentError}) {
      when(
        () => repository.createEphemeralKey(),
      ).thenAnswer((_) async => _ephemeralKey);
      final init = when(
        () => gateway.initPaymentSheet(
          clientSecret: any(named: 'clientSecret'),
          customerId: any(named: 'customerId'),
          customerEphemeralKeySecret: any(named: 'customerEphemeralKeySecret'),
        ),
      );
      if (initError != null) {
        init.thenThrow(initError);
      } else {
        init.thenAnswer((_) async {});
      }
      final present = when(() => gateway.presentPaymentSheet());
      if (presentError != null) {
        present.thenThrow(presentError);
      } else {
        present.thenAnswer((_) async {});
      }
    }

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec d\'initPaymentSheet → sheetUnavailable, sans message du SDK, '
      'jamais presentPaymentSheet, remonté en payment.stripe_init',
      build: () {
        stubCardFlow(initError: fragmentDestroyed);
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.sheetUnavailable,
          ready: ready,
        ),
        ready,
      ],
      verify: (_) {
        verifyNever(() => gateway.presentPaymentSheet());
        expect(sink.contexts.single['operation'], 'payment.stripe_init');
        expect(
          sink.contexts.single['stripe_message'],
          'FragmentManager has been destroyed',
        );
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'PayPal : erreur locale du SDK (sans type) → sheetUnavailable',
      build: () {
        when(() => gateway.confirmPayPal(any())).thenThrow(fragmentDestroyed);
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.paypal,
        ),
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.sheetUnavailable,
          ready: ready,
        ),
        ready,
      ],
      verify: (_) =>
          expect(sink.contexts.single['operation'], 'payment.stripe_confirm'),
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'erreur Stripe typée hors carte (api_error) après ouverture → generic',
      build: () {
        stubCardFlow(
          presentError: const PaymentConfirmationException.fromStripe(
            null,
            stripeCode: 'Failed',
            stripeErrorType: 'api_error',
            stripeMessage: 'An error occurred with our API.',
          ),
        );
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.generic,
          ready: ready,
        ),
        ready,
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'vrai refus carte (card_error) → declined avec le message du fournisseur',
      build: () {
        stubCardFlow(
          presentError: const PaymentConfirmationException.fromStripe(
            'Votre carte a été refusée.',
            stripeCode: 'Failed',
            stripeErrorType: 'card_error',
            declineCode: 'insufficient_funds',
          ),
        );
        return buildReportingBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetCardPressed()),
      expect: () => [
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
        const PaymentSheetFailure(
          reason: PaymentSheetFailureReason.declined,
          providerMessage: 'Votre carte a été refusée.',
          ready: ready,
        ),
        ready,
      ],
    );
  });

  group('mapStripeException', () {
    test('annulation → PaymentCancelledException', () {
      final mapped = mapStripeException(
        const StripeException(
          error: LocalizedErrorMessage(code: FailureCode.Canceled),
        ),
      );
      expect(mapped, isA<PaymentCancelledException>());
    });

    test('échec → message localisé affiché, codes du SDK conservés', () {
      final mapped = mapStripeException(
        const StripeException(
          error: LocalizedErrorMessage(
            code: FailureCode.Failed,
            localizedMessage: 'Votre carte a été refusée.',
            message: 'Your card was declined.',
            stripeErrorCode: 'card_declined',
            declineCode: 'generic_decline',
            type: 'card_error',
          ),
        ),
      );
      expect(
        mapped,
        isA<PaymentConfirmationException>()
            .having((e) => e.message, 'message', 'Votre carte a été refusée.')
            .having((e) => e.isFromStripe, 'isFromStripe', isTrue)
            .having((e) => e.stripeCode, 'stripeCode', 'Failed')
            .having((e) => e.stripeErrorCode, 'code', 'card_declined')
            .having((e) => e.declineCode, 'decline', 'generic_decline')
            .having((e) => e.stripeErrorType, 'type', 'card_error')
            .having(
              (e) => e.stripeMessage,
              'stripeMessage',
              'Your card was declined.',
            ),
      );
    });

    test('erreur locale du SDK (pas card_error) → aucun message montrable, '
        'texte brut gardé pour Sentry (FLUTTER-CJ)', () {
      final mapped = mapStripeException(
        const StripeException(
          error: LocalizedErrorMessage(
            code: FailureCode.Failed,
            localizedMessage: 'FragmentManager has been destroyed',
            message: 'FragmentManager has been destroyed',
          ),
        ),
      );
      expect(
        mapped,
        isA<PaymentConfirmationException>()
            .having((e) => e.message, 'message', isNull)
            .having((e) => e.isCardError, 'isCardError', isFalse)
            .having(
              (e) => e.stripeMessage,
              'stripeMessage',
              'FragmentManager has been destroyed',
            ),
      );
    });

    test('card_error sans message localisé → message brut', () {
      final mapped = mapStripeException(
        const StripeException(
          error: LocalizedErrorMessage(
            code: FailureCode.Failed,
            message: 'Your card was declined.',
            type: 'card_error',
          ),
        ),
      );
      expect(
        mapped,
        isA<PaymentConfirmationException>().having(
          (e) => e.message,
          'message',
          'Your card was declined.',
        ),
      );
    });

    test('sans message localisé → message brut, sinon null', () {
      final mapped = mapStripeException(
        const StripeException(
          error: LocalizedErrorMessage(code: FailureCode.Timeout),
        ),
      );
      expect(
        mapped,
        isA<PaymentConfirmationException>()
            .having((e) => e.message, 'message', isNull)
            .having((e) => e.stripeCode, 'stripeCode', 'Timeout'),
      );
    });
  });
}

class _RecordingSink implements ErrorReportingSink {
  final contexts = <Map<String, Object>>[];

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    contexts.add(context);
  }
}
