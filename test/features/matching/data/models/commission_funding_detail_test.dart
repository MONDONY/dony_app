import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/commission_funding_detail.dart';
import 'package:dony/features/matching/data/models/supplement_commission_unfunded.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const json = {
    'bidCurrency': 'eur',
    'commission': 10,
    'availableInBid': 7.5,
    'shortfallInBid': 2.5,
    'wallets': [
      {'currency': 'usd', 'balance': 5, 'valueInBid': 4.6},
      {'currency': 'XOF', 'balance': 1900, 'valueInBid': 2.9},
    ],
    'excluded': {'gbp': 'frozen'},
  };

  test('lit le détail complet et met les devises en majuscules', () {
    final d = CommissionFundingDetail.fromJson(json);

    expect(d.bidCurrency, 'EUR');
    expect(d.commission, 10);
    expect(d.availableInBid, 7.5);
    expect(d.shortfallInBid, 2.5);
    expect(d.wallets.map((w) => w.currency), ['USD', 'XOF']);
    expect(d.wallets.first.valueInBid, 4.6);
    expect(d.excluded, {'GBP': CommissionFundingDetail.frozen});
    expect(d.hasExclusions, isTrue);
  });

  test('listes absentes : valeurs neutres', () {
    final d = CommissionFundingDetail.fromJson(const {
      'bidCurrency': 'EUR',
      'commission': 3,
    });

    expect(d.wallets, isEmpty);
    expect(d.excluded, isEmpty);
    expect(d.availableInBid, 0);
    expect(d.hasExclusions, isFalse);
  });

  test('tryParse : null si absent ou mal formé', () {
    expect(CommissionFundingDetail.tryParse(null), isNull);
    expect(CommissionFundingDetail.tryParse('x'), isNull);
    expect(CommissionFundingDetail.tryParse(const {'bidCurrency': 1}), isNull);
    expect(CommissionFundingDetail.tryParse(json), isNotNull);
  });

  test('égalité par valeur', () {
    expect(
      CommissionFundingDetail.fromJson(json),
      CommissionFundingDetail.fromJson(json),
    );
  });

  test('SupplementCommissionUnfunded lit fundingDetail de l\'erreur', () {
    final unfunded = SupplementCommissionUnfunded.fromError(
      const ValidationException(
        'x',
        code: SupplementCommissionUnfunded.code,
        extensions: <String, Object?>{
          'availableBalance': 1,
          'requiredCommission': 2,
          'shortfall': 1,
          'fundingDetail': json,
        },
      ),
    );

    expect(unfunded?.fundingDetail?.shortfallInBid, 2.5);
  });
}
