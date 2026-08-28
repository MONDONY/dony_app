import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockProfileRepository mockRepo;
  late MockAnalyticsService analytics;

  /// Le refus serveur quand la source de l'abonnement est Stripe et que le
  /// statut donne encore accès : `409` RFC 7807 dont la propriété `code`
  /// porte `active-stripe-subscription`. C'est `code` qui fait foi, jamais
  /// `title` ni `detail`.
  const tActiveStripeConflict = ConflictException(
    'Cancel your subscription from the billing portal first.',
    code: 'active-stripe-subscription',
  );

  setUp(() {
    mockRepo = MockProfileRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  UpgradeToProBloc bloc() => UpgradeToProBloc(mockRepo, analytics);

  test('initial state is UpgradeToProInitial', () {
    expect(bloc().state, isA<UpgradeToProInitial>());
  });

  group('DowngradeRequested', () {
    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, DowngradeSuccess] when downgradePro succeeds',
      build: () {
        when(() => mockRepo.downgradePro()).thenAnswer((_) async {});
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      expect: () => [isA<UpgradeToProLoading>(), isA<DowngradeSuccess>()],
      verify: (_) {
        verify(() => mockRepo.downgradePro()).called(1);
      },
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, DowngradeError] preserving the AppException',
      build: () {
        when(
          () => mockRepo.downgradePro(),
        ).thenThrow(const NetworkException('Network timeout'));
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<DowngradeError>().having(
          (s) => s.error,
          'error',
          isA<NetworkException>(),
        ),
      ],
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, DowngradeError] wrapping non-AppException via '
      'unwrapDioError',
      build: () {
        when(
          () => mockRepo.downgradePro(),
        ).thenThrow(Exception('Unexpected error'));
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<DowngradeError>().having(
          (s) => s.error,
          'error',
          isA<AppException>(),
        ),
      ],
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'a 409 active-stripe-subscription surfaces an error state carrying that '
      'exact code',
      build: () {
        when(() => mockRepo.downgradePro()).thenThrow(tActiveStripeConflict);
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      // Le code, jamais le message : c'est lui que l'écran doit reconnaître
      // pour renvoyer vers la gestion sur le web.
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<DowngradeError>().having(
          (s) => s.error.code,
          'error.code',
          'active-stripe-subscription',
        ),
      ],
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'a 409 active-stripe-subscription logs proDowngradeBlocked without any '
      'property',
      build: () {
        when(() => mockRepo.downgradePro()).thenThrow(tActiveStripeConflict);
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      verify: (_) {
        // `properties: null` n'est PAS un argument redondant ici : mocktail
        // compare les arguments nommés de l'invocation réelle à ceux de la
        // vérification. C'est lui qui garantit l'absence de PII, pas une
        // simple lecture du code. Vérifié par mutation : faire porter
        // `{'detail': error.message}` à l'event fait bien échouer ce test.
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.proDowngradeBlocked,
            // ignore: avoid_redundant_argument_values
            properties: null,
          ),
        ).called(1);
      },
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'an error that is NOT active-stripe-subscription never logs '
      'proDowngradeBlocked',
      build: () {
        when(() => mockRepo.downgradePro()).thenThrow(
          const ConflictException('Not a PRO account', code: 'not-pro-account'),
        );
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.proDowngradeBlocked,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'a tracking failure never swallows the error state',
      build: () {
        when(() => mockRepo.downgradePro()).thenThrow(tActiveStripeConflict);
        // `async => throw` reproduit une Future rejetée (rejet asynchrone),
        // pas une exception synchrone : c'est bien ce que produit un backend
        // analytics en panne.
        when(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        ).thenAnswer((_) async => throw Exception('analytics down'));
        return bloc();
      },
      act: (b) => b.add(const DowngradeRequested()),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<DowngradeError>().having(
          (s) => s.error.code,
          'error.code',
          'active-stripe-subscription',
        ),
      ],
    );
  });
}
