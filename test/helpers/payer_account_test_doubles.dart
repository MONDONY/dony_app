import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:mocktail/mocktail.dart';

/// Doublure du composant « compte qui paie » : l'état est piloté par le test,
/// les gestes sont vérifiés par `verify`.
class MockPayerAccountCubit extends MockCubit<PayerAccountState>
    implements PayerAccountCubit {}

const kOrangeCiv = MobileMoneyOperator(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
  minAmount: 100,
  maxAmount: 500000,
);

const kMtnCiv = MobileMoneyOperator(
  code: 'MTN_MOMO_CIV',
  label: 'MTN MoMo',
  brand: 'MTN',
);

const kCoteDIvoire = MobileMoneyCountry(
  country: 'CI',
  currency: 'XOF',
  operators: [kOrangeCiv, kMtnCiv],
);

const kSenegal = MobileMoneyCountry(
  country: 'SN',
  currency: 'XOF',
  operators: [
    MobileMoneyOperator(
      code: 'ORANGE_SEN',
      label: 'Orange Money',
      brand: 'ORANGE',
    ),
  ],
);

/// Catalogue de test : Côte d'Ivoire et Sénégal servis, Mali « Bientôt ».
const kPayerCountries = MobileMoneyCountries(
  available: [kCoteDIvoire, kSenegal],
  upcoming: ['ML'],
);

const kPayerReady = PayerAccountState(
  status: PayerAccountStatus.ready,
  countries: kPayerCountries,
);

/// Pays, opérateur et numéro complets, numéro reconnu par pawaPay.
const kPayerRecognized = PayerAccountState(
  status: PayerAccountStatus.ready,
  countries: kPayerCountries,
  country: kCoteDIvoire,
  operator: kOrangeCiv,
  localNumber: '0748840856',
  e164: '+2250748840856',
  recognition: RecognitionStatus.recognized,
);

/// Branche [cubit] sur [initial], puis sur les états poussés dans le
/// contrôleur rendu (à fermer par le test, ou via `addTearDown`).
StreamController<PayerAccountState> stubPayerAccount(
  MockPayerAccountCubit cubit,
  PayerAccountState initial,
) {
  final controller = StreamController<PayerAccountState>.broadcast();
  whenListen(cubit, controller.stream, initialState: initial);
  when(() => cubit.load()).thenAnswer((_) async {});
  when(() => cubit.retryRecognition()).thenAnswer((_) async {});
  when(() => cubit.rememberSuccess()).thenAnswer((_) async {});
  return controller;
}
