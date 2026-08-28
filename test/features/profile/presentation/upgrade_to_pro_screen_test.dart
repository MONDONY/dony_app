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

/// Réponse dégradée : l'abonnement est chargé, mais sa source est nulle. Ni
/// gestion ni résiliation ne sont légitimes dans ce cas.
const _tUnknownSource = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.unknown,
  source: null,
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
}) {
  _register(repo, subBloc);

  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
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
    for (final unregister in [
      () => getIt.unregister<ProfileRepository>(),
      () => getIt.unregister<UpgradeToProBloc>(),
      () => getIt.unregister<SubscriptionBloc>(),
    ]) {
      unregister();
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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(repo: mockRepo, authBloc: mockAuthBloc, subBloc: mockSubBloc),
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
      'source inconnue malgré un abonnement chargé : aucun des deux boutons',
      (tester) async {
        subscriptionState(const SubscriptionLoaded(_tUnknownSource));
        await pumpScreen(tester);

        // Discriminant sur la règle elle-même : une visibilité écrite
        // « source != stripe » rendrait ici le retour au compte standard,
        // geste dont rien n'établit la légitimité.
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
        await tester.tap(find.text('Confirmer'));
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
