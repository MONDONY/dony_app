import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fullJson = {
    'id': 'acc-1',
    'provider': 'ORANGE_CIV',
    'providerLabel': 'Orange Money',
    'brand': 'ORANGE',
    'country': 'CI',
    'currency': 'XOF',
    'msisdnMasked': '+225 •••• 36',
    'verifiedAt': '2026-10-19T10:00:00Z',
    'pendingPayouts': 2,
  };

  group('MobileMoneyPayoutAccount.fromJson', () {
    test('parse tous les champs', () {
      final a = MobileMoneyPayoutAccount.fromJson(fullJson);

      expect(a.id, 'acc-1');
      expect(a.provider, 'ORANGE_CIV');
      expect(a.providerLabel, 'Orange Money');
      expect(a.brand, 'ORANGE');
      expect(a.country, 'CI');
      expect(a.currency, 'XOF');
      expect(a.msisdnMasked, '+225 •••• 36');
      expect(a.pendingPayouts, 2);
      expect(a.isLocked, isTrue);
    });

    test('valeurs par défaut : marque et libellé déduits du code', () {
      final a = MobileMoneyPayoutAccount.fromJson(const {
        'id': 'acc-2',
        'provider': 'wave_sen',
      });

      expect(a.providerLabel, 'wave_sen');
      expect(a.brand, 'WAVE');
      expect(a.country, '');
      expect(a.currency, '');
      expect(a.msisdnMasked, '');
      expect(a.pendingPayouts, 0);
      expect(a.isLocked, isFalse);
    });

    test('code absent : champs vides, jamais de crash', () {
      final a = MobileMoneyPayoutAccount.fromJson(const {'id': 'acc-3'});

      expect(a.provider, '');
      expect(a.brand, '');
    });

    test('code sans tiret bas : la marque est le code', () {
      expect(MobileMoneyPayoutAccount.brandOf('mtn'), 'MTN');
    });

    test('pendingPayouts décimal accepté', () {
      final a = MobileMoneyPayoutAccount.fromJson({
        ...fullJson,
        'pendingPayouts': 1.0,
      });

      expect(a.pendingPayouts, 1);
    });

    test('égalité par valeur', () {
      expect(
        MobileMoneyPayoutAccount.fromJson(fullJson),
        MobileMoneyPayoutAccount.fromJson(fullJson),
      );
    });
  });

  group('MobileMoneyPayoutAccounts.fromJson', () {
    test('parse comptes et réseaux suggérés', () {
      final result = MobileMoneyPayoutAccounts.fromJson({
        'accounts': [fullJson],
        'suggestedProviders': const [
          {'code': 'MTN_MOMO_CIV', 'label': 'MTN MoMo'},
        ],
      });

      expect(result.accounts, hasLength(1));
      expect(result.accounts.single.id, 'acc-1');
      expect(result.suggested.single.code, 'MTN_MOMO_CIV');
      expect(result.suggested.single.label, 'MTN MoMo');
      expect(result.legacy, isFalse);
    });

    test('clés absentes ou mal typées : listes vides', () {
      expect(MobileMoneyPayoutAccounts.fromJson(const {}).accounts, isEmpty);
      final bad = MobileMoneyPayoutAccounts.fromJson(const {
        'accounts': 'x',
        'suggestedProviders': 3,
      });
      expect(bad.accounts, isEmpty);
      expect(bad.suggested, isEmpty);
    });

    test('ignore les éléments qui ne sont pas des objets', () {
      final result = MobileMoneyPayoutAccounts.fromJson({
        'accounts': [fullJson, 'x', 1],
        'suggestedProviders': const ['y'],
      });

      expect(result.accounts, hasLength(1));
      expect(result.suggested, isEmpty);
    });
  });
}
