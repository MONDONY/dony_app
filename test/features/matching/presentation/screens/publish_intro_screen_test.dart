import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/screens/publish_intro_screen.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_cubit.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/repositories/publish_commitment_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/publish_blocked_screen.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/form_draft_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../publish_gate/publish_gate_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockCommitments extends Mock implements PublishCommitmentRepository {}

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockRequests extends Mock implements PackageRequestRepository {}

class _MockTemplates extends Mock implements TripTemplateRepository {}

class _MockTravelerStatus extends Mock implements TravelerStatusRepository {}

UserModel _user({required String kycStatus}) => UserModel.fromJson({
  'id': 'u1',
  'roles': const ['SENDER', 'TRAVELER'],
  'kycStatus': kycStatus,
});

late List<String> visited;
late List<Object?> extras;
late _MockCommitments _commitmentRepo;
late _MockTravelerStatus _statusRepo;

Future<void> _pump(
  WidgetTester tester, {
  required PublishIntroRole role,
  required String kycStatus,
  String stripeStatus = 'ONBOARDING_COMPLETE',
  bool connectAvailable = true,
  bool commitmentRequired = true,
  Map<String, dynamic>? localDraft,
  List<Object> serverDrafts = const [],
  List<TripTemplate> tripTemplates = const [],
  AuthRepository? authRepository,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  if (!getIt.isRegistered<AnalyticsService>()) {
    final analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  }
  addTearDown(getIt.reset);
  if (authRepository != null) {
    getIt.registerSingleton<AuthRepository>(authRepository);
  }

  _commitmentRepo = _MockCommitments();
  when(() => _commitmentRepo.fetch()).thenAnswer(
    (_) async => commitments(
      travelerRequired: commitmentRequired,
      senderRequired: commitmentRequired,
    ),
  );
  when(() => _commitmentRepo.accept(any(), any())).thenAnswer((_) async {});
  final store = testFormDraftStore();
  if (localDraft != null) {
    await store.save(
      role == PublishIntroRole.trip
          ? FormDraftKind.trip
          : FormDraftKind.packageRequest,
      localDraft,
    );
  }
  final announcements = _MockAnnouncements();
  when(() => announcements.getMyAnnouncements()).thenAnswer(
    (_) async => (
      announcements: serverDrafts.whereType<AnnouncementModel>().toList(),
      totalElements: 0,
    ),
  );
  final requests = _MockRequests();
  when(() => requests.findMine(size: any(named: 'size'))).thenAnswer(
    (_) async => PackageRequestPage(
      content: serverDrafts.whereType<PackageRequest>().toList(),
      totalElements: 0,
      page: 0,
      size: 50,
    ),
  );
  final templates = _MockTemplates();
  when(() => templates.getAll()).thenAnswer((_) async => tripTemplates);
  _statusRepo = _MockTravelerStatus();
  when(() => _statusRepo.checkEligibility()).thenAnswer(
    // Toujours à la limite : l'aiguillage ne doit pas le lire.
    (_) async => (
      eligibility: const PublishingEligibility(
        allowed: false,
        reason: PublishingReason.limitReached,
        limit: 4,
        used: 4,
        travelerStatus: TravelerStatus.individual,
      ),
      failureCode: null,
    ),
  );
  getIt
    ..registerSingleton<TravelerStatusRepository>(_statusRepo)
    ..registerFactory<TravelerStatusCubit>(
      () => TravelerStatusCubit(_statusRepo, getIt<AnalyticsService>()),
    );
  getIt.registerFactoryParam<PublishGateCubit, PublishCommitmentRole, void>(
    (r, _) => PublishGateCubit(
      role: r,
      commitments: _commitmentRepo,
      drafts: store,
      announcements: announcements,
      packageRequests: requests,
      templates: templates,
      analytics: getIt<AnalyticsService>(),
    ),
  );

  visited = [];
  extras = [];
  final authBloc = _MockAuthBloc();
  when(() => authBloc.isClosed).thenReturn(false);
  when(
    () => authBloc.state,
  ).thenReturn(AuthAuthenticated(_user(kycStatus: kycStatus)));

  final stripeBloc = _MockStripeAccountBloc();
  when(() => stripeBloc.state).thenReturn(
    StripeAccountReady(
      ConnectAccountStatus.fromJson({
        'stripeAccountStatus': stripeStatus,
        'connectAvailableInCountry': connectAvailable,
      }),
    ),
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          ],
          child: PublishIntroScreen(role: role),
        ),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, _) {
          visited.add('/connect/onboarding/intro');
          return const Scaffold(body: Text('Onboarding Stripe'));
        },
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, state) {
          visited.add('/trips/create');
          extras.add(state.extra);
          return const Scaffold(body: Text('Formulaire trajet'));
        },
      ),
      GoRoute(
        path: '/package-requests/new',
        builder: (_, state) {
          visited.add('/package-requests/new');
          extras.add(state.extra);
          return const Scaffold(body: Text('Wizard colis'));
        },
      ),
      GoRoute(
        path: '/announcements/:id/trip',
        builder: (_, state) {
          visited.add('/announcements/${state.pathParameters['id']}/trip');
          return const Scaffold(body: Text('Trajet brouillon'));
        },
      ),
      GoRoute(
        path: '/package-requests/:id',
        builder: (_, state) {
          visited.add('/package-requests/${state.pathParameters['id']}');
          return const Scaffold(body: Text('Demande brouillon'));
        },
      ),
      GoRoute(
        path: '/announcements/trips',
        builder: (_, state) {
          visited.add(state.uri.toString());
          return const Scaffold(body: Text('Mes trajets'));
        },
      ),
      GoRoute(
        path: '/trips/publish-blocked',
        builder: (_, state) {
          final args = state.extra! as PublishBlockedArgs;
          return PublishBlockedScreen(
            eligibility: args.eligibility,
            source: args.source,
          );
        },
      ),
      GoRoute(
        path: '/profile/gp-pro',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: context.pop,
            child: const Text('Formulaire GP Pro'),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) {
          visited.add('/home');
          return const Scaffold(body: Text('Accueil'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Coche la case des engagements, tout en bas de l'écran.
Future<void> _check(WidgetTester tester) async {
  final box = find.byKey(const Key('publish-commitment-checkbox'));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(PublishCommitmentRole.traveler));

  group('PublishIntroScreen — limite mensuelle de trajets', () {
    testWidgets('à la limite : l\'écran de blocage ne s\'ouvre pas, le '
        'voyageur arrive aux engagements puis au formulaire', (tester) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Vous ne pouvez plus créer de trajet ce mois-ci'),
        findsNothing,
      );
      expect(visited, contains('/trips/create'));
      verifyNever(() => _statusRepo.checkEligibility());
    });

    testWidgets('à la limite, engagements à accepter : ils s\'affichent', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');
      await tester.pumpAndSettle();

      expect(find.text('Vos engagements de voyageur'), findsOneWidget);
      expect(
        find.text('Limite de 4 trajets atteinte ce mois-ci'),
        findsNothing,
      );
      verifyNever(() => _statusRepo.checkEligibility());
    });
  });

  group('PublishIntroScreen — trajet', () {
    testWidgets(
      'vérifié : titre, engagements voyageur, callout vert, Continuer',
      (tester) async {
        await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

        expect(find.text('Publier un trajet'), findsOneWidget);
        expect(find.text('Vos engagements de voyageur'), findsOneWidget);
        expect(find.textContaining('Identité vérifiée'), findsOneWidget);
        expect(find.text('Continuer'), findsOneWidget);
        expect(find.text('Vérifier mon identité'), findsNothing);
      },
    );

    group('profil en cache périmé (identité validée hors du flux Didit)', () {
      testWidgets(
        'cache non vérifié, serveur VERIFIED : pas de blocage, formulaire direct',
        (tester) async {
          final repo = _MockAuthRepository();
          when(
            () => repo.getProfile(),
          ).thenAnswer((_) async => _user(kycStatus: 'VERIFIED'));
          await _pump(
            tester,
            role: PublishIntroRole.trip,
            kycStatus: 'NOT_STARTED',
            commitmentRequired: false,
            authRepository: repo,
          );
          await tester.pumpAndSettle();

          verify(() => repo.getProfile()).called(1);
          expect(visited, ['/trips/create']);
          expect(
            find.textContaining('identité doit être vérifiée'),
            findsNothing,
          );
        },
      );

      testWidgets('cache non vérifié, serveur non vérifié : blocage conservé', (
        tester,
      ) async {
        final repo = _MockAuthRepository();
        when(
          () => repo.getProfile(),
        ).thenAnswer((_) async => _user(kycStatus: 'NOT_STARTED'));
        await _pump(
          tester,
          role: PublishIntroRole.trip,
          kycStatus: 'NOT_STARTED',
          commitmentRequired: false,
          authRepository: repo,
        );
        await tester.pumpAndSettle();

        expect(visited, isEmpty);
        expect(find.text('Vérifier mon identité'), findsOneWidget);
        expect(
          find.textContaining('identité doit être vérifiée'),
          findsOneWidget,
        );
      });

      testWidgets('serveur injoignable : blocage conservé (comme avant)', (
        tester,
      ) async {
        final repo = _MockAuthRepository();
        when(() => repo.getProfile()).thenThrow(Exception('hors ligne'));
        await _pump(
          tester,
          role: PublishIntroRole.trip,
          kycStatus: 'NOT_STARTED',
          authRepository: repo,
        );
        await tester.pumpAndSettle();

        expect(find.text('Vérifier mon identité'), findsOneWidget);
        expect(visited, isEmpty);
      });

      testWidgets(
        'cache vérifié : aucune relecture du serveur (comportement nominal)',
        (tester) async {
          final repo = _MockAuthRepository();
          await _pump(
            tester,
            role: PublishIntroRole.trip,
            kycStatus: 'VERIFIED',
            commitmentRequired: false,
            authRepository: repo,
          );
          await tester.pumpAndSettle();

          verifyNever(() => repo.getProfile());
          expect(visited, ['/trips/create']);
        },
      );

      testWidgets(
        'tap sur « Vérifier » : le serveur dit VERIFIED, la feuille ne s\'ouvre pas',
        (tester) async {
          final repo = _MockAuthRepository();
          // Premier appel (démarrage) : encore non vérifié ; second (tap) :
          // l'admin a validé entre-temps.
          var calls = 0;
          when(() => repo.getProfile()).thenAnswer((_) async {
            calls++;
            return _user(kycStatus: calls == 1 ? 'NOT_STARTED' : 'VERIFIED');
          });
          await _pump(
            tester,
            role: PublishIntroRole.trip,
            kycStatus: 'NOT_STARTED',
            commitmentRequired: false,
            authRepository: repo,
          );
          await tester.pumpAndSettle();
          expect(visited, isEmpty);

          await tester.tap(find.text('Vérifier mon identité'));
          await tester.pumpAndSettle();

          expect(calls, 2);
          expect(visited, ['/trips/create']);
        },
      );
    });

    testWidgets('non vérifié : bouton Vérifier + invite, pas de Continuer', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
      );

      expect(find.text('Vérifier mon identité'), findsOneWidget);
      expect(find.textContaining('Le bouton devient'), findsOneWidget);
      expect(find.text('Continuer'), findsNothing);
      expect(
        find.textContaining('identité doit être vérifiée'),
        findsOneWidget,
      );
    });

    testWidgets('non vérifié : phrase complète en français (gras + chemin '
        'reconstitués depuis une clé unique paramétrée)', (tester) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
      );

      expect(
        find.text(
          'Avant de publier, votre identité doit être vérifiée. '
          'Rendez-vous dans Profil › Vérifications pour la valider '
          '(2 min).',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'vérifié : Continuer grisé tant que la case n\'est pas cochée',
      (tester) async {
        await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

        expect(
          find.text(
            'J\'ai lu et j\'ai pris connaissance de mes engagements en tant '
            'que voyageur.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Cochez la case en bas de la page pour continuer.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(visited, isEmpty);
        verifyNever(() => _commitmentRepo.accept(any(), any()));
      },
    );

    testWidgets('vérifié : case cochée puis Continuer enregistre l\'accord et '
        'ouvre le formulaire de trajet', (tester) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      await _check(tester);
      expect(
        find.text('Cochez la case en bas de la page pour continuer.'),
        findsNothing,
      );
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      verify(
        () => _commitmentRepo.accept(PublishCommitmentRole.traveler, '2026-10'),
      ).called(1);
      expect(visited, ['/trips/create']);
      expect(extras.single, isA<CreateTripArgs>());
      expect((extras.single! as CreateTripArgs).resumeDraft, isNull);
    });

    testWidgets('engagements déjà acceptés : écran sauté, formulaire direct', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
      );
      await tester.pumpAndSettle();

      expect(visited, ['/trips/create']);
      expect(find.text('Vos engagements de voyageur'), findsNothing);
    });

    testWidgets('accepté mais non vérifié : écran sans case à cocher', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
        commitmentRequired: false,
      );

      expect(find.text('Vérifier mon identité'), findsOneWidget);
      expect(
        find.byKey(const Key('publish-commitment-checkbox')),
        findsNothing,
      );
    });

    testWidgets('texte mis à jour (409) : message et case décochée', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');
      when(() => _commitmentRepo.accept(any(), any())).thenThrow(
        const ConflictException('x', code: 'publish-commitment-outdated'),
      );

      await _check(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Vos engagements ont été mis à jour. Relisez-les avant de continuer.',
        ),
        findsOneWidget,
      );
      expect(visited, isEmpty);
      expect(
        find.text('Cochez la case en bas de la page pour continuer.'),
        findsOneWidget,
      );
    });

    testWidgets('accord non enregistré : message, on reste sur l\'écran', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');
      when(
        () => _commitmentRepo.accept(any(), any()),
      ).thenThrow(const NetworkException('x'));

      await _check(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Votre accord n\'a pas pu être enregistré'),
        findsOneWidget,
      );
      expect(visited, isEmpty);
    });

    testWidgets('rappel Stripe visible si compte non configuré, et navigue', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        stripeStatus: 'NOT_CREATED',
      );

      expect(find.text('Activez les paiements par carte'), findsOneWidget);

      await tester.tap(find.text('Activez les paiements par carte'));
      await tester.pumpAndSettle();

      expect(visited, contains('/connect/onboarding/intro'));
    });

    testWidgets('rappel Stripe masqué si compte déjà opérationnel', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      expect(find.text('Activez les paiements par carte'), findsNothing);
    });

    testWidgets('rappel Stripe masqué si Stripe ne couvre pas le pays', (
      tester,
    ) async {
      // Compte non configuré, donc le rappel s'afficherait normalement : c'est
      // bien le pays qui le masque. Un tap ne pourrait jamais convertir.
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        stripeStatus: 'NOT_CREATED',
        connectAvailable: false,
      );

      expect(find.text('Activez les paiements par carte'), findsNothing);
    });
  });

  group('PublishIntroScreen — colis', () {
    testWidgets('vérifié : titre, engagements expéditeur, Continuer', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(find.text('Publier un colis'), findsOneWidget);
      expect(find.text('Vos engagements d\'expéditeur'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      // Le rappel Stripe est réservé au voyageur : absent côté expéditeur.
      expect(find.text('Activez les paiements par carte'), findsNothing);
    });

    testWidgets('« Comment ça marche » : transport neutre, sans bagages', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(
        find.text('Un voyageur ou un transporteur achemine votre colis.'),
        findsOneWidget,
      );
      expect(find.textContaining('bagage'), findsNothing);
    });

    testWidgets('avant le choix du mode : ni aéroport ni versement propre à un '
        'mode (FR et EN)', (tester) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      final images = tester.widgetList<Image>(find.byType(Image));
      final assets = images
          .map((i) => i.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName);
      expect(assets, contains(kSendIntroIllustration));
      expect(assets, isNot(contains('assets/illustrations/envoie_colis.png')));
      // « libéré à la livraison » est faux en bateau (payé au dépôt).
      expect(find.textContaining('livraison'), findsNothing);
      expect(
        find.text(
          'Paiement sécurisé : vous savez avant de payer quand le '
          'transporteur est payé.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('vérifié : case cochée puis Continuer ouvre le wizard', (
      tester,
    ) async {
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(
        find.text(
          'J\'ai lu et j\'ai pris connaissance de mes engagements en tant '
          'qu\'expéditeur.',
        ),
        findsOneWidget,
      );
      await _check(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      verify(
        () => _commitmentRepo.accept(PublishCommitmentRole.sender, '2026-10'),
      ).called(1);
      expect(visited, ['/package-requests/new']);
      expect(extras.single, isNull);
    });
  });

  group('PublishIntroScreen — feuille des brouillons', () {
    testWidgets('trajet : brouillon local et brouillon serveur proposés', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        localDraft: {
          'step': 1,
          'departureCity': 'Marseille',
          'arrivalCity': 'Douala',
        },
        serverDrafts: [tripFixture(id: 'srv')],
      );
      await tester.pumpAndSettle();

      expect(find.text('Terminer un trajet commencé ?'), findsOneWidget);
      expect(find.textContaining('Marseille → Douala'), findsOneWidget);
      expect(find.textContaining('étape 2 sur 3'), findsOneWidget);
      expect(find.textContaining('Paris → Dakar'), findsOneWidget);
      expect(find.text('Brouillon complet, prêt à publier'), findsOneWidget);
      expect(find.text('Créer un nouveau trajet'), findsOneWidget);
    });

    testWidgets('trajet : terminer le brouillon local le recharge', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        localDraft: {'step': 1, 'departureCity': 'Marseille'},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish-draft-local')));
      await tester.pumpAndSettle();

      expect(visited, ['/trips/create']);
      final args = extras.single! as CreateTripArgs;
      expect(args.resumeDraft?.departureCity, 'Marseille');
      expect(args.resumeDraft?.stepId, TripFormStep.capacite);
    });

    testWidgets('trajet : brouillon serveur ouvre sa fiche', (tester) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        serverDrafts: [tripFixture(id: 'srv')],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish-draft-server')));
      await tester.pumpAndSettle();

      expect(visited, ['/announcements/srv/trip']);
    });

    testWidgets(
      'trajet : « Créer un nouveau trajet » ouvre un formulaire vide',
      (tester) async {
        await _pump(
          tester,
          role: PublishIntroRole.trip,
          kycStatus: 'VERIFIED',
          commitmentRequired: false,
          localDraft: {'step': 0, 'departureCity': 'Lyon'},
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('publish-drafts-new')));
        await tester.pumpAndSettle();

        expect(visited, ['/trips/create']);
        expect((extras.single! as CreateTripArgs).resumeDraft, isNull);
      },
    );

    testWidgets('trajet : un modèle seul suffit à proposer la feuille', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        tripTemplates: [templateFixture(label: 'Navette Dakar')],
      );
      await tester.pumpAndSettle();

      expect(find.text("Partir d'un modèle ?"), findsOneWidget);
      expect(find.text('Navette Dakar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('publish-template-tpl-1')));
      await tester.pumpAndSettle();

      expect(visited, ['/trips/create']);
      final args = extras.single! as CreateTripArgs;
      expect(args.template?.id, 'tpl-1');
      expect(args.resumeDraft, isNull);
    });

    testWidgets('trajet : une série tient sur une ligne et ouvre Mes trajets', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        serverDrafts: [
          tripFixture(
            id: 's1',
            seriesId: 'serie',
            departureDate: DateTime(2026, 11, 27),
          ),
          tripFixture(
            id: 's2',
            seriesId: 'serie',
            departureDate: DateTime(2026, 12, 4),
          ),
        ],
        tripTemplates: [templateFixture()],
      );
      await tester.pumpAndSettle();

      expect(find.text('Paris → Dakar · 2 dates'), findsOneWidget);
      expect(find.text('Brouillons prêts à publier'), findsOneWidget);
      expect(find.byKey(const Key('publish-draft-server')), findsNothing);
      expect(find.byKey(const Key('publish-template-tpl-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('publish-draft-series')));
      await tester.pumpAndSettle();

      expect(visited, ['/announcements/trips?filter=draft']);
    });

    testWidgets('feuille fermée sans choix (écran sauté) : retour', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        localDraft: {'step': 0},
      );
      await tester.pumpAndSettle();

      expect(find.text('Ville à choisir → Ville à choisir'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(visited, ['/home']);
    });

    testWidgets('colis : terminer le brouillon local le transmet au wizard', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.parcel,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        localDraft: {'step': 1, 'departureCity': 'Paris'},
        serverDrafts: [requestFixture(id: 'r9')],
      );
      await tester.pumpAndSettle();

      expect(find.text('Terminer une demande commencée ?'), findsOneWidget);
      expect(find.text('Créer une nouvelle demande'), findsOneWidget);
      await tester.tap(find.byKey(const Key('publish-draft-local')));
      await tester.pumpAndSettle();

      expect(visited, ['/package-requests/new']);
      expect(
        (extras.single! as PackageRequestDraftResume).data['departureCity'],
        'Paris',
      );
    });

    testWidgets('colis : brouillon serveur ouvre « Ma demande »', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.parcel,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        serverDrafts: [requestFixture(id: 'r9')],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish-draft-server')));
      await tester.pumpAndSettle();

      expect(visited, ['/package-requests/r9']);
    });

    testWidgets('colis : « Créer une nouvelle demande » ouvre le wizard vide', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.parcel,
        kycStatus: 'VERIFIED',
        commitmentRequired: false,
        serverDrafts: [requestFixture(id: 'r9')],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish-drafts-new')));
      await tester.pumpAndSettle();

      expect(visited, ['/package-requests/new']);
      expect(extras.single, isNull);
    });

    testWidgets('après l\'écran des engagements : feuille fermée, on y reste', (
      tester,
    ) async {
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        serverDrafts: [tripFixture(id: 'srv')],
      );
      await _check(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Terminer un trajet commencé ?'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
      expect(find.text('Vos engagements de voyageur'), findsOneWidget);
    });
  });

  group('PublishIntroScreen — English', () {
    testWidgets('trajet, vérifié : titre et bouton traduits', (tester) async {
      useEnglish();
      await _pump(tester, role: PublishIntroRole.trip, kycStatus: 'VERIFIED');

      expect(find.text('Post a trip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('trajet, rappel Stripe traduit', (tester) async {
      useEnglish();
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'VERIFIED',
        stripeStatus: 'NOT_CREATED',
      );

      expect(find.text('Activate card payments'), findsOneWidget);
    });

    testWidgets('colis, vérifié : titre traduit', (tester) async {
      useEnglish();
      await _pump(tester, role: PublishIntroRole.parcel, kycStatus: 'VERIFIED');

      expect(find.text('Post a parcel'), findsOneWidget);
      expect(find.textContaining('delivery'), findsNothing);
      expect(
        find.text(
          'Secure payment: you know before paying when the carrier gets paid.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('trajet, non vérifié : phrase complète en anglais', (
      tester,
    ) async {
      useEnglish();
      await _pump(
        tester,
        role: PublishIntroRole.trip,
        kycStatus: 'NOT_STARTED',
      );

      expect(
        find.text(
          'Before you post, your identity must be verified. Go to '
          'Profile › Verifications to verify it (2 min).',
        ),
        findsOneWidget,
      );
    });
  });
}
