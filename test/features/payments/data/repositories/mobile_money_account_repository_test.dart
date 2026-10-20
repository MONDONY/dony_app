import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyAccountRemoteDatasource extends Mock
    implements MobileMoneyAccountRemoteDatasource {}

void main() {
  late MockMobileMoneyAccountRemoteDatasource mockDs;
  late MobileMoneyAccountRepository repository;

  const disabledAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.disabled,
  );

  setUp(() {
    mockDs = MockMobileMoneyAccountRemoteDatasource();
    repository = MobileMoneyAccountRepository(mockDs);
  });

  group('comptes de versement', () {
    const orange = MobileMoneyPayoutAccount(
      id: 'acc-1',
      provider: 'ORANGE_CIV',
      providerLabel: 'Orange Money',
      brand: 'ORANGE',
      country: 'CI',
      currency: 'XOF',
      msisdnMasked: '+225 •••• 36',
    );
    const newContract = MobileMoneyPayoutAccounts(accounts: [orange]);

    DioException notFound() => DioException(
      requestOptions: RequestOptions(path: '/x'),
      error: const NotFoundException(),
    );

    const legacyActive = MobileMoneyAccount(
      status: MobileMoneyAccountStatus.active,
      msisdnMasked: '+221 •••• 67',
      provider: 'ORANGE_SEN',
      providerLabel: 'Orange Money',
      country: 'SN',
      currency: 'XOF',
    );

    /// Fait basculer le repository en repli (404 sur /accounts).
    Future<void> goLegacy(MobileMoneyAccount legacy) async {
      when(() => mockDs.accounts()).thenAnswer((_) => Future.error(notFound()));
      when(() => mockDs.get()).thenAnswer((_) async => legacy);
      await repository.accounts();
    }

    test('nouveau contrat : renvoie la réponse du datasource', () async {
      when(() => mockDs.accounts()).thenAnswer((_) async => newContract);

      final result = await repository.accounts();

      expect(result, newContract);
      expect(result.legacy, isFalse);
      verifyNever(() => mockDs.get());
    });

    test('404 : repli sur GET /account, compte ACTIVE en une ligne', () async {
      await goLegacy(legacyActive);

      final result = await repository.accounts();

      expect(result.legacy, isTrue);
      expect(result.suggested, isEmpty);
      final row = result.accounts.single;
      expect(row.id, MobileMoneyAccountRepository.legacyAccountId);
      expect(row.provider, 'ORANGE_SEN');
      expect(row.providerLabel, 'Orange Money');
      expect(row.brand, 'ORANGE');
      expect(row.country, 'SN');
      expect(row.currency, 'XOF');
      expect(row.msisdnMasked, '+221 •••• 67');
      expect(row.pendingPayouts, 0);
      expect(row.isLocked, isFalse);
    });

    test('404 : compte non actif, aucune ligne', () async {
      await goLegacy(
        const MobileMoneyAccount(status: MobileMoneyAccountStatus.disabled),
      );

      final result = await repository.accounts();

      expect(result.legacy, isTrue);
      expect(result.accounts, isEmpty);
    });

    test('404 : champs absents de l\'ancien compte, valeurs vides', () async {
      await goLegacy(
        const MobileMoneyAccount(status: MobileMoneyAccountStatus.active),
      );

      final row = (await repository.accounts()).accounts.single;

      expect(row.provider, '');
      expect(row.providerLabel, '');
      expect(row.msisdnMasked, '');
    });

    test(
      'le mode repli est mémorisé : /accounts n\'est plus rappelé',
      () async {
        await goLegacy(legacyActive);

        await repository.accounts();

        verify(() => mockDs.accounts()).called(1);
        verify(() => mockDs.get()).called(2);
      },
    );

    test('autre erreur propagée telle quelle, sans repli', () async {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const ServerException(),
      );
      when(() => mockDs.accounts()).thenAnswer((_) => Future.error(error));

      await expectLater(repository.accounts(), throwsA(same(error)));

      verifyNever(() => mockDs.get());
      // Pas de mode repli mémorisé : le prochain appel retente /accounts.
      when(() => mockDs.accounts()).thenAnswer((_) async => newContract);
      expect((await repository.accounts()).legacy, isFalse);
    });

    test('addAccount nouveau contrat : POST /accounts', () async {
      when(
        () => mockDs.addAccount(
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => orange);

      await repository.addAccount(phoneNumber: '+225', provider: 'ORANGE_CIV');

      verify(
        () => mockDs.addAccount(phoneNumber: '+225', provider: 'ORANGE_CIV'),
      ).called(1);
    });

    test('addAccount en repli : POST /account avec providers [code]', () async {
      await goLegacy(legacyActive);
      when(
        () => mockDs.activate(
          phoneNumber: any(named: 'phoneNumber'),
          providers: any(named: 'providers'),
        ),
      ).thenAnswer((_) async => legacyActive);

      await repository.addAccount(phoneNumber: '+225', provider: 'ORANGE_CIV');

      verify(
        () => mockDs.activate(phoneNumber: '+225', providers: ['ORANGE_CIV']),
      ).called(1);
      verifyNever(
        () => mockDs.addAccount(
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      );
    });

    test('changeNumber nouveau contrat : PUT par identifiant', () async {
      when(
        () => mockDs.changeNumber(
          id: any(named: 'id'),
          phoneNumber: any(named: 'phoneNumber'),
        ),
      ).thenAnswer((_) async => orange);

      await repository.changeNumber(account: orange, phoneNumber: '+226');

      verify(
        () => mockDs.changeNumber(id: 'acc-1', phoneNumber: '+226'),
      ).called(1);
    });

    test(
      'changeNumber en repli : POST /account avec le code du compte',
      () async {
        await goLegacy(legacyActive);
        when(
          () => mockDs.activate(
            phoneNumber: any(named: 'phoneNumber'),
            providers: any(named: 'providers'),
          ),
        ).thenAnswer((_) async => legacyActive);

        await repository.changeNumber(account: orange, phoneNumber: '+226');

        verify(
          () => mockDs.activate(phoneNumber: '+226', providers: ['ORANGE_CIV']),
        ).called(1);
        verifyNever(
          () => mockDs.changeNumber(
            id: any(named: 'id'),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    test('removeAccount nouveau contrat : DELETE par identifiant', () async {
      when(() => mockDs.removeAccount(any())).thenAnswer((_) async {});

      await repository.removeAccount(orange);

      verify(() => mockDs.removeAccount('acc-1')).called(1);
    });

    test('removeAccount en repli : DELETE /account', () async {
      await goLegacy(legacyActive);
      when(() => mockDs.disable()).thenAnswer((_) async => disabledAccount);

      await repository.removeAccount(orange);

      verify(() => mockDs.disable()).called(1);
      verifyNever(() => mockDs.removeAccount(any()));
    });

    test('erreur métier d\'une écriture propagée (409 verrou)', () async {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const ConflictException(
          'verrou',
          code: 'mobile-money-account-locked',
        ),
      );
      when(
        () => mockDs.removeAccount(any()),
      ).thenAnswer((_) => Future.error(error));

      await expectLater(repository.removeAccount(orange), throwsA(same(error)));
    });

    test('payoutCountries : catalogue du datasource', () async {
      const countries = MobileMoneyCountries(upcoming: ['ML']);
      when(() => mockDs.payoutCountries()).thenAnswer((_) async => countries);

      expect(await repository.payoutCountries(), countries);
    });

    test('payoutCountries : 404 donne null', () async {
      when(
        () => mockDs.payoutCountries(),
      ).thenAnswer((_) => Future.error(notFound()));

      expect(await repository.payoutCountries(), isNull);
    });

    test('payoutCountries : autre erreur propagée', () async {
      when(
        () => mockDs.payoutCountries(),
      ).thenAnswer((_) => Future.error(Exception('réseau')));

      await expectLater(
        repository.payoutCountries(),
        throwsA(isA<Exception>()),
      );
    });

    test('payoutProviders : catalogue pour le numéro E.164', () async {
      const catalog = MobileMoneyProviderCatalog(country: 'CI');
      when(
        () => mockDs.providers(phoneNumber: '+2250708091036'),
      ).thenAnswer((_) async => catalog);

      expect(await repository.payoutProviders('+2250708091036'), catalog);
    });
  });
}
