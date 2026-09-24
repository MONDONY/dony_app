import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);
  final json = {
    'period': '30d',
    'deliveries': 2,
    'groups': [
      {
        'currency': 'EUR',
        'total': 1030.0,
        'deliveries': 1,
        'items': [
          {
            'tripId': 't1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'date': '2026-09-12',
            'weightKg': 4,
            'rail': 'CARD',
            'amount': 480.0,
          },
        ],
      },
      {
        'currency': 'XOF',
        'total': 120000,
        'deliveries': 1,
        'items': [
          {
            'tripId': null,
            'departureCity': 'Lyon',
            'arrivalCity': 'Abidjan',
            'date': '2026-09-09',
            'weightKg': null,
            'rail': 'MOBILE_MONEY',
            'amount': 120000,
          },
        ],
      },
    ],
  };

  group('RevenueDetailsModel.fromJson', () {
    test('lit les groupes, leurs lignes et les rails', () {
      final model = RevenueDetailsModel.fromJson(json);

      expect(model.period, '30d');
      expect(model.deliveries, 2);
      expect(model.groups.map((g) => g.currency), ['EUR', 'XOF']);
      expect(model.groups.first.total, 1030.0);
      expect(model.groups.first.deliveries, 1);
      final item = model.groups.first.items.single;
      expect(item.tripId, 't1');
      expect(item.departureCity, 'Paris');
      expect(item.arrivalCity, 'Dakar');
      expect(item.date, DateTime(2026, 9, 12));
      expect(item.weightKg, 4);
      expect(item.rail, RevenueRail.card);
      expect(item.amount, 480.0);
      final xof = model.groups.last.items.single;
      expect(xof.tripId, isNull);
      expect(xof.weightKg, isNull);
      expect(xof.rail, RevenueRail.mobileMoney);
    });

    test('un rail inconnu ne casse pas le parsing', () {
      expect(RevenueRail.fromApi('WIRE'), RevenueRail.unknown);
      expect(RevenueRail.fromApi(null), RevenueRail.unknown);
      expect(RevenueRail.fromApi('CASH'), RevenueRail.cash);
    });

    test('les libellés de rail sont ceux de l\'app', () {
      expect(RevenueRail.card.label(l), 'Carte');
      expect(RevenueRail.mobileMoney.label(l), 'Mobile money');
      expect(RevenueRail.cash.label(l), 'Espèces');
      expect(RevenueRail.unknown.label(l), 'Paiement');
    });

    test('groupes absents → liste vide', () {
      final model = RevenueDetailsModel.fromJson({'period': '7d'});

      expect(model.deliveries, 0);
      expect(model.groups, isEmpty);
    });
  });
}
