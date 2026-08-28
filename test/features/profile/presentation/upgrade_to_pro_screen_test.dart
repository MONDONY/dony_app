import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_card.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

/// Assez long pour laisser tous les délais `flutter_animate` de l'écran se
/// terminer avant les assertions.
const _kSettle = Duration(milliseconds: 600);

// ── Libellés sous contrat ───────────────────────────────────────────────────
// Regroupés ici parce que plusieurs tests les partagent : un changement de
// copie doit se voir en un seul endroit du fichier de test.

const _kMonthlyPrice = '4,99 € par mois';
const _kYearlyPrice = '47,90 € par an';
const _kPortalButton = "S'abonner sur le site Yadony PRO";
const _kManageButton = 'Gérer mon abonnement';
const _kDowngradeButton = 'Revenir en compte standard';
const _kRetryButton = 'Réessayer';

/// Verbe explicite du dialogue destructif de résiliation. Un « Confirmer »
/// générique laisserait l'utilisateur valider sans relire ce qu'il confirme.
const _kDowngradeConfirmLabel = 'Désactiver';
const _kDowngradeSuccessMessage = 'Compte PRO désactivé.';

/// La formulation mensongère de l'ancien écran : elle promettait une
/// activation immédiate depuis l'application, ce que le serveur n'accorde
/// plus. Elle ne doit reparaître nulle part.
const _kOldActivationPromise = 'Activer le compte PRO';
const _kOldActivationConfirmation = 'Compte PRO activé';

UserModel _nonProUser() => const UserModel(
  id: 'user-1',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'NONE',
  status: 'ACTIVE',
);

UserModel _proUser() => const UserModel(
  id: 'user-2',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  isProAccount: true,
);

const _tStripeActive = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.active,
  source: ProSubscriptionSource.stripe,
  billingCycle: 'MONTHLY',
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

const _tStripePastDue = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.pastDue,
  source: ProSubscriptionSource.stripe,
  billingCycle: 'MONTHLY',
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

const _tAdminGrant = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.active,
  source: ProSubscriptionSource.adminGrant,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

/// Réponse dégradée : l'abonnement est chargé, mais le serveur n'a rendu
/// aucune source (`null`). Ni gestion ni résiliation ne sont légitimes.
const _tNullSource = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.unknown,
  source: null,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

/// Cas réel de production, **distinct** de [_tNullSource] : le serveur a bien
/// rendu une source, mais cette version de l'application ne la connaît pas,
/// et `ProSubscriptionSource.fromWire` la replie sur
/// [ProSubscriptionSource.unknown]. Une règle écrite
/// `source != null && source != stripe` traiterait ce cas comme un octroi
/// administrateur et offrirait une résiliation sans fondement.
const _tUnknownSource = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.active,
  source: ProSubscriptionSource.unknown,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

const _tLegacyFree = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.legacyGrace,
  source: ProSubscriptionSource.legacyFree,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

/// Tous les textes réellement rendus à l'écran, y compris ceux portés par un
/// `TextSpan` (le bandeau du design system en utilise).
List<String> _renderedTexts(WidgetTester tester) {
  final out = <String>[];
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data ?? widget.textSpan?.toPlainText();
    if (data != null) out.add(data);
  }
  return out;
}

void _register(MockProfileRepository repo, MockSubscriptionBloc subBloc) {
  if (getIt.isRegistered<ProfileRepository>()) {
    getIt.unregister<ProfileRepository>();
  }
  getIt.registerLazySingleton<ProfileRepository>(() => repo);

  if (getIt.isRegistered<UpgradeToProBloc>()) {
    getIt.unregister<UpgradeToProBloc>();
  }
  getIt.registerFactory<UpgradeToProBloc>(
    () =>
        UpgradeToProBloc(getIt<ProfileRepository>(), getIt<AnalyticsService>()),
  );

  if (getIt.isRegistered<SubscriptionBloc>()) {
    getIt.unregister<SubscriptionBloc>();
  }
  getIt.registerFactory<SubscriptionBloc>(() => subBloc);
}

Widget _wrap({
  required MockProfileRepository repo,
  required MockAuthBloc authBloc,
  required MockSubscriptionBloc subBloc,
  String initialLocation = '/',
}) {
  _register(repo, subBloc);

  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const UpgradeToProScreen()),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('Profile')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late MockProfileRepository mockRepo;
  late MockAuthBloc mockAuthBloc;
  late MockSubscriptionBloc mockSubBloc;

  setUpAll(() {
    registerFallbackValue(const DowngradeRequested());
    registerFallbackValue(const AuthCheckRequested());
    registerFallbackValue(const SubscriptionRequested());
    registerFallbackValue(
      const ProPortalOpenRequested(ProPortalTarget.upgrade),
    );
    if (!getIt.isRegistered<AnalyticsService>()) {
      getIt.registerSingleton<AnalyticsService>(
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    mockRepo = MockProfileRepository();
    mockAuthBloc = MockAuthBloc();
    mockSubBloc = MockSubscriptionBloc();
  });

  tearDown(() {
    // Conditionnel : un test qui échoue AVANT le montage n'a rien enregistré,
    // et un `tearDown` qui lèverait à son tour masquerait l'échec réel
    // derrière une erreur d'injection sans rapport.
    if (getIt.isRegistered<ProfileRepository>()) {
      getIt.unregister<ProfileRepository>();
    }
    if (getIt.isRegistered<UpgradeToProBloc>()) {
      getIt.unregister<UpgradeToProBloc>();
    }
    if (getIt.isRegistered<SubscriptionBloc>()) {
      getIt.unregister<SubscriptionBloc>();
    }
  });

  void authAs(UserModel user) {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(user),
    );
  }

  void subscriptionState(SubscriptionState state) {
    whenListen<SubscriptionState>(
      mockSubBloc,
      const Stream.empty(),
      initialState: state,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    await tester.pumpWidget(
      _wrap(
        repo: mockRepo,
        authBloc: mockAuthBloc,
        subBloc: mockSubBloc,
        initialLocation: initialLocation,
      ),
    );
    await tester.pump(_kSettle);
  }

  // ── Vue non abonnée ───────────────────────────────────────────────────────

  group('UpgradeToProScreen — vue non abonnée', () {
    setUp(() {
      authAs(_nonProUser());
      subscriptionState(const SubscriptionInitial());
    });

    testWidgets(
      'affiche les deux tarifs, le bouton du portail, et AUCUN champ de saisie',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text(_kMonthlyPrice), findsOneWidget);
        expect(find.text(_kYearlyPrice), findsOneWidget);
        expect(find.text(_kPortalButton), findsOneWidget);

        // La garantie que le formulaire trompeur ne revient pas se prend sur
        // les TYPES de widget de saisie, pas sur un libellé : un champ
        // renommé passerait sous un test de libellé, jamais sous celui-ci.
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(Form), findsNothing);
      },
    );

    testWidgets(
      "l'économie annuelle est chiffrée en euros, jamais traduite en mois",
      (tester) async {
        await pumpScreen(tester);

        expect(find.textContaining('11,98 €'), findsOneWidget);
        // 11,98 € font 2,4 mois : toute formulation en mois entiers mentirait.
        for (final text in _renderedTexts(tester)) {
          expect(
            text.contains('mois offert'),
            isFalse,
            reason: 'Économie annuelle traduite en mois offerts : "$text"',
          );
        }
      },
    );

    testWidgets('le tap sur le bouton demande le portail de souscription', (
      tester,
    ) async {
      await pumpScreen(tester);

      // La page de vente dépasse la hauteur du viewport de test : le bouton
      // vit sous la ligne de flottaison et doit être amené à l'écran avant
      // d'être touché.
      await tester.ensureVisible(find.text(_kPortalButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_kPortalButton));
      await tester.pump();

      // La cible est assertée : une inversion upgrade/manage enverrait le
      // prospect sur une page de gestion vide.
      verify(
        () => mockSubBloc.add(
          const ProPortalOpenRequested(ProPortalTarget.upgrade),
        ),
      ).called(1);
    });

    testWidgets("aucun texte ne promet une activation depuis l'application", (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(_kOldActivationPromise), findsNothing);
      expect(find.text(_kOldActivationConfirmation), findsNothing);
      expect(find.text(_kDowngradeButton), findsNothing);
    });

    testWidgets("l'abonnement n'est pas interrogé pour un compte non PRO", (
      tester,
    ) async {
      await pumpScreen(tester);

      verifyNever(() => mockSubBloc.add(const SubscriptionRequested()));
    });
  });

  // ── Vue abonnée ───────────────────────────────────────────────────────────

  group('UpgradeToProScreen — vue abonnée', () {
    setUp(() {
      authAs(_proUser());
    });

    testWidgets("l'abonnement est demandé à l'ouverture pour un compte PRO", (
      tester,
    ) async {
      subscriptionState(const SubscriptionInitial());
      await pumpScreen(tester);

      verify(() => mockSubBloc.add(const SubscriptionRequested())).called(1);
    });

    testWidgets(
      'source stripe : la carte et le bouton de gestion sont rendus, le retour '
      'au compte standard est absent',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tStripeActive));
        await pumpScreen(tester);

        expect(find.byType(SubscriptionStatusCard), findsOneWidget);
        expect(find.text(_kManageButton), findsOneWidget);
        // Ce bouton ne pourrait qu'échouer en 409 pour un abonné payant.
        expect(find.text(_kDowngradeButton), findsNothing);
      },
    );

    testWidgets('le bouton de gestion émet bien la cible de GESTION', (
      tester,
    ) async {
      subscriptionState(const SubscriptionLoaded(_tStripeActive));
      await pumpScreen(tester);

      await tester.tap(find.text(_kManageButton));
      await tester.pump();

      // La présence du libellé ne prouve rien de la cible : une inversion
      // enverrait un abonné payant sur la page de vente.
      verify(
        () => mockSubBloc.add(
          const ProPortalOpenRequested(ProPortalTarget.manage),
        ),
      ).called(1);
    });

    testWidgets(
      "l'action du bandeau d'impayé mène à la GESTION du moyen de paiement",
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tStripePastDue));
        await pumpScreen(tester);

        await tester.tap(find.text('Régler'));
        await tester.pump();

        verify(
          () => mockSubBloc.add(
            const ProPortalOpenRequested(ProPortalTarget.manage),
          ),
        ).called(1);
      },
    );

    testWidgets("l'action du bandeau de grâce mène à la page de VENTE", (
      tester,
    ) async {
      subscriptionState(const SubscriptionLoaded(_tLegacyFree));
      await pumpScreen(tester);

      await tester.tap(find.text("S'abonner"));
      await tester.pump();

      // Seule une grâce historique (jamais payé) doit atteindre la vente.
      // L'inverser enverrait un bénéficiaire de grâce sur une page de
      // gestion vide, faute d'abonnement à gérer.
      verify(
        () => mockSubBloc.add(
          const ProPortalOpenRequested(ProPortalTarget.upgrade),
        ),
      ).called(1);
    });

    testWidgets(
      'source adminGrant : gestion absente, retour au compte standard présent',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tAdminGrant));
        await pumpScreen(tester);

        expect(find.text(_kManageButton), findsNothing);
        expect(find.text(_kDowngradeButton), findsOneWidget);
      },
    );

    testWidgets(
      'source legacyFree : gestion absente, retour présent, bandeau de grâce '
      'rendu',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tLegacyFree));
        await pumpScreen(tester);

        expect(find.text(_kManageButton), findsNothing);
        expect(find.text(_kDowngradeButton), findsOneWidget);
        expect(
          find.textContaining('accès PRO gratuit'),
          findsOneWidget,
          reason: 'Le bandeau de grâce historique doit être rendu.',
        );
      },
    );

    testWidgets(
      'chargement en cours : ni gestion ni retour au compte standard',
      (tester) async {
        subscriptionState(const SubscriptionLoading());
        await pumpScreen(tester);

        // Tant que `source` est inconnue, aucun des deux gestes n'a de
        // légitimité établie.
        expect(find.text(_kManageButton), findsNothing);
        expect(find.text(_kDowngradeButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'source absente (null) malgré un abonnement chargé : aucun des deux '
      'boutons',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tNullSource));
        await pumpScreen(tester);

        // Discriminant sur la règle elle-même : une visibilité écrite
        // « source != stripe » rendrait ici le retour au compte standard,
        // geste dont rien n'établit la légitimité.
        expect(find.text(_kManageButton), findsNothing);
        expect(find.text(_kDowngradeButton), findsNothing);
      },
    );

    testWidgets(
      'source unknown (valeur serveur non reconnue) : aucun des deux boutons',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tUnknownSource));
        await pumpScreen(tester);

        // Jumeau du test précédent, sur la valeur d'énumération réelle et non
        // sur `null`. C'est lui qui ferme la porte au correctif « naturel »
        // `source != null && source != stripe`, qui resterait vert partout
        // ailleurs tout en offrant une résiliation à un abonné dont la source
        // n'est pas connue de cette version de l'app.
        expect(find.text(_kManageButton), findsNothing);
        expect(find.text(_kDowngradeButton), findsNothing);
      },
    );

    testWidgets(
      'bandeau muet : aucun espacement fantôme au-dessus de la carte',
      (tester) async {
        // Abonnement actif sans résiliation programmée : le bandeau rend
        // `SizedBox.shrink()`. L'espacement qui le suit ne doit pas exister
        // non plus, sinon la page s'ouvre sur un vide inexpliqué pour le cas
        // le plus courant.
        subscriptionState(const SubscriptionLoaded(_tAdminGrant));
        await pumpScreen(tester);

        final scrollTop = tester
            .getTopLeft(find.byType(SingleChildScrollView))
            .dy;
        final cardTop = tester
            .getTopLeft(find.byType(SubscriptionStatusCard))
            .dy;
        // La carte commence exactement au début de la zone de contenu. Un
        // espacement inconditionnel décalerait ce point de DonySpacing.lg.
        expect(cardTop, scrollTop + DonySpacing.xl);
      },
    );

    testWidgets('statut pastDue : le bandeau d\'impayé est rendu', (
      tester,
    ) async {
      subscriptionState(const SubscriptionLoaded(_tStripePastDue));
      await pumpScreen(tester);

      expect(find.textContaining("n'a pas abouti"), findsOneWidget);
    });

    testWidgets(
      "une erreur de chargement n'efface pas l'écran et propose de réessayer",
      (tester) async {
        subscriptionState(const SubscriptionError(NetworkException('boom')));
        await pumpScreen(tester);

        // La page reste lisible : son titre est toujours là.
        expect(find.text('Mon compte PRO'), findsOneWidget);
        expect(find.text(_kRetryButton), findsOneWidget);

        await tester.tap(find.text(_kRetryButton));
        await tester.pump();

        // Une fois au montage, une fois au tap.
        verify(() => mockSubBloc.add(const SubscriptionRequested())).called(2);
      },
    );

    testWidgets(
      'résiliation réussie : profil rafraîchi et confirmation affichée',
      (tester) async {
        when(() => mockRepo.downgradePro()).thenAnswer((_) async {});
        subscriptionState(const SubscriptionLoaded(_tAdminGrant));
        await pumpScreen(tester);

        await tester.tap(find.text(_kDowngradeButton));
        await tester.pumpAndSettle();
        expect(find.text(_kDowngradeConfirmLabel), findsOneWidget);
        await tester.tap(find.text(_kDowngradeConfirmLabel));
        await tester.pumpAndSettle();

        verify(() => mockRepo.downgradePro()).called(1);
        // Le rafraîchissement du profil est le maillon dont l'absence ne se
        // voit nulle part ailleurs : sans lui, l'utilisateur repasse en compte
        // standard et le Profil continue d'afficher son badge PRO.
        verify(() => mockAuthBloc.add(const AuthCheckRequested())).called(1);
        expect(find.text(_kDowngradeSuccessMessage), findsOneWidget);
      },
    );

    testWidgets(
      'résiliation réussie : la page se referme sur celle qui la précédait',
      (tester) async {
        when(() => mockRepo.downgradePro()).thenAnswer((_) async {});
        subscriptionState(const SubscriptionLoaded(_tAdminGrant));

        // Ce test seul démarre ailleurs et EMPILE l'écran, pour que
        // `canPop()` soit vrai. Monté à la racine du routeur comme les
        // autres tests du fichier, la branche de fermeture n'est jamais
        // atteinte et ne prouverait donc rien.
        await pumpScreen(tester, initialLocation: '/profile');
        // `push` ne se complète qu'au dépilement de la route : l'attendre ici
        // bloquerait le test avant même le premier `pump`.
        unawaited(tester.element(find.text('Profile')).push('/'));
        await tester.pumpAndSettle();
        expect(find.text(_kDowngradeButton), findsOneWidget);

        await tester.tap(find.text(_kDowngradeButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_kDowngradeConfirmLabel));
        await tester.pumpAndSettle();

        // L'écran a disparu et la page précédente est revenue : rester sur
        // un écran PRO après avoir cessé d'être PRO serait incohérent.
        expect(find.text(_kDowngradeButton), findsNothing);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'downgrade refusé en 409 active-stripe-subscription : message renvoyant '
      'vers le web, jamais le message brut du serveur',
      (tester) async {
        const rawServerDetail =
            'Cancel your subscription from the billing portal first.';
        when(() => mockRepo.downgradePro()).thenThrow(
          const ConflictException(
            rawServerDetail,
            code: 'active-stripe-subscription',
          ),
        );
        // adminGrant : c'est la seule vue où le bouton est offert. La course
        // reproduite ici est celle d'un abonnement souscrit sur le web
        // pendant que cet écran était déjà ouvert.
        subscriptionState(const SubscriptionLoaded(_tAdminGrant));
        await pumpScreen(tester);

        await tester.tap(find.text(_kDowngradeButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_kDowngradeConfirmLabel));
        await tester.pumpAndSettle();

        expect(find.textContaining('site Yadony PRO'), findsWidgets);
        expect(find.text(rawServerDetail), findsNothing);
        // Le message générique du catalogue d'erreurs : sa présence
        // signifierait que le code 409 n'a pas été reconnu.
        expect(
          find.text("L'état actuel ne permet pas cette action."),
          findsNothing,
        );
      },
    );
  });

  // ── Réaction au changement d'état d'authentification ──────────────────────

  group('UpgradeToProScreen — le compte devient PRO écran ouvert', () {
    testWidgets(
      'le passage à PRO après la construction déclenche le chargement de '
      "l'abonnement",
      (tester) async {
        // Parcours nominal de ce lot : l'utilisateur part s'abonner dans le
        // navigateur, revient, et un rafraîchissement de profil le fait
        // basculer en PRO alors que cet écran est toujours monté. Si la
        // décision d'interroger l'abonnement reste figée à la construction,
        // la demande n'est jamais émise.
        final authStates = StreamController<AuthState>.broadcast();
        addTearDown(authStates.close);
        whenListen<AuthState>(
          mockAuthBloc,
          authStates.stream,
          initialState: AuthAuthenticated(_nonProUser()),
        );
        subscriptionState(const SubscriptionInitial());

        await pumpScreen(tester);
        // À la construction, l'utilisateur n'est pas PRO : aucun appel.
        verifyNever(() => mockSubBloc.add(const SubscriptionRequested()));

        authStates.add(AuthAuthenticated(_proUser()));
        await tester.pump();
        await tester.pump(_kSettle);

        verify(() => mockSubBloc.add(const SubscriptionRequested())).called(1);
      },
    );

    testWidgets(
      "un compte PRO dont l'abonnement n'a jamais été demandé garde une "
      'sortie',
      (tester) async {
        // Filet de sécurité : même si, pour une raison quelconque, aucune
        // demande n'est en vol, l'écran ne doit jamais se réduire à un
        // indicateur de chargement définitif. Sans sortie, l'utilisateur est
        // enfermé sur l'écran exactement là où il attend son abonnement.
        authAs(_proUser());
        subscriptionState(const SubscriptionInitial());
        await pumpScreen(tester);

        expect(find.text(_kRetryButton), findsOneWidget);
        // Pas d'indicateur d'activité dans cette branche : un « attends »
        // affiché à côté d'un « agis » se contredit, et rien n'attend
        // effectivement quoi que ce soit puisque aucune demande n'est en vol.
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text(_kRetryButton));
        await tester.pump();

        // Une fois au montage (le compte est déjà PRO), une fois au tap.
        verify(() => mockSubBloc.add(const SubscriptionRequested())).called(2);
      },
    );
  });

  // ── États d'authentification qui ne portent pas d'utilisateur ─────────────

  group(
    "UpgradeToProScreen — l'authentification ne dit rien de l'utilisateur",
    () {
      testWidgets(
        'un rafraîchissement de profil ne fait pas clignoter la page de vente '
        "sous les yeux d'un abonné",
        (tester) async {
          // `AuthCheckRequested` émet `AuthLoading` AVANT l'état authentifié
          // (voir `AuthBloc._onCheckRequested`). Déduire « non PRO » de cet
          // état intermédiaire ferait défiler la page de vente, tarifs
          // compris, à un abonné qui n'a rien demandé. C'est le même mensonge
          // visuel que celui que cette tâche supprime, en plus bref.
          final authStates = StreamController<AuthState>.broadcast();
          addTearDown(authStates.close);
          whenListen<AuthState>(
            mockAuthBloc,
            authStates.stream,
            initialState: AuthAuthenticated(_proUser()),
          );
          subscriptionState(const SubscriptionLoaded(_tStripeActive));

          await pumpScreen(tester);
          expect(find.byType(SubscriptionStatusCard), findsOneWidget);

          authStates.add(const AuthLoading());
          await tester.pump();

          expect(find.text(_kMonthlyPrice), findsNothing);
          expect(find.text(_kPortalButton), findsNothing);
          expect(find.byType(SubscriptionStatusCard), findsOneWidget);
        },
      );

      testWidgets(
        "l'échec d'une action annexe ne fait pas disparaître la vue d'abonné",
        (tester) async {
          // `AuthError` est un état SURCHARGÉ : il ne signale pas une fin de
          // session. Il est émis par `_onUpdateProfileRequested`,
          // `_onAvatarUploadRequested`, `_onAddPhoneFromProfileRequested`,
          // `_onAddEmailFromProfileRequested`, `_onDeleteAccountRequested` et
          // `_onProfileRefreshRequested` — six chemins où l'utilisateur reste
          // pleinement authentifié. Un envoi d'avatar qui échoue en réseau ne
          // doit pas escamoter l'abonnement d'un abonné valide.
          final authStates = StreamController<AuthState>.broadcast();
          addTearDown(authStates.close);
          whenListen<AuthState>(
            mockAuthBloc,
            authStates.stream,
            initialState: AuthAuthenticated(_proUser()),
          );
          subscriptionState(const SubscriptionLoaded(_tAdminGrant));

          await pumpScreen(tester);
          expect(find.text(_kDowngradeButton), findsOneWidget);

          authStates.add(const AuthError(NetworkException('upload failed')));
          await tester.pump();

          // La vue d'abonné RESTE : rien dans cet état ne dit quoi que ce
          // soit de la session.
          expect(find.text(_kDowngradeButton), findsOneWidget);
          expect(find.byType(SubscriptionStatusCard), findsOneWidget);
        },
      );

      // Le revers du filtre de reconstruction : ignorer TOUS les états sans
      // utilisateur figerait l'écran sur la vue d'abonné après la fermeture
      // de la session. Le routeur ne redirige pas sur une déconnexion
      // volontaire ultérieure (seulement au tout premier contrôle au
      // démarrage), donc rien d'autre ne rattraperait le coup. Seul
      // `AuthLoading` est un état de passage ; ceux-ci sont terminaux et
      // doivent tous provoquer un rendu.
      for (final (label, terminalState) in <(String, AuthState)>[
        ('déconnexion', const AuthInitial()),
        ('suppression de compte', const AuthAccountDeleted()),
        ('verrouillage', const AuthLocked()),
      ]) {
        testWidgets(
          "$label : l'écran quitte la vue d'abonné au lieu de rester figé",
          (tester) async {
            final authStates = StreamController<AuthState>.broadcast();
            addTearDown(authStates.close);
            whenListen<AuthState>(
              mockAuthBloc,
              authStates.stream,
              initialState: AuthAuthenticated(_proUser()),
            );
            subscriptionState(const SubscriptionLoaded(_tAdminGrant));

            await pumpScreen(tester);
            expect(find.text(_kDowngradeButton), findsOneWidget);

            authStates.add(terminalState);
            await tester.pump();

            // Proposer de résilier un abonnement sur une session fermée est
            // au moins aussi trompeur que la page de vente que cette tâche
            // supprime.
            expect(find.text(_kDowngradeButton), findsNothing);
            expect(find.byType(SubscriptionStatusCard), findsNothing);
          },
        );
      }

      testWidgets(
        "au démarrage à froid, rien n'est affirmé : ni page de vente, ni vue "
        "d'abonné",
        (tester) async {
          // L'état d'authentification n'a encore rien dit. Montrer la page de
          // vente reviendrait à affirmer « vous n'êtes pas abonné » sans le
          // savoir.
          whenListen<AuthState>(
            mockAuthBloc,
            const Stream.empty(),
            initialState: const AuthLoading(),
          );
          subscriptionState(const SubscriptionInitial());

          await pumpScreen(tester);

          expect(find.text(_kMonthlyPrice), findsNothing);
          expect(find.text(_kPortalButton), findsNothing);
          expect(find.byType(SubscriptionStatusCard), findsNothing);
          // Et aucune requête d'abonnement n'est émise sur une supposition.
          verifyNever(() => mockSubBloc.add(const SubscriptionRequested()));
        },
      );
    },
  );

  // ── Contraintes de copie, sur les deux vues ───────────────────────────────

  group('UpgradeToProScreen — contraintes de copie', () {
    testWidgets('vue non abonnée : pas de tiret cadratin, marque « Yadony »', (
      tester,
    ) async {
      authAs(_nonProUser());
      subscriptionState(const SubscriptionInitial());
      await pumpScreen(tester);

      final texts = _renderedTexts(tester);
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.contains('—'), isFalse, reason: 'Tiret cadratin : "$text"');
        expect(
          text.contains('Dony'),
          isFalse,
          reason: 'Nom public « Dony » interdit : "$text"',
        );
      }
      expect(
        texts.any((t) => t.contains('Yadony')),
        isTrue,
        reason: 'La marque doit être nommée « Yadony » sur la vue de vente.',
      );
    });

    testWidgets('vue abonnée : pas de tiret cadratin, jamais « Dony »', (
      tester,
    ) async {
      authAs(_proUser());
      subscriptionState(const SubscriptionLoaded(_tAdminGrant));
      await pumpScreen(tester);

      final texts = _renderedTexts(tester);
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.contains('—'), isFalse, reason: 'Tiret cadratin : "$text"');
        expect(
          text.contains('Dony'),
          isFalse,
          reason: 'Nom public « Dony » interdit : "$text"',
        );
      }
    });
  });
}
