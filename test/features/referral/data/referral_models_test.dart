import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReferralInfo.fromJson', () {
    const legacyJson = <String, dynamic>{
      'code': 'ABOU1890',
      'shareUrl': 'https://yadony.com/r/ABOU1890',
      'totalInvited': 4,
      'signedUp': 3,
      'rewarded': 2,
      'hasBeenReferred': false,
      'activeVoucherCount': 1,
      'voucherFactor': 0.5,
      'nextVoucherExpiresAt': '2027-01-15T00:00:00Z',
    };

    test('ancien contrat : champs nouveaux absents, replis 5 € / 5 %', () {
      final info = ReferralInfo.fromJson(legacyJson);

      expect(info.firstDelivery, isNull);
      expect(info.pendingRewardCount, isNull);
      expect(info.firstDeliveryCount, 2, reason: 'repli sur rewarded');
      expect(info.effectiveRewardWalletAmount, 5.0);
      expect(info.effectiveRewardWalletCurrency, 'EUR');
      expect(info.effectiveRewardDiscountPercent, 5);
      expect(info.voucherPercentOff, 50);
    });

    test('nouveau contrat : champs lus', () {
      final info = ReferralInfo.fromJson({
        ...legacyJson,
        'firstDelivery': 3,
        'pendingRewardCount': 1,
        'rewardWalletAmount': 7.5,
        'rewardWalletCurrency': 'XOF',
        'rewardDiscountPercent': 10,
      });

      expect(info.firstDeliveryCount, 3);
      expect(info.pendingRewardCount, 1);
      expect(info.effectiveRewardWalletAmount, 7.5);
      expect(info.effectiveRewardWalletCurrency, 'XOF');
      expect(info.effectiveRewardDiscountPercent, 10);
    });
  });

  group('Referee.fromJson', () {
    test('filleul complet avec code de réduction', () {
      final referee = Referee.fromJson({
        'invitationId': 'inv-1',
        'displayName': 'Awa D.',
        'signedUpAt': '2026-10-02T10:00:00Z',
        'status': 'REWARDED',
        'rewardStatus': 'CHOSEN',
        'rewardChoice': 'DISCOUNT_CODE',
        'rewardAvailableAt': '2026-10-10T10:00:00Z',
        'rewardChosenAt': '2026-10-11T10:00:00Z',
        'walletAmount': null,
        'walletCurrency': null,
        'discountCode': {
          'code': 'MERCI-ABOU-7K2F',
          'percent': 5,
          'expiresAt': '2027-04-14T00:00:00Z',
          'used': false,
          'expired': false,
        },
      });

      expect(referee.invitationId, 'inv-1');
      expect(referee.displayName, 'Awa D.');
      expect(referee.initials, 'AD');
      expect(referee.status, RefereeStatus.rewarded);
      expect(referee.rewardStatus, RewardStatus.chosen);
      expect(referee.rewardChoice, RewardChoice.discountCode);
      expect(referee.discountCode?.code, 'MERCI-ABOU-7K2F');
      expect(referee.discountCode?.percent, 5);
      expect(referee.discountCode?.expiresAt, DateTime.utc(2027, 4, 14));
      expect(referee.earnedWalletAmount, 0);
    });

    test('crédit wallet choisi : montant compté dans les gains', () {
      final referee = Referee.fromJson({
        'invitationId': 'inv-2',
        'status': 'REWARDED',
        'rewardStatus': 'CHOSEN',
        'rewardChoice': 'WALLET_CREDIT',
        'walletAmount': 5.00,
        'walletCurrency': 'EUR',
      });

      expect(referee.earnedWalletAmount, 5.0);
      expect(referee.walletCurrency, 'EUR');
    });

    test('valeurs inconnues ou absentes : replis sans planter', () {
      final referee = Referee.fromJson({
        'invitationId': 'inv-3',
        'displayName': '   ',
        'status': 'SOMETHING_NEW',
        'rewardStatus': 'WHATEVER',
        'rewardChoice': 'UNKNOWN',
        'discountCode': {'code': ''},
      });

      expect(referee.displayName, isNull);
      expect(referee.initials, isNull);
      expect(referee.status, RefereeStatus.signedUp);
      expect(referee.rewardStatus, RewardStatus.none);
      expect(referee.rewardChoice, isNull);
      expect(referee.discountCode, isNull);
      expect(referee.signedUpAt, isNull);
      expect(referee.isRewardAvailable, isFalse);
    });

    test('récompense disponible', () {
      final referee = Referee.fromJson({
        'invitationId': 'inv-4',
        'status': 'FIRST_DELIVERY',
        'rewardStatus': 'AVAILABLE',
      });
      expect(referee.isRewardAvailable, isTrue);
      expect(referee.status, RefereeStatus.firstDelivery);
    });
  });

  test('RefereePage.fromJson lit la page et ignore les entrées invalides', () {
    final page = RefereePage.fromJson({
      'content': [
        {'invitationId': 'a', 'status': 'SIGNED_UP'},
        'garbage',
      ],
      'page': 1,
      'size': 20,
      'totalElements': 21,
      'totalPages': 2,
      'last': true,
    });

    expect(page.content, hasLength(1));
    expect(page.page, 1);
    expect(page.last, isTrue);
    expect(page.totalElements, 21);
  });

  test('RewardChoice : valeurs échangées avec le back', () {
    expect(RewardChoice.walletCredit.wire, 'WALLET_CREDIT');
    expect(RewardChoice.discountCode.wire, 'DISCOUNT_CODE');
    expect(
      RewardChoice.fromWire('COMMISSION_VOUCHER'),
      RewardChoice.commissionVoucher,
    );
    expect(RewardChoice.fromWire(null), isNull);
  });
}
