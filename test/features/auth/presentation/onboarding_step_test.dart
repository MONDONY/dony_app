import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un utilisateur dont chaque fait serveur se pose champ par champ, pour tester
/// une étape à la fois sans construire sept fixtures presque identiques.
///
/// `roles`/`status` ne font pas partie des faits testés par ce fichier mais
/// sont requis par `UserModel` : on les fixe une fois pour toutes, comme le
/// fait déjà `create_bid_negotiation_test.dart`.
UserModel _user({
  String? country,
  String kycStatus = 'NOT_STARTED',
  bool hasName = false,
  String stripeAccountStatus = 'NOT_CREATED',
  DateTime? onboardingSeenAt,
}) => UserModel(
  id: 'u1',
  roles: const [],
  status: 'ACTIVE',
  country: country,
  kycStatus: kycStatus,
  firstName: hasName ? 'Awa' : null,
  lastName: hasName ? 'Diallo' : null,
  stripeAccountStatus: stripeAccountStatus,
  onboardingSeenAt: onboardingSeenAt,
);

const _connectOk = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);
const _connectUnavailable = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED', connectAvailableInCountry: false),
);
const _connectDone = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

void main() {
  group('onboardingSteps — le parrainage n\'entre jamais dans le décompte', () {
    test('pays couvert par Stripe → cinq étapes, adresse avant identité (ordre '
        'du parcours réel, pas celui de la spec §2)', () {
      expect(onboardingSteps(_connectOk), const [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.personalInfo,
        OnboardingStep.identity,
        OnboardingStep.payouts,
      ]);
    });

    test('pays non couvert → quatre étapes, 4/4 réellement atteignable', () {
      expect(onboardingSteps(_connectUnavailable), const [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.personalInfo,
        OnboardingStep.identity,
      ]);
    });

    test('statut non chargé → optimiste, le segment n\'est jamais perdu '
        'par accident réseau', () {
      expect(onboardingSteps(const StripeAccountInitial()).length, 5);
      expect(onboardingSteps(const StripeAccountLoading()).length, 5);
      expect(onboardingSteps(const StripeAccountLoadError()).length, 5);
    });
  });

  group('nextStep — une combinaison d\'états par test', () {
    test('1. consentement jamais répondu → consent', () {
      expect(
        nextStep(
          user: _user(country: 'FR'),
          stripe: _connectOk,
          analyticsAnswered: false,
        ),
        OnboardingStep.consent,
      );
    });

    test('2. pays absent → country', () {
      expect(
        nextStep(user: _user(), stripe: _connectOk, analyticsAnswered: true),
        OnboardingStep.country,
      );
    });

    test('3. adresse de résidence absente → address (avant identité, ordre '
        'du parcours réel)', () {
      expect(
        nextStep(
          user: _user(country: 'FR', kycStatus: 'PENDING'),
          stripe: _connectOk,
          analyticsAnswered: true,
        ),
        OnboardingStep.personalInfo,
      );
    });

    test('4. identité non vérifiée → identity', () {
      expect(
        nextStep(
          user: _user(country: 'FR', kycStatus: 'PENDING', hasName: true),
          stripe: _connectOk,
          analyticsAnswered: true,
        ),
        OnboardingStep.identity,
      );
    });

    test('5. compte de paiement incomplet → payouts', () {
      expect(
        nextStep(
          user: _user(country: 'FR', kycStatus: 'VERIFIED', hasName: true),
          stripe: _connectOk,
          analyticsAnswered: true,
        ),
        OnboardingStep.payouts,
      );
    });

    test('6. pays hors couverture Stripe → null, l\'étape paiements n\'existe '
        'pas pour lui', () {
      expect(
        nextStep(
          user: _user(country: 'SN', kycStatus: 'VERIFIED', hasName: true),
          stripe: _connectUnavailable,
          analyticsAnswered: true,
        ),
        isNull,
      );
    });

    test('7. tout est fait → null', () {
      expect(
        nextStep(
          user: _user(
            country: 'FR',
            kycStatus: 'VERIFIED',
            hasName: true,
            stripeAccountStatus: 'ONBOARDING_COMPLETE',
          ),
          stripe: _connectDone,
          analyticsAnswered: true,
        ),
        isNull,
      );
    });

    test('8. utilisateur non chargé → aucun fait serveur connu', () {
      expect(
        nextStep(user: null, stripe: _connectOk, analyticsAnswered: false),
        OnboardingStep.consent,
      );
      expect(
        nextStep(user: null, stripe: _connectOk, analyticsAnswered: true),
        OnboardingStep.country,
      );
    });

    test('9. le pays fraîchement choisi vient du repli : POST /auth/register '
        'n\'écrit pas users.country', () {
      expect(
        nextStep(
          user: _user(kycStatus: 'VERIFIED'),
          stripe: _connectOk,
          analyticsAnswered: true,
          countryFallback: 'FR',
        ),
        OnboardingStep.personalInfo,
      );
    });

    test('un pays vide ne vaut pas un pays', () {
      expect(
        nextStep(
          user: _user(country: ''),
          stripe: _connectOk,
          analyticsAnswered: true,
          countryFallback: '  ',
        ),
        OnboardingStep.country,
      );
    });

    test(
      'le statut Stripe du UserModel sert tant que le bloc n\'a pas chargé',
      () {
        expect(
          nextStep(
            user: _user(
              country: 'FR',
              kycStatus: 'VERIFIED',
              hasName: true,
              stripeAccountStatus: 'ONBOARDING_COMPLETE',
            ),
            stripe: const StripeAccountInitial(),
            analyticsAnswered: true,
          ),
          isNull,
        );
      },
    );

    test('onboardingSeenAt ne court-circuite jamais nextStep : ce garde-fou '
        'anti-boucle vit uniquement dans resolvePostSignupRoute '
        '(post_signup_route_test.dart), jamais ici — sinon nextStep '
        'contredirait onboardingProgress et la carte de reprise (lot 4) ne '
        'disparaîtrait jamais', () {
      expect(
        nextStep(
          user: _user(onboardingSeenAt: DateTime(2026, 8, 22)),
          stripe: _connectOk,
          analyticsAnswered: true,
        ),
        OnboardingStep.country,
      );
      expect(
        nextStep(
          user: _user(
            country: 'FR',
            kycStatus: 'VERIFIED',
            hasName: true,
            stripeAccountStatus: 'ONBOARDING_COMPLETE',
            onboardingSeenAt: DateTime(2026, 8, 22),
          ),
          stripe: _connectDone,
          analyticsAnswered: true,
        ),
        isNull, // ici, null parce que tout est réellement fait — pas parce
        // que onboardingSeenAt est posé.
      );
    });
  });

  group('OnboardingStep — énumération fermée', () {
    test(
      'chaque étape porte un wireName snake_case et une route existante',
      () {
        expect(OnboardingStep.consent.wireName, 'consent');
        expect(OnboardingStep.country.wireName, 'country');
        expect(OnboardingStep.identity.wireName, 'identity');
        expect(OnboardingStep.personalInfo.wireName, 'personal_info');
        expect(OnboardingStep.payouts.wireName, 'payouts');

        expect(OnboardingStep.consent.route, '/auth/analytics-consent');
        expect(OnboardingStep.country.route, '/auth/country-selection');
        expect(OnboardingStep.identity.route, '/kyc/verify');
        expect(OnboardingStep.personalInfo.route, '/auth/personal-info');
        expect(OnboardingStep.payouts.route, '/payments/onboarding');
      },
    );
  });

  group('onboardingProgress — ce que la jauge doit montrer', () {
    test('dans le parcours, la jauge donne la position : tout ce qui est '
        'derrière l\'écran courant est plein, l\'étape en cours à moitié', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.identity,
      );

      expect(p.total, 5);
      expect(p.segments, const [
        DonyGaugeSegment.done, // consentement
        DonyGaugeSegment.done, // pays
        DonyGaugeSegment.done, // adresse — derrière l'écran courant
        DonyGaugeSegment.current, // identité
        DonyGaugeSegment.todo, // paiements
      ]);
    });

    test('une étape passée compte comme franchie dans le parcours — le '
        'compteur suit la position, pas le remplissage', () {
      // Retour utilisateur : un compteur qui stagne à 2/5 sur l'identité
      // après avoir passé l'adresse se lit comme un parcours cassé. La
      // position avance même quand une étape a été passée.
      final p = onboardingProgress(
        user: _user(),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.personalInfo,
      );

      expect(p.segments, const [
        DonyGaugeSegment.done,
        DonyGaugeSegment.done, // pays passé : franchi positionnellement
        DonyGaugeSegment.current,
        DonyGaugeSegment.todo,
        DonyGaugeSegment.todo,
      ]);
    });

    test('parrainage (hors décompte) : position ancrée après l\'adresse, '
        'aucun segment à moitié', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
        reachedPast: OnboardingStep.personalInfo,
      );

      expect(p.current, isNull);
      // Trois segments pleins (consentement, pays, adresse franchis), soit
      // « 3 / 5 · Parrainage » au libellé de la jauge.
      expect(p.segments, const [
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
        DonyGaugeSegment.todo,
        DonyGaugeSegment.todo,
      ]);
    });

    test('hors parcours (carte de reprise du profil) : faits accomplis — une '
        'étape passée reste vide, passer n\'est pas terminer', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
      );

      expect(p.current, isNull);
      expect(p.doneCount, 2);
      expect(p.segments, const [
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
        DonyGaugeSegment.todo, // adresse jamais remplie : vide au profil
        DonyGaugeSegment.todo,
        DonyGaugeSegment.todo,
      ]);
    });

    test('pays hors couverture Stripe → quatre segments', () {
      final p = onboardingProgress(
        user: _user(country: 'SN', kycStatus: 'VERIFIED', hasName: true),
        stripe: _connectUnavailable,
        analyticsAnswered: true,
      );

      expect(p.total, 4);
      expect(p.doneCount, 4);
      expect(p.segments, const [
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
        DonyGaugeSegment.done,
      ]);
    });

    test('l\'écran courant est toujours « en cours », même si son fait '
        'serveur existe déjà — la position prime dans le parcours', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.country,
      );

      expect(p.segments[1], DonyGaugeSegment.current);
    });

    test('onboardingSeenAt posé n\'efface pas la progression réelle — la carte '
        'de reprise (lot 4) doit pouvoir compter dessus pour disparaître '
        'exactement quand nextStep rend null', () {
      final p = onboardingProgress(
        user: _user(country: 'FR', onboardingSeenAt: DateTime(2026, 8, 22)),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.identity,
      );

      expect(p.doneCount, 2);
      expect(p.segments[0], DonyGaugeSegment.done);
      expect(p.segments[1], DonyGaugeSegment.done);
    });
  });

  group('OnboardingStep.displayLabel — noms montrés à l\'utilisateur', () {
    test('chaque étape a un nom, fermé et en français', () {
      expect(OnboardingStep.consent.displayLabel, 'Confidentialité');
      expect(OnboardingStep.country.displayLabel, 'Pays');
      expect(OnboardingStep.personalInfo.displayLabel, 'Vos infos');
      expect(OnboardingStep.identity.displayLabel, 'Identité');
      expect(OnboardingStep.payouts.displayLabel, 'Paiements');
    });
  });

  group('OnboardingProgress.next — écran de parrainage, seul point '
      'du parcours où plusieurs étapes peuvent rester à faire', () {
    test('identité et paiements restants → identity (le premier des deux)', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
        },
      );

      expect(progress.next, OnboardingStep.identity);
    });

    test('tout est fait → null, le parrainage clôt réellement le parcours', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        },
      );

      expect(progress.next, isNull);
    });
  });

  group('OnboardingProgress.nextAfter — le parcours ne revient jamais en '
      'arrière sur une étape passée', () {
    // Régression trouvée en test de bout en bout sur device : l'utilisateur
    // passe l'étape adresse, arrive au parrainage, et `next` le renvoyait sur
    // l'adresse — qu'il venait justement de passer. Boucle sans fin, le
    // parcours ne pouvait plus se terminer.
    test('adresse passée → identity, jamais un retour sur address', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        // L'adresse est absente de `done` : passée, pas remplie.
        done: {OnboardingStep.consent, OnboardingStep.country},
      );

      expect(progress.next, OnboardingStep.personalInfo, reason: 'next boucle');
      expect(
        progress.nextAfter(OnboardingStep.personalInfo),
        OnboardingStep.identity,
      );
    });

    test('identité passée → null : les paiements restent verrouillés', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {OnboardingStep.consent, OnboardingStep.country},
      );

      // Stripe Connect refuse un compte non vérifié : y conduire n'offrirait
      // qu'un 422. Le parcours s'arrête là, l'accueil prend la suite.
      expect(progress.nextAfter(OnboardingStep.identity), isNull);
    });

    test('identité vérifiée → payouts devient atteignable', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.identity,
        },
      );

      expect(
        progress.nextAfter(OnboardingStep.identity),
        OnboardingStep.payouts,
      );
    });

    test('plus rien après l\'adresse → null, le parcours se termine', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
        ],
        done: {OnboardingStep.identity},
      );

      expect(progress.nextAfter(OnboardingStep.identity), isNull);
    });
  });

  group('OnboardingProgress.routeAfter — navigation positionnelle des '
      'écrans identité et paiements (terminer ou passer mène au même '
      'endroit)', () {
    const fiveSteps = OnboardingProgress(
      steps: [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.personalInfo,
        OnboardingStep.identity,
        OnboardingStep.payouts,
      ],
      done: {OnboardingStep.identity},
    );

    test(
      'après identité vérifiée → /payments/onboarding, marqueur compris',
      () {
        // Sans `?from=onboarding`, le routeur construit l'écran des paiements
        // avec `progress: null` : ni jauge, ni suite. Le parcours s'arrêtait là
        // en silence (régression trouvée en test sur device).
        expect(
          fiveSteps.routeAfter(OnboardingStep.identity),
          '/payments/onboarding?from=onboarding',
        );
      },
    );

    test('après identité passée → /home : les paiements sont verrouillés', () {
      const skipped = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {},
      );

      expect(skipped.routeAfter(OnboardingStep.identity), '/home');
    });

    test('après identité, paiements non applicable (pays hors couverture '
        'Stripe) → /home', () {
      const fourSteps = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.personalInfo,
          OnboardingStep.identity,
        ],
        done: {OnboardingStep.identity},
      );

      expect(fourSteps.routeAfter(OnboardingStep.identity), '/home');
    });

    test('après paiements (dernière étape) → /home', () {
      expect(fiveSteps.routeAfter(OnboardingStep.payouts), '/home');
    });

    test('après le pays → vos infos, route brute (écran sans double entrée)', () {
      expect(
        fiveSteps.routeAfter(OnboardingStep.country),
        '/auth/personal-info',
      );
    });
  });

  group('OnboardingStep.onboardingRoute — marqueur d\'entrée du parcours', () {
    test('identité et paiements portent ?from=onboarding', () {
      expect(
        OnboardingStep.identity.onboardingRoute,
        '/kyc/verify?from=onboarding',
      );
      expect(
        OnboardingStep.payouts.onboardingRoute,
        '/payments/onboarding?from=onboarding',
      );
    });

    test('les étapes sans double entrée gardent leur route brute', () {
      for (final step in [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.personalInfo,
      ]) {
        expect(step.onboardingRoute, step.route, reason: step.wireName);
      }
    });
  });

  group('OnboardingProgress.completing — corrige un instantané périmé', () {
    // `done` est figé à la construction de l'écran. L'écran d'identité, lui,
    // navigue APRÈS avoir fait vérifier l'identité : sans cette correction, il
    // se croirait encore verrouillé et enverrait à l'accueil.
    const beforeVerification = OnboardingProgress(
      steps: [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.personalInfo,
        OnboardingStep.identity,
        OnboardingStep.payouts,
      ],
      done: {OnboardingStep.consent},
    );

    test('déverrouille les paiements juste après la vérification', () {
      expect(beforeVerification.payoutsUnlocked, isFalse);
      expect(beforeVerification.routeAfter(OnboardingStep.identity), '/home');

      final after = beforeVerification.completing(OnboardingStep.identity);

      expect(after.payoutsUnlocked, isTrue);
      expect(
        after.routeAfter(OnboardingStep.identity),
        '/payments/onboarding?from=onboarding',
      );
    });

    test('ne touche pas à l\'original', () {
      beforeVerification.completing(OnboardingStep.identity);

      expect(beforeVerification.done, {OnboardingStep.consent});
    });
  });
}
