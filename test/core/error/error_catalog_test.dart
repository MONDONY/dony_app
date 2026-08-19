import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:flutter/material.dart';
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

  group('ErrorCatalog — currency-mismatch', () {
    test('code dédié → message, sévérité et icône dédiés', () {
      const error = NetworkException('ignored', code: 'currency-mismatch');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Devise différente');
      expect(
        p.message,
        'Ce trajet n\'est plus disponible dans ta devise. '
        'Change de pays dans Réglages pour le voir.',
      );
      expect(p.severity, ErrorSeverity.warning);
      expect(p.icon, Icons.currency_exchange_rounded);
    });
  });

  group('ErrorCatalog — pays', () {
    // Sans entrée dédiée, ces trois 422 tombaient dans le message générique :
    // le voyageur ne pouvait pas deviner qu'il devait renseigner son pays.
    test('country-required oriente vers la tuile Pays des Réglages', () {
      const error = NetworkException('ignored', code: 'country-required');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Pays manquant');
      expect(p.message, contains('Réglages'));
      expect(p.message, contains('Préférences'));
      expect(p.severity, ErrorSeverity.warning);
    });

    test('country-locked explique le gel plutôt qu\'un refus opaque', () {
      const error = NetworkException('ignored', code: 'country-locked');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Pays verrouillé');
      expect(p.message, contains('envoi est en cours'));
      expect(p.severity, ErrorSeverity.warning);
    });

    test('country-unsupported invite à choisir un autre pays', () {
      const error = NetworkException('ignored', code: 'country-unsupported');

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Pays non desservi');
      expect(p.message, contains('Yadony'));
      expect(p.severity, ErrorSeverity.warning);
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

  group('ErrorCatalog — parcours de connexion par email', () {
    // Tout code que peut renvoyer EmailOtpController doit avoir son entrée.
    // Deux manquaient et retombaient sur « Quelque chose s'est mal passé de
    // notre côté », qui ne dit ni ce qui a échoué ni quoi faire ensuite.
    const codesEmisParLeBackend = <String>[
      'rate-limit',
      'otp-invalid',
      'otp-expired',
      'otp-attempts-exceeded',
      'email-service-error',
      'firebase-error',
      'email-already-exists',
      'email-already-set',
    ];

    for (final code in codesEmisParLeBackend) {
      test('$code est traduit', () {
        final error = ServerException('peu importe', code);

        expect(
          ErrorCatalog.isKnown(error),
          isTrue,
          reason:
              'le backend émet "$code" : sans entrée, l\'utilisateur voit '
              'un message générique au lieu de la cause réelle',
        );
      });
    }

    test(
      'les codes demandés et les codes mal saisis ne portent pas le même titre',
      () {
        // Un titre commun laissait croire à une erreur de saisie alors que
        // l'utilisateur avait seulement trop cliqué sur « Renvoyer le code ».
        final tropDeCodes = ErrorCatalog.lookup(
          const ServerException('peu importe', 'rate-limit'),
        );
        final tropDEssais = ErrorCatalog.lookup(
          const ServerException('peu importe', 'otp-attempts-exceeded'),
        );

        expect(tropDeCodes.title, isNot(tropDEssais.title));
      },
    );

    test(
      'essais épuisés : le texte n\'invite pas à demander un nouveau code',
      () {
        // Le budget est compté par adresse, pas par code : un renvoi ne le remet
        // pas à zéro et l'utilisateur resterait bloqué en suivant ce conseil.
        final p = ErrorCatalog.lookup(
          const ServerException('peu importe', 'otp-attempts-exceeded'),
        );

        expect(
          p.message.toLowerCase(),
          isNot(contains('demande un nouveau code')),
        );
      },
    );
  });

  group('ErrorCatalog — checkout d\'un accord negocie', () {
    test('les quatre refus du checkout ont un message dedie', () {
      const codes = [
        'bid-not-negotiated',
        'bid-not-awaiting-payment',
        'payment-already-completed',
        'traveler-stripe-invalid',
      ];

      for (final code in codes) {
        final p = ErrorCatalog.lookup(NetworkException('brut', code: code));

        expect(
          ErrorCatalog.isKnown(NetworkException('brut', code: code)),
          isTrue,
          reason: '$code doit avoir une entree dediee',
        );
        // Le detail brut du backend ne doit jamais atteindre l'utilisateur.
        expect(p.message, isNot(contains('brut')));
        // Vouvoiement cote expediteur, et jamais de tiret cadratin.
        expect(p.message, isNot(contains('\u2014')));
      }
    });

    test('accord deja paye n alarme pas', () {
      final p = ErrorCatalog.lookup(
        const ConflictException('x', code: 'payment-already-completed'),
      );

      expect(p.severity, isNot(ErrorSeverity.critical));
    });
  });
}
