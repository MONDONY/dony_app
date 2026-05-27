import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorCatalog — ValidationException', () {
    test('avec violations → message liste les messages de champ (regression)', () {
      const error = ValidationException(
        'Validation failed',
        errors: {
          'availableKg': ["La capacité doit être d'au moins 1 kg"],
          'pricePerKg': ['Le prix ne peut pas être négatif'],
        },
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Données invalides');
      expect(p.message, contains("La capacité doit être d'au moins 1 kg"));
      expect(p.message, contains('Le prix ne peut pas être négatif'));
    });

    test('sans violations → message générique', () {
      const error = ValidationException('Validation failed');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Données invalides');
      expect(p.message, 'Vérifie les informations saisies puis réessaie.');
    });

    test('violations vides → message générique', () {
      const error = ValidationException('Validation failed', errors: {});

      final p = ErrorCatalog.lookup(error);

      expect(p.message, 'Vérifie les informations saisies puis réessaie.');
    });
  });
}
