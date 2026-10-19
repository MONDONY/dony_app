import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements IConnectOnboardingRepository {}

const _url = 'https://connect.stripe.com/express/abc';

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() async {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  Future<BankAccountLinkCubit> build() async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    return BankAccountLinkCubit(repo, analytics);
  }

  Map<String, Object> lastFailedProps() =>
      verify(
            () => backend.capture(
              AnalyticsEvents.bankAccountChangeLinkFailed,
              captureAny(),
            ),
          ).captured.last
          as Map<String, Object>;

  test('état initial : repos', () async {
    final cubit = await build();
    expect(cubit.state, isA<BankAccountLinkIdle>());
    await cubit.close();
  });

  blocTest<BankAccountLinkCubit, BankAccountLinkState>(
    'succès : chargement puis lien, analytics avec la source',
    setUp: () => when(repo.createDashboardLink).thenAnswer((_) async => _url),
    build: () => BankAccountLinkCubit(repo, makeEnabledAnalytics(backend)),
    act: (c) async {
      await c.request(BankAccountLinkSource.bankPayoutSheet);
      c.handled();
    },
    expect: () => [
      isA<BankAccountLinkLoading>(),
      isA<BankAccountLinkReady>().having((s) => s.url, 'url', _url),
      isA<BankAccountLinkIdle>(),
    ],
  );

  test('succès : bank_account_change_link_opened', () async {
    when(repo.createDashboardLink).thenAnswer((_) async => _url);
    final cubit = await build();
    await cubit.request(BankAccountLinkSource.payoutsScreen);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => backend.capture(AnalyticsEvents.bankAccountChangeLinkOpened, {
        'source': 'payouts_screen',
      }),
    ).called(1);
    await cubit.close();
  });

  test('lien jamais mis en cache : un appel par tap', () async {
    when(repo.createDashboardLink).thenAnswer((_) async => _url);
    final cubit = await build();
    await cubit.request(BankAccountLinkSource.payoutsScreen);
    cubit.handled();
    await cubit.request(BankAccountLinkSource.payoutsScreen);
    verify(repo.createDashboardLink).called(2);
    await cubit.close();
  });

  Future<void> expectFailure(
    Object error,
    BankAccountLinkFailure failure,
    String code,
  ) async {
    when(repo.createDashboardLink).thenThrow(error);
    final cubit = await build();
    await cubit.request(BankAccountLinkSource.bankPayoutSheet);
    final state = cubit.state;
    expect(state, isA<BankAccountLinkFailed>());
    expect((state as BankAccountLinkFailed).failure, failure);
    await Future<void>.delayed(Duration.zero);
    expect(lastFailedProps(), {
      'source': 'bank_payout_sheet',
      'reason': failure.analyticsValue,
      'error_code': code,
    });
    await cubit.close();
  }

  test('404 stripe-account-missing : compte absent', () async {
    await expectFailure(
      const NotFoundException(apiCode: 'stripe-account-missing'),
      BankAccountLinkFailure.accountMissing,
      'stripe-account-missing',
    );
  });

  test('409 stripe-onboarding-incomplete : inscription à finir', () async {
    await expectFailure(
      const ConflictException('x', code: 'stripe-onboarding-incomplete'),
      BankAccountLinkFailure.onboardingIncomplete,
      'stripe-onboarding-incomplete',
    );
  });

  test('ancien back, 404 sans code : disponible bientôt', () async {
    await expectFailure(
      const NotFoundException(),
      BankAccountLinkFailure.unavailable,
      'NOT_FOUND',
    );
  });

  test('ancien back, 405 : disponible bientôt', () async {
    await expectFailure(
      const NetworkException('x', code: '405'),
      BankAccountLinkFailure.unavailable,
      '405',
    );
  });

  test('erreur réseau : erreur générique', () async {
    await expectFailure(
      const OfflineException(),
      BankAccountLinkFailure.error,
      'OFFLINE',
    );
  });

  test('navigateur non ouvert : launch', () async {
    final cubit = await build();
    cubit.launchFailed();
    expect(
      (cubit.state as BankAccountLinkFailed).failure,
      BankAccountLinkFailure.launch,
    );
    await Future<void>.delayed(Duration.zero);
    expect(lastFailedProps()['error_code'], 'unknown');
    await cubit.close();
  });

  test('second tap pendant le chargement ignoré', () async {
    when(repo.createDashboardLink).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _url;
    });
    final cubit = await build();
    final first = cubit.request(BankAccountLinkSource.payoutsScreen);
    await cubit.request(BankAccountLinkSource.payoutsScreen);
    await first;
    verify(repo.createDashboardLink).called(1);
    await cubit.close();
  });

  test('fermé pendant l\'appel : aucun état émis', () async {
    when(repo.createDashboardLink).thenAnswer((_) async => _url);
    final cubit = await build();
    final pending = cubit.request(BankAccountLinkSource.payoutsScreen);
    await cubit.close();
    await pending;
    cubit.handled();
  });

  test('fermé pendant une erreur : aucun état émis', () async {
    when(repo.createDashboardLink).thenThrow(const OfflineException());
    final cubit = await build();
    final pending = cubit.request(BankAccountLinkSource.payoutsScreen);
    await cubit.close();
    await pending;
  });
}
