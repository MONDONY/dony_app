import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/billing_repository.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_banner_host.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockBillingRepository extends Mock implements BillingRepository {}

class MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

/// Assez long pour laisser le pipeline asynchrone du BLoC se terminer après
/// le montage (event initial envoyé, réponse du repository ou du stream
/// mocké, puis rebuild), sans dépendre d'un `pumpAndSettle` qui ne rendrait
/// jamais la main sur un `StreamController` resté ouvert (utilisé par
/// plusieurs tests ci-dessous). Ni `SubscriptionStatusBanner` ni
/// `DonyStatusBanner` n'utilisent `flutter_animate` : ce délai n'a rien à
/// voir avec une animation.
const _kSettle = Duration(milliseconds: 600);

const tActiveSubscription = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.active,
  source: ProSubscriptionSource.stripe,
  billingCycle: 'monthly',
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

const tPastDueSubscription = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.pastDue,
  source: ProSubscriptionSource.stripe,
  billingCycle: 'monthly',
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

const tLegacyGraceSubscription = ProSubscriptionModel(
  active: true,
  status: ProSubscriptionStatus.legacyGrace,
  source: ProSubscriptionSource.legacyFree,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void _registerMockBloc(MockSubscriptionBloc bloc) {
  if (getIt.isRegistered<SubscriptionBloc>()) {
    getIt.unregister<SubscriptionBloc>();
  }
  getIt.registerFactory<SubscriptionBloc>(() => bloc);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const SubscriptionRequested());
    registerFallbackValue(
      const ProPortalOpenRequested(ProPortalTarget.upgrade),
    );
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  // ── Porte réseau : isProAccount ─────────────────────────────────────────

  group('SubscriptionBannerHost — isProAccount gate', () {
    late MockBillingRepository mockRepo;

    setUp(() {
      mockRepo = MockBillingRepository();
      if (getIt.isRegistered<BillingRepository>()) {
        getIt.unregister<BillingRepository>();
      }
      getIt.registerLazySingleton<BillingRepository>(() => mockRepo);
      if (getIt.isRegistered<SubscriptionBloc>()) {
        getIt.unregister<SubscriptionBloc>();
      }
      getIt.registerFactory<SubscriptionBloc>(
        () => SubscriptionBloc(
          getIt<BillingRepository>(),
          getIt<AnalyticsService>(),
        ),
      );
    });

    tearDown(() {
      if (getIt.isRegistered<BillingRepository>()) {
        getIt.unregister<BillingRepository>();
      }
      if (getIt.isRegistered<SubscriptionBloc>()) {
        getIt.unregister<SubscriptionBloc>();
      }
    });

    testWidgets(
      'isProAccount=false: no BLoC is created, no network call, renders '
      'nothing',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: false)),
        );
        await tester.pump(_kSettle);

        // Discriminant : si le widget créait le BLoC puis se contentait de ne
        // pas lui envoyer d'event, ce provider existerait quand même dans
        // l'arbre.
        expect(find.byType(BlocProvider<SubscriptionBloc>), findsNothing);
        expect(find.byType(SubscriptionStatusBanner), findsNothing);
        verifyNever(() => mockRepo.getSubscription());
      },
    );

    testWidgets('isProAccount=true: calls getSubscription exactly once', (
      tester,
    ) async {
      when(
        () => mockRepo.getSubscription(),
      ).thenAnswer((_) async => tActiveSubscription);

      await tester.pumpWidget(
        _wrap(const SubscriptionBannerHost(isProAccount: true)),
      );
      await tester.pump(_kSettle);

      verify(() => mockRepo.getSubscription()).called(1);
    });
  });

  // ── Rendu selon l'état du BLoC ───────────────────────────────────────────

  group('SubscriptionBannerHost — state rendering', () {
    late MockSubscriptionBloc mockBloc;

    setUp(() {
      mockBloc = MockSubscriptionBloc();
      _registerMockBloc(mockBloc);
    });

    tearDown(() {
      if (getIt.isRegistered<SubscriptionBloc>()) {
        getIt.unregister<SubscriptionBloc>();
      }
    });

    testWidgets('pastDue: le bandeau est rendu', (tester) async {
      whenListen<SubscriptionState>(
        mockBloc,
        Stream.value(const SubscriptionLoaded(tPastDueSubscription)),
        initialState: const SubscriptionLoaded(tPastDueSubscription),
      );

      await tester.pumpWidget(
        _wrap(const SubscriptionBannerHost(isProAccount: true)),
      );
      await tester.pump(_kSettle);

      expect(find.byType(SubscriptionStatusBanner), findsOneWidget);
    });

    testWidgets(
      'active sans résiliation : rien n\'est rendu, aucun espace résiduel, '
      'espacement compris',
      (tester) async {
        whenListen<SubscriptionState>(
          mockBloc,
          Stream.value(const SubscriptionLoaded(tActiveSubscription)),
          initialState: const SubscriptionLoaded(tActiveSubscription),
        );

        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: true)),
        );
        await tester.pump(_kSettle);

        expect(find.byType(DonyStatusBanner), findsNothing);
        // Discriminant : c'est le composant lui-même, et non son appelant
        // (`profile_screen.dart`), qui doit porter son propre espacement de
        // section. Une taille non nulle ici prouverait soit un espace vide
        // résiduel, soit un espacement laissé à la charge de l'appelant —
        // dans les deux cas, un vide apparaîtrait dans la liste pour la
        // majorité des comptes (non-PRO ou sans rien à signaler).
        final size = tester.getSize(find.byType(SubscriptionBannerHost));
        expect(size, Size.zero);
      },
    );

    testWidgets(
      "l'espacement de section suit le bandeau, et seulement quand il "
      's\'affiche',
      (tester) async {
        whenListen<SubscriptionState>(
          mockBloc,
          Stream.value(const SubscriptionLoaded(tPastDueSubscription)),
          initialState: const SubscriptionLoaded(tPastDueSubscription),
        );

        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: true)),
        );
        await tester.pump(_kSettle);

        final hostHeight = tester
            .getSize(find.byType(SubscriptionBannerHost))
            .height;
        final bannerHeight = tester
            .getSize(find.byType(SubscriptionStatusBanner))
            .height;

        // Discriminant : si l'espacement de section restait porté par
        // l'appelant (comme avant ce correctif) plutôt que par le composant
        // lui-même, la hauteur du host égalerait exactement celle du
        // bandeau, sans les `DonySpacing.lg` supplémentaires attendus après
        // lui.
        expect(hostHeight, bannerHeight + DonySpacing.lg);
      },
    );

    testWidgets('erreur : rien n\'est rendu, aucun message ne s\'affiche', (
      tester,
    ) async {
      whenListen<SubscriptionState>(
        mockBloc,
        Stream.value(
          const SubscriptionError(
            NetworkException('boom', code: 'SERVER_ERROR'),
          ),
        ),
        initialState: const SubscriptionError(
          NetworkException('boom', code: 'SERVER_ERROR'),
        ),
      );

      await tester.pumpWidget(
        _wrap(const SubscriptionBannerHost(isProAccount: true)),
      );
      await tester.pump(_kSettle);

      expect(find.byType(SubscriptionStatusBanner), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      final size = tester.getSize(find.byType(SubscriptionBannerHost));
      expect(size, Size.zero);
    });

    testWidgets(
      'chargement : rien n\'est rendu, pas d\'indicateur de progression',
      (tester) async {
        whenListen<SubscriptionState>(
          mockBloc,
          Stream.value(const SubscriptionLoading()),
          initialState: const SubscriptionLoading(),
        );

        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: true)),
        );
        await tester.pump(_kSettle);

        expect(find.byType(SubscriptionStatusBanner), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final size = tester.getSize(find.byType(SubscriptionBannerHost));
        expect(size, Size.zero);
      },
    );

    testWidgets(
      "tap sur l'action d'un impayé envoie ProPortalOpenRequested(manage)",
      (tester) async {
        whenListen<SubscriptionState>(
          mockBloc,
          Stream.value(const SubscriptionLoaded(tPastDueSubscription)),
          initialState: const SubscriptionLoaded(tPastDueSubscription),
        );

        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: true)),
        );
        await tester.pump(_kSettle);

        await tester.tap(find.text('Régler'));
        await tester.pump();

        // Discriminant : si la cible était inversée, cet événement précis ne
        // serait jamais envoyé (un `upgrade` le serait à la place) et
        // `verify` échouerait.
        verify(
          () => mockBloc.add(
            const ProPortalOpenRequested(ProPortalTarget.manage),
          ),
        ).called(1);
      },
    );

    testWidgets("tap sur l'action d'une grâce historique envoie "
        'ProPortalOpenRequested(upgrade)', (tester) async {
      whenListen<SubscriptionState>(
        mockBloc,
        Stream.value(const SubscriptionLoaded(tLegacyGraceSubscription)),
        initialState: const SubscriptionLoaded(tLegacyGraceSubscription),
      );

      await tester.pumpWidget(
        _wrap(const SubscriptionBannerHost(isProAccount: true)),
      );
      await tester.pump(_kSettle);

      await tester.tap(find.text("S'abonner"));
      await tester.pump();

      // Discriminant : symétrique du test ci-dessus ; les deux ensemble
      // empêchent l'inversion des cibles dans les deux sens.
      verify(
        () =>
            mockBloc.add(const ProPortalOpenRequested(ProPortalTarget.upgrade)),
      ).called(1);
    });

    testWidgets(
      'deux SubscriptionPortalLaunchFailed distincts affichent chacun leur '
      'message (le filtrage Equatable est prouvé côté BLoC)',
      (tester) async {
        final controller = StreamController<SubscriptionState>();
        addTearDown(controller.close);
        whenListen<SubscriptionState>(
          mockBloc,
          controller.stream,
          initialState: const SubscriptionLoaded(tPastDueSubscription),
        );

        await tester.pumpWidget(
          _wrap(const SubscriptionBannerHost(isProAccount: true)),
        );
        await tester.pump(_kSettle);

        // 1er échec : le message apparaît.
        controller.add(
          const SubscriptionPortalLaunchFailed(tPastDueSubscription),
        );
        await tester.pump();
        controller.add(const SubscriptionLoaded(tPastDueSubscription));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        // Le bandeau reste affiché pendant tout l'épisode : l'état
        // transitoire est traité par le `listener`, jamais par le
        // `builder`.
        expect(find.byType(SubscriptionStatusBanner), findsOneWidget);

        // Fait disparaître le message explicitement (plutôt que d'attendre
        // sa durée par défaut, minuterie plus fragile à piloter dans un
        // test) : une réapparition plus bas prouve un second déclenchement
        // distinct, pas le même message resté affiché.
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .hideCurrentSnackBar();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SnackBar), findsNothing);

        // Contourne le dédoublonnage interne de `DonySnackbar` (fenêtre de
        // 400 ms en horloge réelle, sans rapport avec ce que ce test
        // vérifie) : sans ça, deux appels rapprochés en temps réel
        // d'exécution du test seraient fusionnés par `DonySnackbar`
        // lui-même, masquant le comportement du BLoC que ce test cible.
        DonySnackbar.clearDedup();

        // 2e échec, avec exactement le même abonnement que le premier.
        controller.add(
          const SubscriptionPortalLaunchFailed(tPastDueSubscription),
        );
        await tester.pump();
        controller.add(const SubscriptionLoaded(tPastDueSubscription));
        await tester.pump();

        // Ce test prouve que le widget répond bien à une seconde
        // `SubscriptionPortalLaunchFailed` distincte (le listener n'a pas de
        // filtrage propre qui l'empêcherait de ré-afficher un message
        // identique) : il pilote un stream brut, qui délivre sans filtrage
        // tout ce qu'on y pousse, et ne peut donc pas, à lui seul, démontrer
        // que la seconde émission n'est pas avalée par Equatable dans le
        // vrai BLoC. Cette garantie-là est prouvée côté BLoC, voir
        // `subscription_bloc_test.dart` : « two consecutive failed launches
        // each emit their own PortalLaunchFailed ».
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
