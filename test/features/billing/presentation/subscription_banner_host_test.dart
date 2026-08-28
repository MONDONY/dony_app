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

/// Assez long pour laisser les délais `flutter_animate` du bandeau se
/// terminer, sans dépendre d'un `pumpAndSettle` qui boucle indéfiniment sur
/// une animation en continu.
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
    registerFallbackValue(const ProPortalOpenRequested(ProPortalTarget.upgrade));
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
      'active sans résiliation : rien n\'est rendu, aucun espace résiduel',
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

        // `SubscriptionStatusBanner` est bien instancié (l'état est chargé,
        // c'est à lui de décider s'il y a quelque chose à signaler) : le
        // composant visuellement porteur d'une alerte, lui, doit être
        // absent.
        expect(find.byType(DonyStatusBanner), findsNothing);
        // Discriminant : une taille non nulle prouverait un espace vide
        // résiduel dans la liste, même sans texte ni bandeau visible.
        final size = tester.getSize(find.byType(SubscriptionBannerHost));
        expect(size, Size.zero);
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

    testWidgets(
      "tap sur l'action d'une grâce historique envoie "
      'ProPortalOpenRequested(upgrade)',
      (tester) async {
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
          () => mockBloc.add(
            const ProPortalOpenRequested(ProPortalTarget.upgrade),
          ),
        ).called(1);
      },
    );

    testWidgets(
      "l'échec d'ouverture du portail affiche un message et laisse le "
      'bandeau affiché',
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

        controller.add(
          const SubscriptionPortalLaunchFailed(tPastDueSubscription),
        );
        await tester.pump();
        controller.add(const SubscriptionLoaded(tPastDueSubscription));
        await tester.pump();

        // Discriminant : si le listener n'écoutait pas
        // SubscriptionPortalLaunchFailed, aucun SnackBar n'apparaîtrait.
        expect(find.byType(SnackBar), findsOneWidget);
        // Discriminant : si l'état transitoire était traité par le
        // `builder` (au lieu du `listener`), le bandeau disparaîtrait
        // momentanément au lieu de rester affiché.
        expect(find.byType(SubscriptionStatusBanner), findsOneWidget);
      },
    );
  });
}
