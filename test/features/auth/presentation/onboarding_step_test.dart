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
  String? residenceStreet,
  String stripeAccountStatus = 'NOT_CREATED',
  DateTime? onboardingSeenAt,
}) => UserModel(
  id: 'u1',
  roles: const [],
  status: 'ACTIVE',
  country: country,
  kycStatus: kycStatus,
  residenceStreet: residenceStreet,
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
        OnboardingStep.address,
        OnboardingStep.identity,
        OnboardingStep.payouts,
      ]);
    });

    test('pays non couvert → quatre étapes, 4/4 réellement atteignable', () {
      expect(onboardingSteps(_connectUnavailable), const [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.address,
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
        OnboardingStep.address,
      );
    });

    test('4. identité non vérifiée → identity', () {
      expect(
        nextStep(
          user: _user(
            country: 'FR',
            kycStatus: 'PENDING',
            residenceStreet: '12 rue des Lilas',
          ),
          stripe: _connectOk,
          analyticsAnswered: true,
        ),
        OnboardingStep.identity,
      );
    });

    test('5. compte de paiement incomplet → payouts', () {
      expect(
        nextStep(
          user: _user(
            country: 'FR',
            kycStatus: 'VERIFIED',
            residenceStreet: '12 rue des Lilas',
          ),
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
          user: _user(
            country: 'SN',
            kycStatus: 'VERIFIED',
            residenceStreet: '12 rue des Lilas',
          ),
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
            residenceStreet: '12 rue des Lilas',
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
        OnboardingStep.address,
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
              residenceStreet: '12 rue des Lilas',
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
            residenceStreet: '12 rue des Lilas',
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
        expect(OnboardingStep.address.wireName, 'address');
        expect(OnboardingStep.payouts.wireName, 'payouts');

        expect(OnboardingStep.consent.route, '/auth/analytics-consent');
        expect(OnboardingStep.country.route, '/auth/country-selection');
        expect(OnboardingStep.identity.route, '/kyc/verify');
        expect(OnboardingStep.address.route, '/auth/residence-address');
        expect(OnboardingStep.payouts.route, '/payments/onboarding');
      },
    );
  });

  group('onboardingProgress — ce que la jauge doit montrer', () {
    test('une étape faite est pleine, l\'étape en cours est à moitié, '
        'le reste est vide', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.identity,
      );

      expect(p.total, 5);
      expect(p.doneCount, 2);
      expect(p.segments, const [
        DonyGaugeSegment.done, // consentement
        DonyGaugeSegment.done, // pays
        DonyGaugeSegment.todo, // adresse
        DonyGaugeSegment.current, // identité
        DonyGaugeSegment.todo, // paiements
      ]);
    });

    test('une étape passée reste vide — passer n\'est pas terminer', () {
      // L'utilisateur a passé le pays (skip) et se trouve sur l'adresse :
      // le segment « pays » ne doit pas se remplir pour autant.
      final p = onboardingProgress(
        user: _user(),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.address,
      );

      expect(p.segments, const [
        DonyGaugeSegment.done,
        DonyGaugeSegment.todo, // pays passé, donc vide
        DonyGaugeSegment.current,
        DonyGaugeSegment.todo,
        DonyGaugeSegment.todo,
      ]);
    });

    test('sans étape en cours (écran parrainage, hors décompte) aucun segment '
        'n\'est à moitié', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
      );

      expect(p.current, isNull);
      expect(p.segments.contains(DonyGaugeSegment.current), isFalse);
      expect(p.doneCount, 2);
    });

    test('pays hors couverture Stripe → quatre segments', () {
      final p = onboardingProgress(
        user: _user(
          country: 'SN',
          kycStatus: 'VERIFIED',
          residenceStreet: '12 rue des Lilas',
        ),
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

    test('une étape déjà faite reste pleine même si elle est l\'étape '
        'en cours', () {
      final p = onboardingProgress(
        user: _user(country: 'FR'),
        stripe: _connectOk,
        analyticsAnswered: true,
        current: OnboardingStep.country,
      );

      expect(p.segments[1], DonyGaugeSegment.done);
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

  group('OnboardingProgress.next — écran de parrainage, seul point '
      'du parcours où plusieurs étapes peuvent rester à faire', () {
    test('identité et paiements restants → identity (le premier des deux)', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.address,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.address,
        },
      );

      expect(progress.next, OnboardingStep.identity);
    });

    test('tout est fait → null, le parrainage clôt réellement le parcours', () {
      const progress = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.address,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        ],
        done: {
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.address,
          OnboardingStep.identity,
          OnboardingStep.payouts,
        },
      );

      expect(progress.next, isNull);
    });
  });

  group('OnboardingProgress.routeAfter — navigation positionnelle des '
      'écrans identité et paiements (terminer ou passer mène au même '
      'endroit)', () {
    const fiveSteps = OnboardingProgress(
      steps: [
        OnboardingStep.consent,
        OnboardingStep.country,
        OnboardingStep.address,
        OnboardingStep.identity,
        OnboardingStep.payouts,
      ],
      done: {},
    );

    test('après identité, paiements applicable → /payments/onboarding', () {
      expect(
        fiveSteps.routeAfter(OnboardingStep.identity),
        '/payments/onboarding',
      );
    });

    test('après identité, paiements non applicable (pays hors couverture '
        'Stripe) → /home', () {
      const fourSteps = OnboardingProgress(
        steps: [
          OnboardingStep.consent,
          OnboardingStep.country,
          OnboardingStep.address,
          OnboardingStep.identity,
        ],
        done: {},
      );

      expect(fourSteps.routeAfter(OnboardingStep.identity), '/home');
    });

    test('après paiements (dernière étape) → /home', () {
      expect(fiveSteps.routeAfter(OnboardingStep.payouts), '/home');
    });
  });
}
