import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/billing/data/billing_repository.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockUrlLauncherPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class _FakeLaunchOptions extends Fake implements LaunchOptions {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

const _activeSubscriptionJson = {
  'active': true,
  'status': 'ACTIVE',
  'source': 'STRIPE',
  'billingCycle': 'monthly',
  'currentPeriodEnd': '2026-09-28T00:00:00.000Z',
  'cancelAtPeriodEnd': false,
  'graceExpiresAt': null,
};

const _noneSubscriptionJson = {
  'active': false,
  'status': 'NONE',
  'source': null,
  'billingCycle': null,
  'currentPeriodEnd': null,
  'cancelAtPeriodEnd': false,
  'graceExpiresAt': null,
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeLaunchOptions());
  });

  late MockApiClient mockClient;
  late MockDio mockDio;
  late MockUrlLauncherPlatform mockLauncher;
  late BillingRepository repository;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    mockLauncher = MockUrlLauncherPlatform();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = BillingRepository(mockClient, launcher: mockLauncher);
  });

  group('getSubscription', () {
    test('une réponse active rend un ProSubscriptionModel correspondant '
        'et appelle GET /billing/subscription', () async {
      when(() => mockDio.get('/billing/subscription')).thenAnswer(
        (_) async => _ok(_activeSubscriptionJson, '/billing/subscription'),
      );

      final result = await repository.getSubscription();

      expect(result, ProSubscriptionModel.fromJson(_activeSubscriptionJson));
      expect(result.status, ProSubscriptionStatus.active);
      verify(() => mockDio.get('/billing/subscription')).called(1);
    });

    test('la charge utile « aucun abonnement » rend un modèle de statut none, '
        'sans lever', () async {
      when(() => mockDio.get('/billing/subscription')).thenAnswer(
        (_) async => _ok(_noneSubscriptionJson, '/billing/subscription'),
      );

      final result = await repository.getSubscription();

      expect(result.status, ProSubscriptionStatus.none);
      expect(result.active, isFalse);
    });

    test(
      'une DioException réseau est convertie en AppException et relancée',
      () async {
        when(() => mockDio.get('/billing/subscription')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/billing/subscription'),
            type: DioExceptionType.connectionError,
          ),
        );

        expect(
          () => repository.getSubscription(),
          throwsA(isA<OfflineException>()),
        );
      },
    );
  });

  group('openExternal', () {
    test('une URI https valide déclenche l’ouverture en navigateur externe '
        'et rend true', () async {
      when(
        () => mockLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      final result = await repository.openExternal(
        Uri.parse('https://yadony.com/pro/upgrade'),
      );

      expect(result, isTrue);
      final captured = verify(
        () => mockLauncher.launchUrl(
          'https://yadony.com/pro/upgrade',
          captureAny(),
        ),
      ).captured;
      final options = captured.single as LaunchOptions;
      expect(options.mode, PreferredLaunchMode.externalApplication);
    });

    test('un lanceur qui rend false fait rendre false au repository', () async {
      when(
        () => mockLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => false);

      final result = await repository.openExternal(
        Uri.parse('https://yadony.com/pro/upgrade'),
      );

      expect(result, isFalse);
    });

    test('un lanceur qui lève une PlatformException fait rendre false, '
        'sans propager', () async {
      when(
        () => mockLauncher.launchUrl(any(), any()),
      ).thenThrow(PlatformException(code: 'launch_failed'));

      final result = await repository.openExternal(
        Uri.parse('https://yadony.com/pro/upgrade'),
      );

      expect(result, isFalse);
    });

    test(
      'une URI de schéma non https rend false sans appeler le lanceur',
      () async {
        final result = await repository.openExternal(
          Uri.parse('http://yadony.com/pro/upgrade'),
        );

        expect(result, isFalse);
        verifyNever(() => mockLauncher.launchUrl(any(), any()));
      },
    );

    test('une URI sans hôte rend false sans appeler le lanceur', () async {
      final result = await repository.openExternal(
        Uri.parse('https:///upgrade'),
      );

      expect(result, isFalse);
      verifyNever(() => mockLauncher.launchUrl(any(), any()));
    });
  });
}
