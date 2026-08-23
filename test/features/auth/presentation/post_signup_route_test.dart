import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

/// `roles`/`status` ne font pas partie des faits testés par ce fichier mais
/// sont requis par `UserModel` : on les fixe une fois pour toutes, comme le
/// fait déjà `onboarding_step_test.dart`.
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

/// Couvre `resolvePostSignupRoute` — la décision de routing après création de
/// compte. Deux responsabilités distinctes, testées séparément :
/// - la réconciliation du consentement analytics avec le backend (régression
///   « réinstall » corrigée avant ce lot, toujours protégée ici) ;
/// - la délégation à [nextStep] (couverte exhaustivement par
///   `onboarding_step_test.dart`) — ici on verrouille seulement que chaque
///   étape se traduit bien par sa route, et le court-circuit
///   `onboardingSeenAt`.
void main() {
  late MockAnalyticsBackend backend;
  late MockAnalyticsConsentRemote remote;
  late MockHiveService hive;
  late MockBox box;
  late AnalyticsService service;

  // Seule donnée Hive encore lue par `resolvePostSignupRoute` : le
  // consentement analytics. Le pays/l'onboarding pays vivaient dans Hive
  // avant ce lot (`kCountryOnboardingSeen`) ; ce drapeau a disparu du
  // résolveur, remplacé par les faits serveur portés par `UserModel`.
  Object? storedConsent;

  setUp(() {
    backend = MockAnalyticsBackend();
    remote = MockAnalyticsConsentRemote();
    hive = MockHiveService();
    box = MockBox();
    storedConsent = null;

    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(HiveService.kAnalyticsConsent),
    ).thenAnswer((_) => storedConsent);
    when(() => box.put(HiveService.kAnalyticsConsent, any())).thenAnswer((
      invocation,
    ) async {
      storedConsent = invocation.positionalArguments[1];
    });

    when(() => backend.optIn()).thenAnswer((_) async {});
    when(() => backend.optOut()).thenAnswer((_) async {});
    when(() => backend.capture(any(), any())).thenAnswer((_) async {});

    when(() => remote.fetch()).thenAnswer((_) async => null);
    when(
      () => remote.push(
        granted: any(named: 'granted'),
        policyVersion: any(named: 'policyVersion'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    service = AnalyticsService(hive, backend: backend, remote: remote);
  });

  group('resolvePostSignupRoute — réinstall (Hive vide, backend renseigné)', () {
    test(
      'backend granted=true → /auth/country-selection, PAS de re-prompt (régression corrigée)',
      () async {
        // Réinstall : sans le sync backend, hasAnswered serait faux à tort →
        // l'utilisateur verrait /auth/analytics-consent alors qu'il a déjà
        // répondu côté backend.
        storedConsent = null;
        when(() => remote.fetch()).thenAnswer((_) async => true);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/country-selection');
        verify(() => remote.fetch()).called(1);
      },
    );

    test(
      'backend granted=false → /auth/country-selection (révocation respectée, pas de re-prompt)',
      () async {
        storedConsent = null;
        when(() => remote.fetch()).thenAnswer((_) async => false);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/country-selection');
        verify(() => remote.fetch()).called(1);
      },
    );
  });

  group('resolvePostSignupRoute — jamais répondu (backend null)', () {
    test(
      'aucune donnée pays connue → /auth/analytics-consent, aucun consentement poussé',
      () async {
        storedConsent = null;
        when(() => remote.fetch()).thenAnswer((_) async => null);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/analytics-consent');
        verifyNever(
          () => remote.push(
            granted: any(named: 'granted'),
            policyVersion: any(named: 'policyVersion'),
            source: any(named: 'source'),
          ),
        );
      },
    );

    test('même si le pays est déjà connu → /auth/analytics-consent quand même '
        '(le consentement prime toujours sur les étapes suivantes)', () async {
      storedConsent = null;
      when(() => remote.fetch()).thenAnswer((_) async => null);
      await service.onConfigured();

      final route = await resolvePostSignupRoute(
        analytics: service,
        user: _user(country: 'SN'),
        stripe: const StripeAccountInitial(),
      );

      // Le consentement n'est plus jamais court-circuité par le pays :
      // l'écran est présenté à tout nouvel utilisateur, quel que soit
      // l'avancement des autres étapes.
      expect(route, '/auth/analytics-consent');
      verifyNever(
        () => remote.push(
          granted: any(named: 'granted'),
          policyVersion: any(named: 'policyVersion'),
          source: any(named: 'source'),
        ),
      );
    });
  });

  group('resolvePostSignupRoute — pas de sync inutile', () {
    test(
      'non configuré (analytics off) → /auth/country-selection sans appel backend',
      () async {
        // onConfigured non appelé → isConfigured=false.
        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/country-selection');
        verifyNever(() => remote.fetch());
      },
    );

    test(
      'consentement déjà répondu → pas de re-sync, avance à l\'étape pays',
      () async {
        storedConsent = true;
        await service.onConfigured();

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/country-selection');
        verifyNever(() => remote.fetch());
      },
    );

    test('consentement déjà répondu → pas de re-sync même quand tout le reste '
        'est fait (le parrainage clôt le parcours)', () async {
      storedConsent = true;
      await service.onConfigured();

      final route = await resolvePostSignupRoute(
        analytics: service,
        user: _user(
          country: 'FR',
          kycStatus: 'VERIFIED',
          residenceStreet: '12 rue des Lilas',
          stripeAccountStatus: 'ONBOARDING_COMPLETE',
        ),
        stripe: const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );

      expect(route, '/auth/referral-code');
      verifyNever(() => remote.fetch());
    });
  });

  group(
    'resolvePostSignupRoute — le parcours ne s\'impose plus une fois vu',
    () {
      test('onboardingSeenAt renseigné → /home, quelles que soient les étapes '
          'manquantes', () async {
        storedConsent = true;

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(onboardingSeenAt: DateTime.utc(2026, 8, 22)),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/home');
      });

      test(
        'un utilisateur qui a passé le pays n\'y est pas renvoyé en boucle',
        () async {
          // skip() et continueAsSenderOnly() laissent volontairement country
          // null.
          storedConsent = true;

          final route = await resolvePostSignupRoute(
            analytics: service,
            user: _user(onboardingSeenAt: DateTime.utc(2026, 8, 22)),
            stripe: const StripeAccountInitial(),
          );

          expect(route, isNot('/auth/country-selection'));
        },
      );
    },
  );

  group('resolvePostSignupRoute — route de chaque étape', () {
    test(
      'compte tout neuf, consentement répondu → sélection du pays',
      () async {
        storedConsent = true;

        final route = await resolvePostSignupRoute(
          analytics: service,
          user: _user(),
          stripe: const StripeAccountInitial(),
        );

        expect(route, '/auth/country-selection');
      },
    );

    test('identité non vérifiée → /kyc/verify', () async {
      storedConsent = true;

      final route = await resolvePostSignupRoute(
        analytics: service,
        // Adresse déjà connue : sinon, avec l'ordre du parcours réel
        // (adresse avant identité), c'est /auth/residence-address qui
        // serait retenue en premier.
        user: _user(country: 'FR', residenceStreet: '12 rue des Lilas'),
        stripe: const StripeAccountInitial(),
      );

      expect(route, '/kyc/verify');
    });

    test('plus rien à compléter → le parrainage clôt le parcours', () async {
      storedConsent = true;

      final route = await resolvePostSignupRoute(
        analytics: service,
        user: _user(
          country: 'FR',
          kycStatus: 'VERIFIED',
          residenceStreet: '12 rue des Lilas',
          stripeAccountStatus: 'ONBOARDING_COMPLETE',
        ),
        stripe: const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
      );

      expect(route, '/auth/referral-code');
    });
  });

  group('resolvePostSignupRoute — analytics de l\'étape retenue', () {
    test('l\'étape retenue est tracée, sans PII', () async {
      storedConsent = true;
      await service.onConfigured();

      await resolvePostSignupRoute(
        analytics: service,
        user: _user(country: 'FR'),
        stripe: const StripeAccountInitial(),
      );

      // 5 étapes (payouts inclus, StripeAccountInitial est optimiste) ;
      // consent + country faits, adresse manquante en premier (ordre du
      // parcours réel : adresse avant identité) → index 3/5.
      final captured = verify(
        () => backend.capture(captureAny(), captureAny()),
      ).captured;
      expect(captured[0], AnalyticsEvents.onboardingStepViewed);
      expect(captured[1], {'step': 'address', 'index': 3, 'total': 5});
      expect(captured.toString(), isNot(contains('u1')));
    });

    test(
      'le compte complet est tracé sans PII, avec le total d\'étapes',
      () async {
        storedConsent = true;
        await service.onConfigured();

        await resolvePostSignupRoute(
          analytics: service,
          user: _user(
            country: 'FR',
            kycStatus: 'VERIFIED',
            residenceStreet: '12 rue des Lilas',
            stripeAccountStatus: 'ONBOARDING_COMPLETE',
          ),
          stripe: const StripeAccountReady(
            ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
          ),
        );

        verify(
          () => backend.capture(AnalyticsEvents.onboardingCompleted, {
            'steps_total': 5,
          }),
        ).called(1);
        verifyNever(
          () => backend.capture(AnalyticsEvents.onboardingStepViewed, any()),
        );
      },
    );
  });
}
