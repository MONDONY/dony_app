import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot 5 multidevise : équivalents « environ » servis par le backend sur les
/// budgets colis et les items de grille. Champs additifs — un payload antérieur
/// (sans ces clés) doit parser à l'identique.
void main() {
  Map<String, dynamic> searchItemJson() => {
    'id': 'r1',
    'departureCity': 'Dakar',
    'arrivalCity': 'Paris',
    'desiredDate': '2026-09-20',
    'dateToleranceDays': 3,
    'weightKg': 5.0,
    'parcelSize': 'SMALL',
    'transportMode': 'PLANE',
    'contentCategory': 'VETEMENTS',
    'negotiable': true,
    'sender': {
      'id': 's1',
      'displayName': 'Awa D.',
      'averageRating': 4.8,
      'totalRatings': 12,
      'kycVerified': true,
    },
    'currency': 'XOF',
    'targetPriceEur': 65596,
    'grossPriceEur': 73468,
  };

  group('PackageRequestSearchItem — convertedDisplayPrice', () {
    test('parse les équivalents convertis servis par le backend', () {
      final json = searchItemJson()
        ..addAll({'convertedDisplayPrice': 112.0, 'convertedCurrency': 'EUR'});

      final item = PackageRequestSearchItem.fromJson(json);

      expect(item.convertedDisplayPrice, 112.0);
      expect(item.convertedCurrency, 'EUR');
      // Le montant d'origine reste intouché : seule vérité transactionnelle.
      expect(item.grossPriceEur, 73468);
      expect(item.currency, 'XOF');
    });

    test('backend antérieur (clés absentes) → nulls, parsing intact', () {
      final item = PackageRequestSearchItem.fromJson(searchItemJson());

      expect(item.convertedDisplayPrice, isNull);
      expect(item.convertedCurrency, isNull);
    });
  });

  group('PackageRequest (détail) — convertedDisplayPrice', () {
    test('parse les équivalents convertis', () {
      final json = {
        'id': 'r1',
        'senderId': 's1',
        'departureCity': 'Dakar',
        'arrivalCity': 'Paris',
        'desiredDate': '2026-09-20',
        'dateToleranceDays': 3,
        'weightKg': 5.0,
        'parcelSize': 'SMALL',
        'transportMode': 'PLANE',
        'contentCategory': 'VETEMENTS',
        'status': 'OPEN',
        'createdAt': '2026-09-01T10:00:00',
        'negotiable': true,
        'currency': 'XOF',
        'targetPriceEur': 65596,
        'convertedDisplayPrice': 112.0,
        'convertedCurrency': 'EUR',
      };

      final request = PackageRequest.fromJson(json);

      expect(request.convertedDisplayPrice, 112.0);
      expect(request.convertedCurrency, 'EUR');
    });
  });

  group('AnnouncementGridItemModel — convertedUnitPriceDisplay', () {
    test('parse l\'équivalent converti d\'un item de grille', () {
      final item = AnnouncementGridItemModel.fromJson({
        'id': 'g1',
        'label': 'Valise 23 kg',
        'unitPriceDisplay': 33600,
        'convertedUnitPriceDisplay': 51.22,
      });

      expect(item.unitPriceDisplay, 33600);
      expect(item.convertedUnitPriceDisplay, 51.22);
    });

    test('clé absente (backend antérieur) → null', () {
      final item = AnnouncementGridItemModel.fromJson({
        'id': 'g1',
        'label': 'Valise 23 kg',
        'unitPriceDisplay': 33600,
      });

      expect(item.convertedUnitPriceDisplay, isNull);
    });
  });
}
