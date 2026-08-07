import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorCatalog — ValidationException', () {
    test(
      'avec violations → message liste les messages de champ (regression)',
      () {
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
      },
    );

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
        'pro-limit-reached',
      );

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

  group('ErrorCatalog — sms-otp-disabled', () {
    // Le backend renvoie 503 quand app.sms.enabled=false en prod alors que
    // l'écran de connexion par téléphone reste accessible (build client
    // périmé, deep link) — évite un "code envoyé" silencieux qui n'arrive
    // jamais.
    test('code dédié → message clair (warning)', () {
      const error = ServerException('unavailable', 'sms-otp-disabled');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Indisponible');
      expect(p.message, contains('téléphone'));
      expect(p.severity, ErrorSeverity.warning);
    });

    test('isKnown reconnaît le code', () {
      const error = ServerException('unavailable', 'sms-otp-disabled');
      expect(ErrorCatalog.isKnown(error), isTrue);
    });
  });

  group('ErrorCatalog — negotiation/commission-charge-failed', () {
    // Le backend renvoie un 422 (ValidationException) avec ce code quand la
    // commission n'a pas pu être prélevée au voyageur (wallet vide + carte
    // refusée) lors de la finalisation d'un accord cash.
    test('code dédié → message clair (critical)', () {
      const error = ValidationException(
        'commission charge failed',
        code: 'negotiation/commission-charge-failed',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Accord non validé');
      expect(p.message, contains('commission'));
      expect(p.message, contains("L'accord n'est pas validé"));
      expect(p.severity, ErrorSeverity.critical);
    });

    test('isKnown reconnaît le code', () {
      const error = ValidationException(
        'peu importe',
        code: 'negotiation/commission-charge-failed',
      );
      expect(ErrorCatalog.isKnown(error), isTrue);
    });
  });

  group('ErrorCatalog — firebase-* (connexion par numéro)', () {
    // RÉGRESSION : AuthBloc._friendlyFirebaseError générait des codes
    // ('code-expired', 'code-incorrect', 'too-many-attempts') identiques à
    // ceux déjà utilisés par la confirmation de livraison — un OTP expiré
    // affichait « Demande à l'expéditeur d'en générer un nouveau », un
    // message trompeur en plein flux de connexion. Les codes Firebase sont
    // maintenant préfixés `firebase-` et n'entrent plus en collision.
    test('firebase-code-expired reste distinct du code-expired livraison', () {
      const firebaseError = NetworkException(
        'peu importe',
        code: 'firebase-code-expired',
      );
      const deliveryError = NetworkException(
        'peu importe',
        code: 'code-expired',
      );

      final firebasePresentation = ErrorCatalog.lookup(firebaseError);
      final deliveryPresentation = ErrorCatalog.lookup(deliveryError);

      expect(firebasePresentation.message, contains('nouveau code'));
      expect(deliveryPresentation.message, contains('expéditeur'));
      expect(firebasePresentation.message, isNot(contains('expéditeur')));
    });

    test('code Firebase générique inconnu → entrée dédiée, pas "Erreur '
        'réseau"', () {
      const error = NetworkException(
        'peu importe',
        code: 'firebase-auth-error',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.title, isNot('Erreur réseau'));
    });
  });
}
