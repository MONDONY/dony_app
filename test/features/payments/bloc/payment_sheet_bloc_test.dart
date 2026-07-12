import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/saved_card_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentGateway extends Mock implements PaymentGateway {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

const _visa = SavedCardModel(
  id: 'pm_1',
  brand: 'visa',
  last4: '4242',
  expMonth: 8,
  expYear: 2027,
);

const _mastercard = SavedCardModel(
  id: 'pm_2',
  brand: 'mastercard',
  last4: '4444',
  expMonth: 1,
  expYear: 2028,
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
      PaymentSheetBloc(
        gateway: gateway,
        repository: repository,
        config: cfg,
      );

  void stubResolution({
    bool wallet = false,
    List<SavedCardModel> cards = const [],
  }) {
    when(() => gateway.isPlatformPaySupported())
        .thenAnswer((_) async => wallet);
    when(() => repository.listSavedPaymentMethods())
        .thenAnswer((_) async => cards);
  }

  group('paymentIntentId', () {
    test('dérivé du clientSecret', () {
      expect(config.paymentIntentId, 'pi_123');
    });
  });

  group('PaymentSheetStarted — résolution des moyens disponibles', () {
    // Les 8 combinaisons wallet × paypal × cartes.
    for (final wallet in [true, false]) {
      for (final paypal in [true, false]) {
        for (final hasCards in [true, false]) {
          blocTest<PaymentSheetBloc, PaymentSheetState>(
            'wallet=$wallet paypal=$paypal cartes=$hasCards',
            build: () {
              stubResolution(
                wallet: wallet,
                cards: hasCards ? [_visa] : const [],
              );
              return buildBloc(
                cfg: PaymentSheetConfig(
                  clientSecret: 'pi_123_secret_abc',
                  amountEur: 56.0,
                  paymentMethodTypes:
                      paypal ? const ['card', 'paypal'] : const ['card'],
                ),
              );
            },
            act: (bloc) => bloc.add(const PaymentSheetStarted()),
            expect: () => [
              PaymentSheetResolved(
                walletAvailable: wallet,
                paypalAvailable: paypal,
                savedCards: hasCards ? const [_visa] : const [],
                saveCard: true,
              ),
            ],
          );
        }
      }
    }

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec réseau payment-methods → sheet fonctionnelle avec cartes vides',
      build: () {
        when(() => gateway.isPlatformPaySupported())
            .thenAnswer((_) async => true);
        when(() => repository.listSavedPaymentMethods())
            .thenThrow(Exception('réseau'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PaymentSheetStarted()),
      expect: () => [
        const PaymentSheetResolved(
          walletAvailable: true,
          paypalAvailable: true,
          savedCards: [],
          saveCard: true,
        ),
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec isPlatformPaySupported → wallet indisponible, sheet fonctionnelle',
      build: () {
        when(() => gateway.isPlatformPaySupported())
            .thenThrow(Exception('platform'));
        when(() => repository.listSavedPaymentMethods())
            .thenAnswer((_) async => const [_visa]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PaymentSheetStarted()),
      expect: () => [
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: true,
          savedCards: [_visa],
          saveCard: true,
        ),
      ],
    );
  });

  group('Wallet', () {
    const ready = PaymentSheetResolved(
      walletAvailable: true,
      paypalAvailable: true,
      savedCards: [],
      saveCard: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'succès → processing puis success',
      build: () {
        when(() => gateway.confirmPlatformPay(
              clientSecret: any(named: 'clientSecret'),
              amountEur: any(named: 'amountEur'),
            )).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetWalletPressed()),
      expect: () => [
        const PaymentSheetProcessing(
            ready: ready, method: PaymentMethodKind.wallet),
        const PaymentSheetSuccess(method: PaymentMethodKind.wallet),
      ],
      verify: (_) {
        verify(() => gateway.confirmPlatformPay(
              clientSecret: 'pi_123_secret_abc',
              amountEur: 56.0,
            )).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'annulation → retour ready sans failure',
      build: () {
        when(() => gateway.confirmPlatformPay(
              clientSecret: any(named: 'clientSecret'),
              amountEur: any(named: 'amountEur'),
            )).thenThrow(const PaymentCancelledException());
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetWalletPressed()),
      expect: () => [
        const PaymentSheetProcessing(
            ready: ready, method: PaymentMethodKind.wallet),
        ready,
      ],
    );
  });

  group('PayPal', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: true,
      savedCards: [],
      saveCard: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec → failure transitoire puis ready ré-armé',
      build: () {
        when(() => gateway.confirmPayPal(any()))
            .thenThrow(const PaymentConfirmationException('refusé'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPalPressed()),
      expect: () => [
        const PaymentSheetProcessing(
            ready: ready, method: PaymentMethodKind.paypal),
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
            ready: ready, method: PaymentMethodKind.paypal),
        const PaymentSheetSuccess(method: PaymentMethodKind.paypal),
      ],
      verify: (_) {
        verify(() => gateway.confirmPayPal('pi_123_secret_abc')).called(1);
      },
    );
  });

  group('Cartes', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: false,
      savedCards: [_visa, _mastercard],
      saveCard: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'sélection carte enregistrée → ready avec choix',
      build: buildBloc,
      seed: () => ready,
      act: (bloc) =>
          bloc.add(const PaymentSheetCardChoiceChanged(SavedCardChoice(_visa))),
      expect: () => [
        ready.copyWith(cardChoice: const SavedCardChoice(_visa)),
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'payer avec carte enregistrée → confirmWithSavedCard',
      build: () {
        when(() => gateway.confirmWithSavedCard(
              clientSecret: any(named: 'clientSecret'),
              paymentMethodId: any(named: 'paymentMethodId'),
            )).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready.copyWith(cardChoice: const SavedCardChoice(_visa)),
      act: (bloc) => bloc.add(const PaymentSheetPayPressed()),
      expect: () => [
        PaymentSheetProcessing(
          ready: ready.copyWith(cardChoice: const SavedCardChoice(_visa)),
          method: PaymentMethodKind.savedCard,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.savedCard),
      ],
      verify: (_) {
        verify(() => gateway.confirmWithSavedCard(
              clientSecret: 'pi_123_secret_abc',
              paymentMethodId: 'pm_1',
            )).called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'payer avec nouvelle carte → confirmWithNewCard',
      build: () {
        when(() => gateway.confirmWithNewCard(any())).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready.copyWith(cardChoice: const NewCardChoice()),
      act: (bloc) => bloc.add(const PaymentSheetPayPressed()),
      expect: () => [
        PaymentSheetProcessing(
          ready: ready.copyWith(cardChoice: const NewCardChoice()),
          method: PaymentMethodKind.newCard,
        ),
        const PaymentSheetSuccess(method: PaymentMethodKind.newCard),
      ],
      verify: (_) {
        verify(() => gateway.confirmWithNewCard('pi_123_secret_abc'))
            .called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'payer sans choix de carte → rien ne se passe',
      build: buildBloc,
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetPayPressed()),
      expect: () => const <PaymentSheetState>[],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec carte → failure transitoire puis ready ré-armé (choix conservé)',
      build: () {
        when(() => gateway.confirmWithNewCard(any()))
            .thenThrow(const PaymentConfirmationException('carte refusée'));
        return buildBloc();
      },
      seed: () => ready.copyWith(cardChoice: const NewCardChoice()),
      act: (bloc) => bloc.add(const PaymentSheetPayPressed()),
      expect: () => [
        PaymentSheetProcessing(
          ready: ready.copyWith(cardChoice: const NewCardChoice()),
          method: PaymentMethodKind.newCard,
        ),
        PaymentSheetFailure(
          message: 'carte refusée',
          ready: ready.copyWith(cardChoice: const NewCardChoice()),
        ),
        ready.copyWith(cardChoice: const NewCardChoice()),
      ],
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'retour à la vue principale → efface le choix de carte',
      build: buildBloc,
      seed: () => ready.copyWith(cardChoice: const NewCardChoice()),
      act: (bloc) => bloc.add(const PaymentSheetBackToMainPressed()),
      expect: () => [ready],
    );
  });

  group('Toggle « Enregistrer cette carte »', () {
    const ready = PaymentSheetResolved(
      walletAvailable: false,
      paypalAvailable: false,
      savedCards: [],
      saveCard: true,
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'décocher → PATCH save=false + état mis à jour',
      build: () {
        when(() => repository.updateSavePaymentMethod(any(), any()))
            .thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetSaveCardToggled(false)),
      expect: () => [ready.copyWith(saveCard: false)],
      verify: (_) {
        verify(() => repository.updateSavePaymentMethod('pi_123', false))
            .called(1);
      },
    );

    blocTest<PaymentSheetBloc, PaymentSheetState>(
      'échec du PATCH → non bloquant, état quand même mis à jour',
      build: () {
        when(() => repository.updateSavePaymentMethod(any(), any()))
            .thenThrow(Exception('réseau'));
        return buildBloc();
      },
      seed: () => ready,
      act: (bloc) => bloc.add(const PaymentSheetSaveCardToggled(false)),
      expect: () => [ready.copyWith(saveCard: false)],
    );
  });
}
