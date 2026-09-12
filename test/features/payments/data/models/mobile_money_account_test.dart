import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileMoneyAccount', () {
    group('fromJson', () {
      test('parses un compte actif avec tous les champs', () {
        final json = {
          'status': 'ACTIVE',
          'msisdnMasked': '+221 •••• 67',
          'provider': 'ORANGE_SEN',
          'providerLabel': 'Orange Money',
          'country': 'SN',
          'currency': 'XOF',
          'verifiedAt': '2026-09-08T06:00:00Z',
        };

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.status, MobileMoneyAccountStatus.active);
        expect(account.msisdnMasked, '+221 •••• 67');
        expect(account.providerLabel, 'Orange Money');
        expect(account.country, 'SN');
        expect(account.currency, 'XOF');
      });

      test('parses le statut NOT_CONFIGURED', () {
        final json = {'status': 'NOT_CONFIGURED'};

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.status, MobileMoneyAccountStatus.notConfigured);
      });

      test('parses le statut DISABLED', () {
        final json = {'status': 'DISABLED'};

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.status, MobileMoneyAccountStatus.disabled);
      });

      test('replie sur notConfigured pour un statut inconnu', () {
        final json = {'status': 'SOMETHING_NEW'};

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.status, MobileMoneyAccountStatus.notConfigured);
      });

      test('replie sur notConfigured quand le statut est absent', () {
        final json = <String, dynamic>{};

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.status, MobileMoneyAccountStatus.notConfigured);
      });

      test('les champs facultatifs sont nuls quand ils sont absents', () {
        final json = {'status': 'ACTIVE'};

        final account = MobileMoneyAccount.fromJson(json);

        expect(account.msisdnMasked, isNull);
        expect(account.providerLabel, isNull);
        expect(account.country, isNull);
        expect(account.currency, isNull);
      });
    });

    group('isActive', () {
      test('vrai quand le statut est active', () {
        const account = MobileMoneyAccount(
          status: MobileMoneyAccountStatus.active,
        );

        expect(account.isActive, isTrue);
      });

      test('faux quand le statut est disabled', () {
        const account = MobileMoneyAccount(
          status: MobileMoneyAccountStatus.disabled,
        );

        expect(account.isActive, isFalse);
      });

      test('faux quand le statut est notConfigured', () {
        const account = MobileMoneyAccount(
          status: MobileMoneyAccountStatus.notConfigured,
        );

        expect(account.isActive, isFalse);
      });
    });

    group('Equatable', () {
      test('deux comptes avec les memes donnees sont egaux', () {
        const a = MobileMoneyAccount(
          status: MobileMoneyAccountStatus.active,
          msisdnMasked: '+221 •••• 67',
          providerLabel: 'Orange Money',
          country: 'SN',
          currency: 'XOF',
        );
        const b = MobileMoneyAccount(
          status: MobileMoneyAccountStatus.active,
          msisdnMasked: '+221 •••• 67',
          providerLabel: 'Orange Money',
          country: 'SN',
          currency: 'XOF',
        );

        expect(a, equals(b));
      });

      test('deux comptes avec un statut different ne sont pas egaux', () {
        const a = MobileMoneyAccount(status: MobileMoneyAccountStatus.active);
        const b = MobileMoneyAccount(status: MobileMoneyAccountStatus.disabled);

        expect(a, isNot(equals(b)));
      });
    });

    group('providers', () {
      test('lit la liste des réseaux acceptés', () {
        final account = MobileMoneyAccount.fromJson(const {
          'status': 'ACTIVE',
          'msisdnMasked': '+225 •••• 36',
          'provider': 'ORANGE_CIV',
          'providerLabel': 'Orange Money',
          'providers': [
            {'code': 'ORANGE_CIV', 'label': 'Orange Money'},
            {'code': 'WAVE_CIV', 'label': 'Wave'},
          ],
        });
        expect(account.provider, 'ORANGE_CIV');
        expect(account.providers.map((p) => p.label), ['Orange Money', 'Wave']);
      });

      test(
        'providers explicitement vide fait foi, même avec un provider hérité',
        () {
          final account = MobileMoneyAccount.fromJson(const {
            'providers': [],
            'provider': 'ORANGE_CIV',
            'providerLabel': 'Orange Money',
          });
          expect(account.providers, isEmpty);
          expect(account.provider, 'ORANGE_CIV');
        },
      );

      test(
        'ancien contrat sans liste : repli sur provider et providerLabel',
        () {
          final account = MobileMoneyAccount.fromJson(const {
            'status': 'ACTIVE',
            'provider': 'ORANGE_CIV',
            'providerLabel': 'Orange Money',
          });
          expect(account.providers.single.code, 'ORANGE_CIV');
          expect(account.providers.single.label, 'Orange Money');
        },
      );

      test('compte non configuré : aucune liste', () {
        final account = MobileMoneyAccount.fromJson(const {
          'status': 'NOT_CONFIGURED',
        });
        expect(account.providers, isEmpty);
        expect(account.provider, isNull);
      });
    });
  });
}
