import 'package:dony/features/payments/cash/data/datasources/commission_method_remote_datasource.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommissionMethodRemoteDatasource extends Mock
    implements CommissionMethodRemoteDatasource {}

const _fakeCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

void main() {
  late MockCommissionMethodRemoteDatasource mockDs;
  late CommissionMethodRepository repo;

  setUp(() {
    mockDs = MockCommissionMethodRemoteDatasource();
    repo = CommissionMethodRepository(mockDs);
  });

  test('startSetup delegates to datasource.setup()', () async {
    when(() => mockDs.setup()).thenAnswer((_) async => 'seti_x');
    final result = await repo.startSetup();
    expect(result, 'seti_x');
    verify(() => mockDs.setup()).called(1);
  });

  test('load delegates to datasource.get()', () async {
    when(() => mockDs.get()).thenAnswer((_) async => _fakeCard);
    final result = await repo.load();
    expect(result, _fakeCard);
  });

  test('load returns null when datasource returns null', () async {
    when(() => mockDs.get()).thenAnswer((_) async => null);
    final result = await repo.load();
    expect(result, isNull);
  });

  test('remove delegates to datasource.delete()', () async {
    when(() => mockDs.delete()).thenAnswer((_) async {});
    await repo.remove();
    verify(() => mockDs.delete()).called(1);
  });
}
