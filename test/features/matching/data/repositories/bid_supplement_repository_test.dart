import 'package:dony/features/matching/data/datasources/bid_supplement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements BidSupplementRemoteDatasource {}

const _supplement = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  grossAmount: 17,
);

void main() {
  late _MockDatasource datasource;
  late BidSupplementRepository repository;

  setUpAll(() => registerFallbackValue(BidSupplementReason.other));

  setUp(() {
    datasource = _MockDatasource();
    repository = BidSupplementRepository(datasource);
  });

  test('délègue chaque appel à la datasource', () async {
    const options = SupplementOptions(currency: 'EUR', minNet: 1, maxNet: 300);
    const quote = SupplementQuote(
      netAmount: 15,
      commissionAmount: 2,
      grossAmount: 17,
      currency: 'EUR',
    );
    when(() => datasource.options('b')).thenAnswer((_) async => options);
    when(() => datasource.quote('b', 15)).thenAnswer((_) async => quote);
    when(
      () => datasource.uploadPhoto('b', '/p.jpg'),
    ).thenAnswer((_) async => 'k');
    when(
      () => datasource.create(
        'b',
        netAmount: 15,
        reason: BidSupplementReason.gridItem,
        reasonText: 't',
        gridItemLabel: 'Téléphone',
        photoKey: 'k',
      ),
    ).thenAnswer((_) async => _supplement);
    when(
      () => datasource.withdraw('b', 'sup-1'),
    ).thenAnswer((_) async => _supplement);
    when(
      () => datasource.decline('b', 'sup-1'),
    ).thenAnswer((_) async => _supplement);

    expect(await repository.options('b'), options);
    expect(await repository.quote('b', 15), quote);
    expect(await repository.uploadPhoto('b', '/p.jpg'), 'k');
    expect(
      await repository.create(
        'b',
        netAmount: 15,
        reason: BidSupplementReason.gridItem,
        reasonText: 't',
        gridItemLabel: 'Téléphone',
        photoKey: 'k',
      ),
      _supplement,
    );
    expect(await repository.withdraw('b', 'sup-1'), _supplement);
    expect(await repository.decline('b', 'sup-1'), _supplement);
  });
}
