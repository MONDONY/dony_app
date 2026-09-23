import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

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

  group('ErrorCatalog — invalid-phone-number', () {
    // Twilio refuse le numéro (21211) : le back répond 422 au lieu d'un
    // « code envoyé » fantôme. Le message doit orienter vers la saisie.
    test('code dédié → message clair sur le numéro (warning)', () {
      const error = ValidationException(
        'Ce numéro n\'est pas joignable par SMS',
        code: 'invalid-phone-number',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Numéro injoignable');
      expect(p.message, contains('indicatif'));
      expect(p.severity, ErrorSeverity.warning);
    });

    test('isKnown reconnaît le code', () {
      const error = ValidationException('x', code: 'invalid-phone-number');
      expect(ErrorCatalog.isKnown(error), isTrue);
    });
  });

  group('ErrorCatalog — depart-already-scanned', () {
    // Second scan DEPART : 409 du back. Pas une erreur pour l'utilisateur,
    // juste une étape déjà faite.
    test('code dédié → info, pas warning', () {
      const error = ConflictException(
        'Le départ de ce colis a déjà été scanné',
        code: 'depart-already-scanned',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.title, 'Départ déjà scanné');
      expect(p.severity, ErrorSeverity.info);
    });

    test('isKnown reconnaît le code', () {
      const error = ConflictException('x', code: 'depart-already-scanned');
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
        'bid-already-paid',
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
      for (final code in ['payment-already-completed', 'bid-already-paid']) {
        final p = ErrorCatalog.lookup(ConflictException('x', code: code));

        expect(p.severity, isNot(ErrorSeverity.critical), reason: code);
      }
    });
  });

  // Regression : ces codes n avaient aucune entree et retombaient sur le
  // generique « Donnees invalides ». Le message du serveur, qui disait
  // pourtant quoi faire, n atteignait jamais l utilisateur.
  group('ErrorCatalog — rechargement du portefeuille', () {
    const codes = [
      'wallet-topup-stripe-error',
      'payment-method-unavailable-for-currency',
      'unsupported-currency',
    ];

    test('chaque code a une entree dediee, jamais le generique', () {
      for (final code in codes) {
        final error = ValidationException('detail brut backend', code: code);

        expect(
          ErrorCatalog.isKnown(error),
          isTrue,
          reason: '$code doit avoir une entree dediee',
        );

        final p = ErrorCatalog.lookup(error);
        // Titre generique compare AVEC ses accents : sans eux l assertion
        // etait vacante et n aurait jamais pu echouer.
        expect(
          p.title,
          isNot(ErrorCatalog.lookup(const ValidationException('x')).title),
          reason: '$code ne doit plus afficher le titre generique',
        );
        // Le detail brut du backend ne doit jamais atteindre l utilisateur.
        expect(p.message, isNot(contains('detail brut backend')));
        expect(p.message, isNot(contains('—')));
      }
    });

    // Tache 7 (pawaPay) : ce code est desormais leve aussi bien pour la
    // carte (BidService/PaymentService) que pour le mobile money
    // (BidService.resolvePaymentMethodFor, branche MOBILE_MONEY) quand la
    // devise du trajet ne supporte pas le moyen choisi. Le message ne peut
    // donc plus presumer d'un moyen de paiement precis ni orienter vers les
    // especes.
    test('devise incompatible : message generique au moyen de paiement', () {
      final p = ErrorCatalog.lookup(
        const ValidationException(
          'x',
          code: 'payment-method-unavailable-for-currency',
        ),
      );

      expect(
        p.message,
        "Ce moyen de paiement n'est pas proposé dans la devise de ce "
        'trajet.',
      );
      expect(p.severity, isNot(ErrorSeverity.critical));
    });
  });

  // Tache 7 : catalogue d'erreurs du rail mobile money (pawaPay), compte de
  // versement voyageur (mobile-money-account-*) et paiement d'un bid par
  // l'expediteur. Chaque code est verifie avec le type d'exception que
  // l'interceptor produit reellement pour son statut HTTP backend :
  // 422 -> ValidationException, 409 -> ConflictException, 502 -> ServerException
  // (mappe sur >=500).
  group('ErrorCatalog — mobile money (pawaPay)', () {
    const codes409 = {
      'mobile-money-payment-not-pending',
      'mobile-money-operation-in-progress',
    };
    const codes5xx = {'mobile-money-provider-unavailable'};

    AppException buildError(String code) {
      if (codes409.contains(code)) {
        return ConflictException('detail brut backend', code: code);
      }
      if (codes5xx.contains(code)) {
        return ServerException('detail brut backend', code);
      }
      return ValidationException('detail brut backend', code: code);
    }

    // code -> [titre attendu, message attendu]. Textes adaptes au
    // tutoiement (convention dominante du catalogue et des ecrans) par
    // rapport au brief de la tache 7, qui vouvoyait a tort : correction
    // demandee en relecture de la tache 7.
    const attendus = <String, List<String>>{
      'mobile-money-disabled': [
        'Mobile money indisponible',
        "Le paiement mobile money n'est pas ouvert pour le moment. "
            'Choisis un autre moyen de paiement.',
      ],
      'mobile-money-phone-required': [
        'Numéro manquant',
        'Indique le numéro mobile money à utiliser pour continuer.',
      ],
      // 'mobile-money-account-unsupported' est retire de cette boucle : ce
      // code fait desormais exception (voir le groupe dedie plus bas), le
      // detail brut backend y est attendu tel quel pour un message
      // exploitable, ce que cette boucle interdit explicitement.
      'mobile-money-account-required': [
        'Compte de versement requis',
        "Active ton versement mobile money avant d'accepter cette offre.",
      ],
      'mobile-money-currency-mismatch': [
        'Devise différente',
        "Ton compte de versement mobile money n'est pas dans la devise "
            'de ce trajet.',
      ],
      'mobile-money-not-available': [
        'Mobile money non proposé',
        "Ce voyageur n'accepte pas le paiement mobile money.",
      ],
      'payment-method-unavailable-for-currency': [
        'Moyen de paiement indisponible',
        "Ce moyen de paiement n'est pas proposé dans la devise de ce "
            'trajet.',
      ],
      'mobile-money-payer-unsupported': [
        'Numéro non pris en charge',
        'Vérifie le numéro qui doit payer, ou essaie avec un autre '
            'numéro.',
      ],
      'mobile-money-invalid-phone': [
        'Numéro non reconnu',
        "Ce numéro n'est reconnu par aucun opérateur mobile money. "
            'Vérifie-le et réessaie.',
      ],
      'mobile-money-deposit-rejected': [
        'Paiement refusé',
        "L'opérateur a refusé la demande de paiement. Réessaie, "
            'éventuellement avec un autre numéro.',
      ],
      'mobile-money-payment-expired': [
        'Délai dépassé',
        'Le délai de paiement de 30 minutes est passé. Refais une offre '
            'au voyageur.',
      ],
      'mobile-money-payment-not-pending': [
        'Paiement déjà traité',
        "Ce paiement n'est plus en attente.",
      ],
      'mobile-money-operation-in-progress': [
        'Opération en cours',
        'Une opération mobile money est déjà en cours pour cet envoi. '
            'Patiente quelques instants.',
      ],
      'mobile-money-provider-unavailable': [
        'Service indisponible',
        'Le service mobile money ne répond pas. Réessaie dans quelques '
            'minutes.',
      ],
      'invalid-payment-method': [
        'Moyen de paiement invalide',
        "Ce moyen de paiement n'est pas reconnu. Mets l'application à "
            'jour.',
      ],
    };

    // Titres generiques : un code dedie ne doit jamais en afficher un.
    final genericTitles = [
      ErrorCatalog.lookup(const ValidationException('x')).title,
      ErrorCatalog.lookup(const ConflictException('x')).title,
      ErrorCatalog.lookup(const ServerException('x')).title,
    ];

    for (final entry in attendus.entries) {
      final code = entry.key;
      final title = entry.value[0];
      final message = entry.value[1];

      test('$code : titre et message dedies', () {
        final error = buildError(code);
        final p = ErrorCatalog.lookup(error);

        expect(ErrorCatalog.isKnown(error), isTrue, reason: code);
        expect(p.title, title, reason: code);
        expect(p.message, message, reason: code);
        expect(p.title, isNot(anyOf(genericTitles)), reason: code);
        // Le detail brut du backend ne doit jamais atteindre l'utilisateur,
        // et aucun texte affiche ne porte de tiret cadratin.
        expect(p.message, isNot(contains('detail brut backend')));
        expect(p.message, isNot(contains('—')));
      });
    }

    test('quatorze codes couverts (liste du brief moins l exception)', () {
      expect(attendus.length, 14);
    });
  });

  // 'mobile-money-account-unsupported' : le back renvoie un detail redige
  // pour l'utilisateur (devise du portefeuille, reseau indisponible...),
  // plus precis que le texte fixe du catalogue. Precedent : la boucle
  // ci-dessus verifie que le detail brut backend est toujours masque, ce
  // groupe verifie l'exception controlee a cette regle, pour ce seul code.
  group('ErrorCatalog — mobile-money-account-unsupported : detail serveur', () {
    const genericTitle = 'Numéro non pris en charge';
    const genericMessage =
        "Ton numéro n'est pas rattaché à un opérateur mobile money "
        'compatible, ou sa devise ne correspond pas à ta zone.';

    test('detail serveur exploitable → affiche tel quel', () {
      const error = ValidationException(
        'Réseau Wave indisponible pour ce numéro.',
        code: 'mobile-money-account-unsupported',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.message, 'Réseau Wave indisponible pour ce numéro.');
      expect(p.title, genericTitle);
      expect(p.severity, ErrorSeverity.warning);
    });

    test('message vide → texte generique du catalogue', () {
      const error = ValidationException(
        '',
        code: 'mobile-money-account-unsupported',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.message, genericMessage);
      expect(p.title, genericTitle);
    });

    test('message technique echappe → texte generique du catalogue', () {
      const error = ValidationException(
        'DioException [bad response]: This exception was thrown because '
        'the response has a status code of 422',
        code: 'mobile-money-account-unsupported',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.message, genericMessage);
      expect(p.title, genericTitle);
    });

    test('autre code du catalogue (ensemble ferme) → texte generique inchange '
        'malgre un detail serveur exploitable', () {
      const error = ValidationException(
        'Un detail parfaitement exploitable envoye par le back.',
        code: 'mobile-money-account-required',
      );

      final p = ErrorCatalog.lookup(error);

      expect(
        p.message,
        "Active ton versement mobile money avant d'accepter cette offre.",
      );
      expect(p.title, 'Compte de versement requis');
    });
  });
  // Tache 6 (tour 1) : recharge du portefeuille par mobile money
  // (WalletMobileMoneyTopupService). Principe retenu en relecture : le
  // detail serveur n'est affiche que lorsqu'il porte une information que
  // l'app ne possede pas deja (bornes de montant, operateurs couverts) ;
  // sinon l'app ecrit son propre texte, en tutoiement.
  group('ErrorCatalog — recharge mobile money : detail serveur reserve aux '
      'codes qui apportent une information', () {
    test('topup-amount-out-of-range : detail serveur exploitable → affiche tel '
        'quel (bornes reelles dans la devise de l operateur)', () {
      const error = ValidationException(
        'Entre 1 000 FCFA et 3 000 000 FCFA par recharge, sans centimes.',
        code: 'topup-amount-out-of-range',
      );

      final p = ErrorCatalog.lookup(error);

      expect(
        p.message,
        'Entre 1 000 FCFA et 3 000 000 FCFA par recharge, sans centimes.',
      );
      expect(p.title, 'Montant hors limites');
      expect(p.severity, ErrorSeverity.warning);
    });

    test('topup-amount-out-of-range : detail vide → texte generique du '
        'catalogue', () {
      const error = ValidationException('', code: 'topup-amount-out-of-range');

      final p = ErrorCatalog.lookup(error);

      expect(
        p.message,
        'Ce montant ne respecte pas les limites de recharge autorisées. '
        'Ajuste le montant puis réessaie.',
      );
    });

    test('topup-phone-unsupported : detail serveur exploitable → affiche tel '
        'quel (operateurs reellement couverts pour ce numero)', () {
      const error = ValidationException(
        'Réseau Orange Money indisponible pour ce numéro.',
        code: 'topup-phone-unsupported',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.message, 'Réseau Orange Money indisponible pour ce numéro.');
      expect(p.title, 'Numéro non pris en charge');
    });

    test('topup-phone-unsupported : detail technique echappe → texte generique '
        'du catalogue', () {
      const error = ValidationException(
        'DioException [bad response]: status code 422',
        code: 'topup-phone-unsupported',
      );

      final p = ErrorCatalog.lookup(error);

      expect(
        p.message,
        'Ce numéro n\'est pas exploitable pour une recharge mobile '
        'money. Vérifie-le ou essaie avec un autre numéro.',
      );
    });

    test('topup-already-pending : texte app en tutoiement, jamais le detail '
        'serveur (vouvoiement) meme exploitable', () {
      const error = ValidationException(
        'Une recharge est déjà en attente de validation sur votre '
        'téléphone.',
        code: 'topup-already-pending',
      );

      final p = ErrorCatalog.lookup(error);

      expect(
        p.message,
        'Une recharge est déjà en cours. Valide-la sur ton téléphone, ou '
        'attends qu\'elle expire avant d\'en lancer une nouvelle.',
      );
      expect(p.message, isNot(contains('votre')));
      // Aucun écran ne permet d'annuler une recharge : ne jamais le demander.
      expect(p.message, isNot(contains('annule')));
      expect(p.title, 'Recharge déjà en cours');
    });

    test('topup-phone-required : texte app en tutoiement, jamais le detail '
        'serveur (vouvoiement) meme exploitable', () {
      const error = ValidationException(
        'Indiquez le numéro mobile money qui paie la recharge.',
        code: 'topup-phone-required',
      );

      final p = ErrorCatalog.lookup(error);

      expect(p.message, 'Indique le numéro qui va payer la recharge.');
      expect(p.message, isNot(contains('Indiquez')));
      expect(p.title, 'Numéro manquant');
    });

    // Les autres codes du meme service ont deja un texte fixe, en tutoiement
    // ou neutre (aucun pronom) : verifie ici pour ne rien laisser en
    // vouvoiement sans le savoir.
    const autresCodesEtMessages = <String, String>{
      'mobile-money-invalid-phone':
          "Ce numéro n'est reconnu par aucun opérateur mobile money. "
          'Vérifie-le et réessaie.',
      'mobile-money-disabled':
          "Le paiement mobile money n'est pas ouvert pour le moment. "
          'Choisis un autre moyen de paiement.',
      'topup-not-found':
          'Cette recharge n\'existe plus ou son lien a '
          'expiré.',
    };

    autresCodesEtMessages.forEach((code, message) {
      test('$code : entree existante et coherente avec le tutoiement', () {
        final error = ValidationException('detail brut backend', code: code);

        expect(ErrorCatalog.isKnown(error), isTrue, reason: code);

        final p = ErrorCatalog.lookup(error);
        expect(p.message, message, reason: code);
        expect(p.message, isNot(contains('vous')), reason: code);
        expect(p.message, isNot(contains('votre')), reason: code);
        expect(p.message, isNot(contains('—')), reason: code);
      });
    });
  });

  // Lot 2 mobile money sur colis : codes emis par le back sur le depot d'un fil
  // de negociation (POST /negotiations/{id}/mobile-money/*) et par la
  // resolution du moyen de paiement (PR back #295).
  group('ErrorCatalog — depot mobile money d un fil de negociation', () {
    const attendus = <String, (String, String, ErrorSeverity)>{
      'negotiation/not-awaiting-deposit': (
        'Aucun dépôt en cours',
        'Ce fil n\'attend pas de paiement mobile money.',
        ErrorSeverity.info,
      ),
      'negotiation/deposit-in-flight': (
        'Paiement en cours de validation',
        'Ton opérateur traite encore le paiement, patiente quelques instants.',
        ErrorSeverity.warning,
      ),
      'negotiation/traveler-cannot-receive-mobile-money': (
        'Mobile money indisponible',
        'Le voyageur ne peut pas recevoir de versement mobile money dans '
            'cette devise. Choisis un autre moyen de paiement.',
        ErrorSeverity.warning,
      ),
      'payment-method/not-in-available-set': (
        'Moyen de paiement non proposé',
        'Ce moyen de paiement n\'est pas proposé pour cette offre. '
            'Choisis-en un autre.',
        ErrorSeverity.warning,
      ),
      'payment-method/mobile-money-capability-required': (
        'Mobile money indisponible',
        'Le voyageur n\'a pas de compte de versement mobile money dans '
            'cette devise.',
        ErrorSeverity.warning,
      ),
    };

    final genericTitles = [
      ErrorCatalog.lookup(const ValidationException('x')).title,
      ErrorCatalog.lookup(const ConflictException('x')).title,
      ErrorCatalog.lookup(const NetworkException('x')).title,
    ];

    for (final entry in attendus.entries) {
      final code = entry.key;
      final (title, message, severity) = entry.value;

      test('$code : titre, message et severite dedies', () {
        final error = ConflictException('detail brut backend', code: code);
        final p = ErrorCatalog.lookup(error);

        expect(ErrorCatalog.isKnown(error), isTrue, reason: code);
        expect(p.title, title, reason: code);
        expect(p.message, message, reason: code);
        expect(p.severity, severity, reason: code);
        expect(p.title, isNot(anyOf(genericTitles)), reason: code);
        expect(p.message, isNot(contains('detail brut backend')));
        expect(p.message, isNot(contains('\u2014')));
      });
    }
  });

  group('ErrorCatalog — anglais', () {
    final en = lookupAppLocalizations(AppL10n.en);
    final fr = lookupAppLocalizations(AppL10n.fr);

    test('currency-mismatch en anglais', () {
      const error = NetworkException('ignored', code: 'currency-mismatch');
      final p = ErrorCatalog.lookup(error, l10n: en);
      expect(p.title, 'Different currency');
      expect(
        p.message,
        'This trip is no longer available in your currency. '
        'Change your country in Settings to see it.',
      );
      expect(p.severity, ErrorSeverity.warning);
    });

    test('violations du serveur gardées, titre traduit', () {
      const error = ValidationException(
        'Validation failed',
        errors: {
          'x': ['Server text'],
        },
      );
      final p = ErrorCatalog.lookup(error, l10n: en);
      expect(p.title, 'Invalid information');
      expect(p.message, 'Server text');
    });

    test('erreur inconnue → générique anglais', () {
      expect(ErrorCatalog.lookup(null, l10n: en).title, 'Something went wrong');
    });

    test('sans l10n : suit Intl.defaultLocale', () {
      useEnglish();
      const error = NetworkException('ignored', code: 'currency-mismatch');
      expect(ErrorCatalog.lookup(error).title, 'Different currency');
    });

    test('chaque code a une traduction anglaise distincte du français', () {
      for (final code in ErrorCatalog.debugCodes) {
        final error = NetworkException('ignored', code: code);
        final pEn = ErrorCatalog.lookup(error, l10n: en);
        final pFr = ErrorCatalog.lookup(error, l10n: fr);
        expect(
          pEn.title != pFr.title || pEn.message != pFr.message,
          isTrue,
          reason: code,
        );
      }
    });
  });
}
