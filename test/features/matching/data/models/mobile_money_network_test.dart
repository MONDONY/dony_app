import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:flutter_test/flutter_test.dart';

const _orangeCi = MobileMoneyNetwork(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
);
const _orangeSn = MobileMoneyNetwork(
  code: 'ORANGE_SEN',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'SN',
);
const _mtnCi = MobileMoneyNetwork(
  code: 'MTN_MOMO_CIV',
  label: 'MTN MoMo',
  brand: 'MTN',
  country: 'CI',
);

void main() {
  group('MobileMoneyNetwork.fromJson', () {
    test('lit code, libellé, marque et pays', () {
      final n = MobileMoneyNetwork.fromJson(const {
        'code': 'ORANGE_CIV',
        'label': 'Orange Money',
        'brand': 'ORANGE',
        'country': 'CI',
      });
      expect(n, _orangeCi);
      expect(n.toJson(), {
        'code': 'ORANGE_CIV',
        'label': 'Orange Money',
        'brand': 'ORANGE',
        'country': 'CI',
      });
    });

    test('champs manquants : marque dérivée du code, libellé = code', () {
      final n = MobileMoneyNetwork.fromJson(const {'code': 'MTN_MOMO_CIV'});
      expect(n.brand, 'MTN');
      expect(n.label, 'MTN_MOMO_CIV');
      expect(n.country, '');
    });
  });

  group('mobileMoneyNetworksFromJson', () {
    test('clé absente ou non liste : liste vide', () {
      expect(mobileMoneyNetworksFromJson(null), isEmpty);
      expect(mobileMoneyNetworksFromJson('x'), isEmpty);
    });

    test('ignore les entrées illisibles', () {
      final list = mobileMoneyNetworksFromJson([
        {'code': 'ORANGE_CIV', 'label': 'Orange Money', 'brand': 'ORANGE'},
        'poubelle',
        {'label': 'sans code'},
      ]);
      expect(list.map((n) => n.code), ['ORANGE_CIV']);
    });
  });

  group('mobileMoneyNetworkChipLabel', () {
    test('marque seule quand elle n\'apparaît qu\'une fois', () {
      const all = [_orangeCi, _mtnCi];
      expect(mobileMoneyNetworkChipLabel(_orangeCi, all), 'Orange');
      expect(mobileMoneyNetworkChipLabel(_mtnCi, all), 'MTN');
    });

    test('même marque dans deux pays : code pays ajouté', () {
      const all = [_orangeCi, _orangeSn, _mtnCi];
      expect(mobileMoneyNetworkChipLabel(_orangeCi, all), 'Orange CI');
      expect(mobileMoneyNetworkChipLabel(_orangeSn, all), 'Orange SN');
      expect(mobileMoneyNetworkChipLabel(_mtnCi, all), 'MTN');
    });
  });

  group('AnnouncementModel.acceptedMobileMoneyNetworks', () {
    Map<String, dynamic> base() => {
      'id': 'ann1',
      'travelerId': 't1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2024-06-01',
      'availableKg': 10.0,
      'totalKg': 20.0,
      'pricePerKg': 15.0,
      'status': 'ACTIVE',
      'createdAt': '2024-01-01T00:00:00Z',
      'updatedAt': '2024-01-01T00:00:00Z',
    };

    test('clé absente (back ancien) : liste vide', () {
      expect(
        AnnouncementModel.fromJson(base()).acceptedMobileMoneyNetworks,
        isEmpty,
      );
    });

    test('liste servie : réseaux lus, aller-retour JSON conservé', () {
      final a = AnnouncementModel.fromJson({
        ...base(),
        'acceptedMobileMoneyNetworks': [
          {
            'code': 'ORANGE_CIV',
            'label': 'Orange Money',
            'brand': 'ORANGE',
            'country': 'CI',
          },
          {
            'code': 'ORANGE_SEN',
            'label': 'Orange Money',
            'brand': 'ORANGE',
            'country': 'SN',
          },
        ],
      });
      expect(a.acceptedMobileMoneyNetworks, [_orangeCi, _orangeSn]);
      final again = AnnouncementModel.fromJson(a.toJson());
      expect(again.acceptedMobileMoneyNetworks, [_orangeCi, _orangeSn]);
    });
  });
}
