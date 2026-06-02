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

  group('ErrorCatalog — pro-limit-reached', () {
    // RÉGRESSION : sans entrée dédiée, une ForbiddenException(pro-limit-reached)
    // retombait sur le type-fallback `forbidden` (« Action non autorisée »), donc
    // l'utilisateur ne comprenait pas qu'il s'agissait du quota mensuel.
    test('code dédié → message clair « Passer en PRO » (warning)', () {
      const error = ForbiddenException(
          'Vous avez atteint votre limite de 2 annonces ce mois-ci.',
          'pro-limit-reached');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Limite mensuelle atteinte');
      expect(p.message, contains('PRO'));
      expect(p.severity, ErrorSeverity.warning);
    });

    test('isKnown reconnaît le code', () {
      const error = ForbiddenException('peu importe', 'pro-limit-reached');
      expect(ErrorCatalog.isKnown(error), isTrue);
    });
  });
}
