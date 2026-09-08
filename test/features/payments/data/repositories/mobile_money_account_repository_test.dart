import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
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
      when(() => mockDs.activate()).thenAnswer((_) async => activeAccount);

      final result = await repository.activate();

      expect(result, activeAccount);
      verify(() => mockDs.activate()).called(1);
    });

    test('disable délègue à datasource.disable()', () async {
      when(() => mockDs.disable()).thenAnswer((_) async => disabledAccount);

      final result = await repository.disable();

      expect(result, disabledAccount);
      verify(() => mockDs.disable()).called(1);
    });
  });
}
