import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseAnnouncementJson() => {
    'id': 'a1',
    'travelerId': 't1',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate': '2026-06-01T00:00:00.000Z',
    'availableKg': 10.0,
    'totalKg': 10.0,
    'pricePerKg': 5.0,
    'status': 'ACTIVE',
    'createdAt': '2026-05-02T00:00:00.000Z',
    'updatedAt': '2026-05-02T00:00:00.000Z',
  };

  group('AnnouncementModel.transportMode', () {
    test('deserializes "PLANE" -> TransportMode.plane', () {
      final json = baseAnnouncementJson()..['transportMode'] = 'PLANE';
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, TransportMode.plane);
    });

    test('deserializes each known value', () {
      const wireToEnum = {
        'PLANE': TransportMode.plane,
        'CAR': TransportMode.car,
        'TRAIN': TransportMode.train,
        'BUS': TransportMode.bus,
        'BOAT': TransportMode.boat,
        'OTHER': TransportMode.other,
      };
      for (final entry in wireToEnum.entries) {
        final json = baseAnnouncementJson()..['transportMode'] = entry.key;
        final model = AnnouncementModel.fromJson(json);
        expect(model.transportMode, entry.value);
      }
    });

    test('deserializes missing transportMode as null', () {
      final json = baseAnnouncementJson();
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, isNull);
    });

    test('deserializes unknown transportMode as null', () {
      final json = baseAnnouncementJson()..['transportMode'] = 'BIKE';
      final model = AnnouncementModel.fromJson(json);
      expect(model.transportMode, isNull);
    });

    test('serializes TransportMode.plane -> "PLANE"', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
        transportMode: TransportMode.plane,
      );
      final json = model.toJson();
      expect(json['transportMode'], 'PLANE');
    });

    test('serializes null transportMode -> null in JSON', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
      );
      final json = model.toJson();
      expect(json['transportMode'], isNull);
    });
  });

  group('AnnouncementModel.currency', () {
    test('deserializes currency from backend, not always EUR', () {
      final json = baseAnnouncementJson()..['currency'] = 'CAD';
      final model = AnnouncementModel.fromJson(json);
      expect(model.currency, 'CAD');
    });

    test('defaults to EUR when currency is absent (older payload)', () {
      final json = baseAnnouncementJson();
      final model = AnnouncementModel.fromJson(json);
      expect(model.currency, 'EUR');
    });
  });

  group('AnnouncementGridItemModel', () {
    test('constructs correctly', () {
      const item = AnnouncementGridItemModel(
        id: 'item-1',
        label: 'Valise cabine',
        unitPriceNet: 10.0,
        unitPriceDisplay: 11.2,
      );

      expect(item.id, 'item-1');
      expect(item.label, 'Valise cabine');
      expect(item.unitPriceNet, 10.0);
      expect(item.unitPriceDisplay, 11.2);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'item-2',
        'label': 'Téléphone',
        'unitPriceNet': 20.0,
        'unitPriceDisplay': 22.4,
      };
      final item = AnnouncementGridItemModel.fromJson(json);

      expect(item.id, 'item-2');
      expect(item.label, 'Téléphone');
      expect(item.unitPriceNet, 20.0);
      expect(item.unitPriceDisplay, 22.4);
    });

    test('fromJson handles integer price values', () {
      final json = {
        'id': 'item-3',
        'label': 'Ordinateur',
        'unitPriceNet': 50,
        'unitPriceDisplay': 56,
      };
      final item = AnnouncementGridItemModel.fromJson(json);

      expect(item.unitPriceNet, 50.0);
      expect(item.unitPriceDisplay, 56.0);
    });

    test('toJson serializes correctly', () {
      const item = AnnouncementGridItemModel(
        id: 'item-4',
        label: 'Chaussures',
        unitPriceNet: 15.0,
        unitPriceDisplay: 16.8,
      );
      final json = item.toJson();

      expect(json['id'], 'item-4');
      expect(json['label'], 'Chaussures');
      expect(json['unitPriceNet'], 15.0);
      expect(json['unitPriceDisplay'], 16.8);
    });

    test('round-trips through JSON', () {
      const original = AnnouncementGridItemModel(
        id: 'item-round',
        label: 'Sacoche',
        unitPriceNet: 8.0,
        unitPriceDisplay: 9.0,
      );
      final json = original.toJson();
      final restored = AnnouncementGridItemModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.unitPriceNet, original.unitPriceNet);
      expect(restored.unitPriceDisplay, original.unitPriceDisplay);
    });

    test('fromJson tolère un unitPriceNet absent (net masqué pour un invité)', () {
      // Même masquage backend que pricePerKg (PriceGridService.travelerNetOrNull,
      // appelé depuis AnnouncementSearchMapper/AnnouncementService) : le net
      // d'un article de grille ne doit pas fuir vers une session anonyme, et son
      // absence ne doit pas planter la désérialisation.
      final json = {
        'id': 'item-5',
        'label': 'Sac de riz',
        'unitPriceDisplay': 12.0,
      };
      final item = AnnouncementGridItemModel.fromJson(json);

      expect(item.unitPriceNet, isNull);
      expect(item.unitPriceDisplay, 12.0);
    });
  });

  group('AnnouncementModel bid counts', () {
    test('parses pendingBidCount / confirmedParcelCount from JSON', () {
      final json = baseAnnouncementJson()
        ..['pendingBidCount'] = 3
        ..['confirmedParcelCount'] = 2;
      final model = AnnouncementModel.fromJson(json);

      expect(model.pendingBidCount, 3);
      expect(model.confirmedParcelCount, 2);
    });

    test('defaults both counts to 0 when absent', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.pendingBidCount, 0);
      expect(model.confirmedParcelCount, 0);
    });

    test('round-trips bid counts through toJson', () {
      final json = baseAnnouncementJson()
        ..['pendingBidCount'] = 5
        ..['confirmedParcelCount'] = 1;
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['pendingBidCount'], 5);
      expect(out['confirmedParcelCount'], 1);
    });
  });

  group('AnnouncementModel surplus capacity', () {
    test(
      'parses reservedKg / surplusEligible / surplusPublished from JSON',
      () {
        final json = baseAnnouncementJson()
          ..['reservedKg'] = 12.0
          ..['surplusEligible'] = true
          ..['surplusPublished'] = true;
        final model = AnnouncementModel.fromJson(json);

        expect(model.reservedKg, 12.0);
        expect(model.surplusEligible, isTrue);
        expect(model.surplusPublished, isTrue);
      },
    );

    test('parses integer reservedKg as double', () {
      final json = baseAnnouncementJson()..['reservedKg'] = 8;
      final model = AnnouncementModel.fromJson(json);
      expect(model.reservedKg, 8.0);
    });

    test('defaults when surplus fields are absent', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.reservedKg, 0);
      expect(model.surplusEligible, isFalse);
      expect(model.surplusPublished, isFalse);
    });

    test('round-trips surplus fields through toJson', () {
      final json = baseAnnouncementJson()
        ..['reservedKg'] = 5.0
        ..['surplusEligible'] = true
        ..['surplusPublished'] = false;
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['reservedKg'], 5.0);
      expect(out['surplusEligible'], true);
      expect(out['surplusPublished'], false);
    });

    test('isDedicated is true when reservedKg > 0', () {
      final dedicated = AnnouncementModel.fromJson(
        baseAnnouncementJson()..['reservedKg'] = 10.0,
      );
      final normal = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(dedicated.isDedicated, isTrue);
      expect(normal.isDedicated, isFalse);
    });

    test('canOpenSurplus is true only when eligible and not yet published', () {
      AnnouncementModel build({
        required bool eligible,
        required bool published,
      }) => AnnouncementModel.fromJson(
        baseAnnouncementJson()
          ..['surplusEligible'] = eligible
          ..['surplusPublished'] = published,
      );

      expect(build(eligible: true, published: false).canOpenSurplus, isTrue);
      expect(build(eligible: true, published: true).canOpenSurplus, isFalse);
      expect(build(eligible: false, published: false).canOpenSurplus, isFalse);
      expect(build(eligible: false, published: true).canOpenSurplus, isFalse);
    });
  });

  group('AnnouncementModel country codes & flags', () {
    test('parses departure/arrival country codes and flags from JSON', () {
      final json = baseAnnouncementJson()
        ..['departureCountryCode'] = 'FR'
        ..['arrivalCountryCode'] = 'US'
        ..['departureFlag'] = '🇫🇷'
        ..['arrivalFlag'] = '🇺🇸';
      final model = AnnouncementModel.fromJson(json);

      expect(model.departureCountryCode, 'FR');
      expect(model.arrivalCountryCode, 'US');
      expect(model.departureFlag, '🇫🇷');
      expect(model.arrivalFlag, '🇺🇸');
    });

    test('country codes and flags are null when absent', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.departureCountryCode, isNull);
      expect(model.arrivalCountryCode, isNull);
      expect(model.departureFlag, isNull);
      expect(model.arrivalFlag, isNull);
    });

    test('round-trips country codes and flags through toJson', () {
      final json = baseAnnouncementJson()
        ..['departureCountryCode'] = 'SN'
        ..['arrivalCountryCode'] = 'CI'
        ..['departureFlag'] = '🇸🇳'
        ..['arrivalFlag'] = '🇨🇮';
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['departureCountryCode'], 'SN');
      expect(out['arrivalCountryCode'], 'CI');
      expect(out['departureFlag'], '🇸🇳');
      expect(out['arrivalFlag'], '🇨🇮');
    });
  });

  group('AnnouncementModel handover window', () {
    test('parse handoverDeadline depuis le JSON', () {
      final json = baseAnnouncementJson()
        ..['handoverDeadline'] = '2026-06-14T18:00:00';
      final model = AnnouncementModel.fromJson(json);
      expect(model.handoverDeadline, DateTime.parse('2026-06-14T18:00:00'));
    });

    test('handover window null toléré (annonce legacy)', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.handoverDeadline, isNull);
    });

    test('round-trips handover window through toJson', () {
      final json = baseAnnouncementJson()
        ..['handoverDeadline'] = '2026-06-14T18:00:00.000Z';
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['handoverDeadline'], isNotNull);
    });
  });

  group('AnnouncementModel with priceGridItems', () {
    test('deserializes priceGridItems from JSON', () {
      final json = baseAnnouncementJson()
        ..['pricingMode'] = 'MIXED'
        ..['priceGridItems'] = [
          {
            'id': 'item-1',
            'label': 'Valise cabine',
            'unitPriceNet': 10.0,
            'unitPriceDisplay': 11.2,
          },
        ];

      final model = AnnouncementModel.fromJson(json);
      expect(model.priceGridItems, hasLength(1));
      expect(model.priceGridItems.first.id, 'item-1');
      expect(model.priceGridItems.first.label, 'Valise cabine');
    });

    test('priceGridItems defaults to empty list when null in JSON', () {
      final json = baseAnnouncementJson();
      final model = AnnouncementModel.fromJson(json);
      expect(model.priceGridItems, isEmpty);
    });

    test('priceGridItems serializes back to JSON', () {
      final model = AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime.parse('2026-06-01'),
        availableKg: 10.0,
        totalKg: 10.0,
        pricePerKg: 5.0,
        status: 'ACTIVE',
        createdAt: DateTime.parse('2026-05-02'),
        updatedAt: DateTime.parse('2026-05-02'),
        pricingMode: 'MIXED',
        priceGridItems: const [
          AnnouncementGridItemModel(
            id: 'item-1',
            label: 'Valise',
            unitPriceNet: 10.0,
            unitPriceDisplay: 11.2,
          ),
        ],
      );

      final json = model.toJson();
      expect(json['priceGridItems'], isNotNull);
      expect((json['priceGridItems'] as List), hasLength(1));
    });
  });

  group('AnnouncementModel urgent', () {
    test('urgent depuis le JSON prime sur le calcul local (true)', () {
      final json = baseAnnouncementJson()
        ..['departureDate'] = DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
        ..['urgent'] = true;
      final model = AnnouncementModel.fromJson(json);
      expect(model.isUrgent, isTrue);
    });

    test('urgent depuis le JSON prime sur le calcul local (false)', () {
      final json = baseAnnouncementJson()
        ..['departureDate'] = DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
        ..['urgent'] = false;
      final model = AnnouncementModel.fromJson(json);
      expect(model.isUrgent, isFalse);
    });

    test('urgent absent → repli sur la date (proche → urgent)', () {
      final json = baseAnnouncementJson()
        ..['departureDate'] = DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String();
      final model = AnnouncementModel.fromJson(json);
      expect(model.urgent, isNull);
      expect(model.isUrgent, isTrue);
    });

    test('urgent absent → repli sur la date (lointaine → pas urgent)', () {
      final json = baseAnnouncementJson()
        ..['departureDate'] = DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String();
      final model = AnnouncementModel.fromJson(json);
      expect(model.urgent, isNull);
      expect(model.isUrgent, isFalse);
    });

    test('isUrgent match isUrgentDate quand urgent absent', () {
      final departureDate = DateTime.now().add(const Duration(days: 2));
      final json = baseAnnouncementJson()
        ..['departureDate'] = departureDate.toIso8601String();
      final model = AnnouncementModel.fromJson(json);
      expect(model.isUrgent, isUrgentDate(model.departureDate));
    });

    test('round-trips urgent through toJson', () {
      final json = baseAnnouncementJson()..['urgent'] = true;
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['urgent'], true);
    });

    test('urgent absent dans le JSON de sortie reste null', () {
      final out = AnnouncementModel.fromJson(baseAnnouncementJson()).toJson();
      expect(out['urgent'], isNull);
    });
  });

  group('AnnouncementModel.convertedPricePerKg / convertedCurrency', () {
    test(
      'parses the server-computed conversion into the reader\'s currency',
      () {
        final json = baseAnnouncementJson()
          ..['currency'] = 'EUR'
          ..['convertedPricePerKg'] = 3279.79
          ..['convertedCurrency'] = 'XOF';
        final model = AnnouncementModel.fromJson(json);

        expect(model.convertedPricePerKg, 3279.79);
        expect(model.convertedCurrency, 'XOF');
      },
    );

    test('defaults both to null when the server has nothing to convert', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.convertedPricePerKg, isNull);
      expect(model.convertedCurrency, isNull);
    });

    test('parses an integer convertedPricePerKg as a double', () {
      final json = baseAnnouncementJson()
        ..['convertedPricePerKg'] = 5
        ..['convertedCurrency'] = 'USD';
      final model = AnnouncementModel.fromJson(json);
      expect(model.convertedPricePerKg, 5.0);
    });

    test('round-trips the conversion fields through toJson', () {
      final json = baseAnnouncementJson()
        ..['convertedPricePerKg'] = 42.0
        ..['convertedCurrency'] = 'USD';
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['convertedPricePerKg'], 42.0);
      expect(out['convertedCurrency'], 'USD');
    });
  });

  group(
    'AnnouncementModel.pricePerKgDisplayConverted (brut converti pour un invité)',
    () {
      test('pricePerKgDisplayConverted est lu quand le serveur le fournit', () {
        final json = baseAnnouncementJson()
          ..['pricePerKgDisplayConverted'] = 8200.0;

        final model = AnnouncementModel.fromJson(json);

        expect(model.pricePerKgDisplayConverted, 8200.0);
      });

      test('pricePerKgDisplayConverted absent : nul, aucune exception', () {
        final json = baseAnnouncementJson()
          ..remove('pricePerKgDisplayConverted');

        expect(
          AnnouncementModel.fromJson(json).pricePerKgDisplayConverted,
          isNull,
        );
      });

      test('parses an integer pricePerKgDisplayConverted as a double', () {
        final json = baseAnnouncementJson()
          ..['pricePerKgDisplayConverted'] = 8200;

        final model = AnnouncementModel.fromJson(json);

        expect(model.pricePerKgDisplayConverted, 8200.0);
      });
    },
  );

  group('AnnouncementModel.pricePerKg (net masqué pour un invité)', () {
    test('tolère un pricePerKg absent (net masqué pour un invité)', () {
      // Le backend masque le net voyageur aux sessions anonymes (décision
      // produit A15 : le net révélerait le taux de commission). Le modèle
      // doit survivre à son absence, sinon toute la recherche plante à la
      // désérialisation.
      final json = baseAnnouncementJson()
        ..remove('pricePerKg')
        ..['pricePerKgDisplay'] = 12.0;

      final model = AnnouncementModel.fromJson(json);

      expect(model.pricePerKg, isNull);
      // Pas de model.pricePerKgDisplay ici : ce serait tautologique (on vient
      // de le poser dans le JSON). senderPricePerKg est le getter réellement
      // consommé par l'affichage expéditeur, et c'est lui qui doit rester
      // exploitable quand le net est masqué.
      expect(model.senderPricePerKg, 12.0);
    });

    test('lit pricePerKg quand il est présent (compte inscrit)', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.pricePerKg, 5.0);
    });
  });

  group('AnnouncementModel.arrivalInstructions', () {
    test('fromJson parses arrivalInstructions', () {
      final json = baseAnnouncementJson()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final model = AnnouncementModel.fromJson(json);
      expect(model.arrivalInstructions, 'Métro Châtelet, sortie 3');
    });

    test('arrivalInstructions absent → null', () {
      final model = AnnouncementModel.fromJson(baseAnnouncementJson());
      expect(model.arrivalInstructions, isNull);
    });

    test('round-trips arrivalInstructions through toJson', () {
      final json = baseAnnouncementJson()
        ..['arrivalInstructions'] = 'Métro Châtelet, sortie 3';
      final out = AnnouncementModel.fromJson(json).toJson();
      expect(out['arrivalInstructions'], 'Métro Châtelet, sortie 3');
    });
  });
}
