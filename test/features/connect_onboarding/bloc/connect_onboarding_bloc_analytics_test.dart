import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements IConnectOnboardingRepository {}

const _pending = ConnectAccountStatus(status: 'PENDING_ONBOARDING');
const _complete = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
const _rejected = ConnectAccountStatus(
  status: 'REJECTED',
  reason: 'Docs invalides',
);

/// L'étape « paiements » de l'inscription n'émettait aucun événement : 27
/// personnes la voyaient, on ignorait combien l'avaient terminée.
void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;
  late ConnectOnboardingBloc bloc;

  setUp(() async {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    bloc = ConnectOnboardingBloc(repo, analytics: analytics);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('lien obtenu : connect_onboarding_link_opened', () async {
    when(repo.createConnectAccount).thenAnswer((_) async => _pending);
    when(
      repo.createOnboardingLink,
    ).thenAnswer((_) async => 'https://connect.stripe.com/setup/abc');

    bloc.add(const ConnectOnboardingLinkRequested());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingUrlReady);
    await settle();

    verify(
      () => backend.capture(AnalyticsEvents.connectOnboardingLinkOpened, any()),
    ).called(1);
  });

  test(
    'retour de Stripe, compte actif : connect_onboarding_completed',
    () async {
      when(repo.getAccountStatus).thenAnswer((_) async => _complete);

      bloc.add(const ConnectOnboardingPollingRequested());
      await bloc.stream.firstWhere((s) => s is ConnectOnboardingComplete);
      await settle();

      verify(
        () =>
            backend.capture(AnalyticsEvents.connectOnboardingCompleted, any()),
      ).called(1);
    },
  );

  test('retour de Stripe, formulaire pas fini : still_pending', () async {
    when(repo.getAccountStatus).thenAnswer((_) async => _pending);

    bloc.add(const ConnectOnboardingPollingRequested());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingPending);
    await settle();

    verify(
      () =>
          backend.capture(AnalyticsEvents.connectOnboardingStillPending, any()),
    ).called(1);
  });

  test('refus Stripe : failed avec l\'étape et le motif', () async {
    when(repo.getAccountStatus).thenAnswer((_) async => _rejected);

    bloc.add(const ConnectOnboardingPollingRequested());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingRejected);
    await settle();

    verify(
      () => backend.capture(AnalyticsEvents.connectOnboardingFailed, {
        'stage': 'rejected',
        'reason': 'Docs invalides',
      }),
    ).called(1);
  });

  test('échec du lien : failed avec le code d\'erreur', () async {
    when(
      repo.createConnectAccount,
    ).thenThrow(const ConflictException('stripe-account-required'));

    bloc.add(const ConnectOnboardingLinkRequested());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingError);
    await settle();

    final captured = verify(
      () => backend.capture(
        AnalyticsEvents.connectOnboardingFailed,
        captureAny(),
      ),
    ).captured;
    expect(captured.single, containsPair('stage', 'link'));
  });

  test('navigateur impossible à ouvrir : failed au lancement', () async {
    bloc.add(const ConnectOnboardingLaunchFailed());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingError);
    await settle();

    verify(
      () => backend.capture(AnalyticsEvents.connectOnboardingFailed, {
        'stage': 'launch',
        'reason': 'launch-failed',
      }),
    ).called(1);
  });

  test('statut initial déjà actif : pas d\'activation comptée', () async {
    when(repo.getAccountStatus).thenAnswer((_) async => _complete);

    bloc.add(const ConnectOnboardingStatusRequested());
    await bloc.stream.firstWhere((s) => s is ConnectOnboardingComplete);
    await settle();

    verifyNever(
      () => backend.capture(AnalyticsEvents.connectOnboardingCompleted, any()),
    );
  });
}
