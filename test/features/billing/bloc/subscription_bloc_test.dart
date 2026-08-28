import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/billing_repository.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockBillingRepository repository;
  late _MockAnalyticsService analytics;

  const tActiveSubscription = ProSubscriptionModel(
    active: true,
    status: ProSubscriptionStatus.active,
    source: ProSubscriptionSource.stripe,
    billingCycle: 'monthly',
    currentPeriodEnd: null,
    cancelAtPeriodEnd: false,
    graceExpiresAt: null,
  );

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.invalid'));
  });

  setUp(() {
    repository = _MockBillingRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SubscriptionBloc bloc() => SubscriptionBloc(repository, analytics);

  test('initial state is SubscriptionInitial', () {
    expect(bloc().state, isA<SubscriptionInitial>());
  });

  group('SubscriptionRequested', () {
    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits [Loading, Loaded] with the subscription returned by the repository',
      build: () {
        when(
          () => repository.getSubscription(),
        ).thenAnswer((_) async => tActiveSubscription);
        return bloc();
      },
      act: (b) => b.add(const SubscriptionRequested()),
      expect: () => [
        isA<SubscriptionLoading>(),
        isA<SubscriptionLoaded>().having(
          (s) => s.subscription,
          'subscription',
          tActiveSubscription,
        ),
      ],
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'logs proSubscriptionViewed with only the status property, no PII',
      build: () {
        when(
          () => repository.getSubscription(),
        ).thenAnswer((_) async => tActiveSubscription);
        return bloc();
      },
      act: (b) => b.add(const SubscriptionRequested()),
      verify: (_) {
        // Discriminant : mocktail exige une égalité stricte de la map. Si le
        // BLoC ajoutait une date, un identifiant Stripe ou toute autre
        // propriété (ou changeait la clé/valeur de `status`), cette
        // vérification échouerait.
        verify(
          () => analytics.logEvent(
            'pro_subscription_viewed',
            properties: {'status': 'active'},
          ),
        ).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'emits [Loading, Error] with the exception thrown by the repository',
      build: () {
        when(
          () => repository.getSubscription(),
        ).thenThrow(const NetworkException('boom', code: 'SERVER_ERROR'));
        return bloc();
      },
      act: (b) => b.add(const SubscriptionRequested()),
      expect: () => [
        isA<SubscriptionLoading>(),
        isA<SubscriptionError>().having(
          (s) => s.error,
          'error',
          const NetworkException('boom', code: 'SERVER_ERROR'),
        ),
      ],
    );
  });

  group('ProPortalOpenRequested', () {
    blocTest<SubscriptionBloc, SubscriptionState>(
      'opens the exact upgrade portal URI for ProPortalTarget.upgrade',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => true);
        return bloc();
      },
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.upgrade)),
      verify: (_) {
        // Discriminant : si le BLoC inversait les deux cibles (envoyait
        // l'URI de gestion pour `upgrade`), cette assertion sur l'URI exacte
        // échouerait alors qu'une simple assertion "un appel a eu lieu"
        // aurait laissé passer l'inversion.
        verify(
          () => repository.openExternal(Uri.parse(proPortalUpgradeUrl())),
        ).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'opens the exact subscription-management portal URI for ProPortalTarget.manage',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => true);
        return bloc();
      },
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.manage)),
      verify: (_) {
        // Discriminant : symétrique du test ci-dessus, côté `manage`. Les
        // deux tests ensemble empêchent l'inversion dans les deux sens.
        verify(
          () => repository.openExternal(Uri.parse(proPortalSubscriptionUrl())),
        ).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'logs proPortalOpened with the target on success',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => true);
        return bloc();
      },
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.manage)),
      expect: () => <SubscriptionState>[],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            'pro_portal_opened',
            properties: {'target': 'manage'},
          ),
        ).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'a failed launch emits PortalLaunchFailed then restores the previous '
      'loaded state, so the screen stays displayed',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => false);
        return bloc();
      },
      seed: () => const SubscriptionLoaded(tActiveSubscription),
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.upgrade)),
      // Discriminant : si `SubscriptionPortalLaunchFailed` devenait un
      // drapeau porté par `SubscriptionLoaded` au lieu d'un état transitoire
      // distinct, cette séquence de deux états ne serait plus émise (une
      // seule notification "Loaded" identique, filtrée par Equatable).
      expect: () => [
        const SubscriptionPortalLaunchFailed(tActiveSubscription),
        const SubscriptionLoaded(tActiveSubscription),
      ],
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'a failed launch logs proPortalOpenFailed',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => false);
        return bloc();
      },
      seed: () => const SubscriptionLoaded(tActiveSubscription),
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.upgrade)),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            'pro_portal_open_failed',
            properties: {'target': 'upgrade'},
          ),
        ).called(1);
      },
    );

    blocTest<SubscriptionBloc, SubscriptionState>(
      'a failed launch with no subscription loaded yet does not crash: '
      'emits PortalLaunchFailed(null) then restores SubscriptionInitial',
      build: () {
        when(
          () => repository.openExternal(any()),
        ).thenAnswer((_) async => false);
        return bloc();
      },
      act: (b) => b.add(const ProPortalOpenRequested(ProPortalTarget.manage)),
      expect: () => [
        const SubscriptionPortalLaunchFailed(null),
        const SubscriptionInitial(),
      ],
    );
  });
}
