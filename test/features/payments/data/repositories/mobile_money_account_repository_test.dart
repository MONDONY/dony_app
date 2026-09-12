import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyAccountRemoteDatasource extends Mock
    implements MobileMoneyAccountRemoteDatasource {}

void main() {
  late MockMobileMoneyAccountRemoteDatasource mockDs;
  late MobileMoneyAccountRepository repository;

  const activeAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.active,
    msisdnMasked: '+221 •••• 67',
    providerLabel: 'Orange Money',
  );

  const disabledAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.disabled,
  );

  setUp(() {
    mockDs = MockMobileMoneyAccountRemoteDatasource();
    repository = MobileMoneyAccountRepository(mockDs);
  });

  group('MobileMoneyAccountRepository', () {
    test('get délègue à datasource.get()', () async {
      when(() => mockDs.get()).thenAnswer((_) async => activeAccount);

      final result = await repository.get();

      expect(result, activeAccount);
      verify(() => mockDs.get()).called(1);
    });

    test('get propage l\'exception du datasource', () async {
      when(
        () => mockDs.get(),
      ).thenAnswer((_) => Future.error(Exception('réseau')));

      await expectLater(repository.get(), throwsA(isA<Exception>()));
    });

    test('activate délègue à datasource.activate()', () async {
      when(
        () => mockDs.activate(
          // ignore: avoid_redundant_argument_values
          phoneNumber: null,
          providers: [],
        ),
      ).thenAnswer((_) async => activeAccount);

      final result = await repository.activate();

      expect(result, activeAccount);
      verify(
        () => mockDs.activate(
          // ignore: avoid_redundant_argument_values
          phoneNumber: null,
          providers: [],
        ),
      ).called(1);
    });

    test(
      'activate avec un numéro délègue à datasource.activate(phoneNumber:)',
      () async {
        when(
          () => mockDs.activate(phoneNumber: '+221771234567', providers: []),
        ).thenAnswer((_) async => activeAccount);

        final result = await repository.activate(phoneNumber: '+221771234567');

        expect(result, activeAccount);
        verify(
          () => mockDs.activate(phoneNumber: '+221771234567', providers: []),
        ).called(1);
      },
    );

    test('providers délègue au datasource', () async {
      const catalog = MobileMoneyProviderCatalog(country: 'CI');
      when(
        () => mockDs.providers(phoneNumber: '+225'),
      ).thenAnswer((_) async => catalog);

      expect(await repository.providers(phoneNumber: '+225'), catalog);
    });

    test('activate transmet la liste des réseaux', () async {
      when(
        () => mockDs.activate(phoneNumber: '+225', providers: ['WAVE_CIV']),
      ).thenAnswer((_) async => activeAccount);

      expect(
        await repository.activate(phoneNumber: '+225', providers: ['WAVE_CIV']),
        activeAccount,
      );
    });

    test('updateProviders délègue au datasource', () async {
      when(
        () => mockDs.updateProviders(['WAVE_CIV']),
      ).thenAnswer((_) async => activeAccount);

      expect(await repository.updateProviders(['WAVE_CIV']), activeAccount);
    });

    test('disable délègue à datasource.disable()', () async {
      when(() => mockDs.disable()).thenAnswer((_) async => disabledAccount);

      final result = await repository.disable();

      expect(result, disabledAccount);
      verify(() => mockDs.disable()).called(1);
    });
  });
}
