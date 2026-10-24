import 'package:dony/features/matching/data/datasources/bid_amendment_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements BidAmendmentRemoteDatasource {}

BidAmendment _amendment() => BidAmendment.fromJson({
  'id': 'am-1',
  'status': 'PROPOSED',
  'grossAmount': 10,
});

void main() {
  late _MockDatasource datasource;
  late BidAmendmentRepository repository;

  setUp(() {
    datasource = _MockDatasource();
    repository = BidAmendmentRepository(datasource);
  });

  test('options et quote passent au datasource', () async {
    final options = AmendmentOptions.fromJson({
      'currency': 'EUR',
      'minAmount': 1,
      'maxAmount': 300,
    });
    when(() => datasource.options('b-1')).thenAnswer((_) async => options);
    when(
      () => datasource.quote('b-1', addedKg: 2, items: {'g': 1}),
    ).thenAnswer((_) async => 22.4);

    expect(await repository.options('b-1'), options);
    expect(await repository.quote('b-1', addedKg: 2, items: {'g': 1}), 22.4);
  });

  test('create transmet kilos, articles et moyen de paiement', () async {
    final checkout = AmendmentCheckout(amendment: _amendment());
    when(
      () => datasource.create(
        'b-1',
        addedKg: 2,
        items: {'g': 1},
        method: BidPaymentMethod.cash,
      ),
    ).thenAnswer((_) async => checkout);

    final result = await repository.create(
      'b-1',
      addedKg: 2,
      items: {'g': 1},
      method: BidPaymentMethod.cash,
    );

    expect(result, checkout);
  });

  test('les actions sur une modification passent au datasource', () async {
    final amendment = _amendment();
    when(
      () => datasource.confirmAuthorization('b-1', 'am-1'),
    ).thenAnswer((_) async => amendment);
    when(
      () => datasource.cancel('b-1', 'am-1'),
    ).thenAnswer((_) async => amendment);
    when(
      () => datasource.decline('b-1', 'am-1'),
    ).thenAnswer((_) async => amendment);
    when(
      () => datasource.notBrought('b-1', 'am-1'),
    ).thenAnswer((_) async => amendment);
    when(
      () => datasource.confirmCommission('b-1', 'am-1'),
    ).thenAnswer((_) async => amendment);
    when(
      () => datasource.accept(
        'b-1',
        'am-1',
        commissionSource: SupplementCommissionSource.wallet,
        fundingCurrency: 'XOF',
      ),
    ).thenAnswer((_) async => amendment);

    expect(await repository.confirmAuthorization('b-1', 'am-1'), amendment);
    expect(await repository.cancel('b-1', 'am-1'), amendment);
    expect(await repository.decline('b-1', 'am-1'), amendment);
    expect(await repository.notBrought('b-1', 'am-1'), amendment);
    expect(await repository.confirmCommission('b-1', 'am-1'), amendment);
    expect(
      await repository.accept(
        'b-1',
        'am-1',
        commissionSource: SupplementCommissionSource.wallet,
        fundingCurrency: 'XOF',
      ),
      amendment,
    );
  });
}
