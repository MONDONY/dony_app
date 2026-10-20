import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:flutter_test/flutter_test.dart';

MobileMoneyPayoutAccount _account(String provider, String currency) =>
    MobileMoneyPayoutAccount(
      id: provider,
      provider: provider,
      providerLabel: provider,
      brand: MobileMoneyPayoutAccount.brandOf(provider),
      country: 'CI',
      currency: currency,
      msisdnMasked: '+225 •• 36',
    );

void main() {
  final two = MobileMoneyPayoutAccounts(
    accounts: [
      _account('ORANGE_CIV', 'XOF'),
      _account('ORANGE_SEN', 'XOF'),
      _account('MTN_CMR', 'XAF'),
    ],
  );
  const none = MobileMoneyPayoutAccounts();

  group('mobileMoneyAccountActiveFrom', () {
    test('au moins un compte : actif', () {
      expect(
        mobileMoneyAccountActiveFrom(MobileMoneyAccountLoaded(two)),
        isTrue,
      );
    });

    test('liste vide : inactif', () {
      expect(
        mobileMoneyAccountActiveFrom(const MobileMoneyAccountLoaded(none)),
        isFalse,
      );
    });

    test('liste pas encore lue : inactif', () {
      expect(
        mobileMoneyAccountActiveFrom(const MobileMoneyAccountInitial()),
        isFalse,
      );
      expect(
        mobileMoneyAccountActiveFrom(const MobileMoneyAccountLoading()),
        isFalse,
      );
      expect(
        mobileMoneyAccountActiveFrom(
          const MobileMoneyAccountError(NetworkException('offline')),
        ),
        isFalse,
      );
    });

    test('les états d\'action portent la liste', () {
      expect(
        mobileMoneyAccountActiveFrom(
          MobileMoneyAccountActionDone(two, MobileMoneyAccountAction.added),
        ),
        isTrue,
      );
      expect(
        mobileMoneyAccountActiveFrom(
          MobileMoneyAccountActionFailed(two, Exception('x')),
        ),
        isTrue,
      );
    });
  });

  group('mobileMoneyAccountCurrenciesFrom', () {
    test('devises des comptes, sans doublon', () {
      expect(mobileMoneyAccountCurrenciesFrom(MobileMoneyAccountLoaded(two)), {
        'XOF',
        'XAF',
      });
    });

    test('devise du trajet couverte = appartenance à l\'ensemble', () {
      final currencies = mobileMoneyAccountCurrenciesFrom(
        MobileMoneyAccountLoaded(
          MobileMoneyPayoutAccounts(accounts: [_account('ORANGE_CIV', 'XOF')]),
        ),
      );
      expect(currencies.contains('XOF'), isTrue);
      expect(currencies.contains('XAF'), isFalse);
    });

    test('compte sans devise ignoré', () {
      expect(
        mobileMoneyAccountCurrenciesFrom(
          MobileMoneyAccountLoaded(
            MobileMoneyPayoutAccounts(accounts: [_account('ORANGE_CIV', '')]),
          ),
        ),
        isEmpty,
      );
    });

    test('aucune liste connue : ensemble vide', () {
      expect(
        mobileMoneyAccountCurrenciesFrom(const MobileMoneyAccountInitial()),
        isEmpty,
      );
      expect(
        mobileMoneyAccountCurrenciesFrom(const MobileMoneyAccountLoaded(none)),
        isEmpty,
      );
    });
  });
}
