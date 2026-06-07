import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockReferralRepository extends Mock implements ReferralRepository {}

void main() {
  // Clipboard.setData requires binding to be initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReferralRepository mockRepo;

  setUp(() {
    mockRepo = MockReferralRepository();
  });

  ReferralBloc buildBloc() {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    analytics.onConfigured();
    return ReferralBloc(mockRepo, analytics);
  }

  const testInfo = ReferralInfo(
    code: 'DONY-ABC123',
    shareUrl: 'https://dony.app/invite/DONY-ABC123',
    totalInvited: 5,
    signedUp: 3,
    rewarded: 2,
    totalEarnedCents: 1000,
    hasBeenReferred: false,
  );

  // 1. État initial = ReferralInitial
  test('initial state is ReferralInitial', () {
    final bloc = buildBloc();
    expect(bloc.state, isA<ReferralInitial>());
    bloc.close();
  });

  // 2. ReferralLoadRequested → [ReferralLoading, ReferralLoaded]
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralLoading, ReferralLoaded] when load succeeds',
    setUp: () {
      when(() => mockRepo.getMyReferral()).thenAnswer((_) async => testInfo);
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralLoadRequested()),
    expect: () => [
      isA<ReferralLoading>(),
      isA<ReferralLoaded>(),
    ],
  );

  // 3. ReferralLoadRequested → [ReferralLoading, ReferralError] en cas d'exception
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralLoading, ReferralError] when load throws',
    setUp: () {
      when(() => mockRepo.getMyReferral())
          .thenThrow(Exception('Erreur réseau'));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralLoadRequested()),
    expect: () => [
      isA<ReferralLoading>(),
      isA<ReferralError>(),
    ],
  );

  // 4. ReferralLoaded contient le bon code
  blocTest<ReferralBloc, ReferralState>(
    'ReferralLoaded contains correct referral code',
    setUp: () {
      when(() => mockRepo.getMyReferral()).thenAnswer((_) async => testInfo);
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralLoadRequested()),
    expect: () => [
      isA<ReferralLoading>(),
      predicate<ReferralState>(
        (s) => s is ReferralLoaded && s.info.code == 'DONY-ABC123',
      ),
    ],
  );

  // 5. ReferralCodeCopied keeps state as ReferralLoaded
  blocTest<ReferralBloc, ReferralState>(
    'ReferralCodeCopied keeps state as ReferralLoaded after event',
    build: buildBloc,
    seed: () => const ReferralLoaded(testInfo),
    act: (bloc) => bloc.add(const ReferralCodeCopied()),
    verify: (bloc) {
      // State remains loaded regardless of clipboard emission
      expect(bloc.state, isA<ReferralLoaded>());
    },
  );

  // 6. ReferralCodeCopied does nothing if not in loaded state
  blocTest<ReferralBloc, ReferralState>(
    'ReferralCodeCopied does nothing when state is not ReferralLoaded',
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralCodeCopied()),
    expect: () => <ReferralState>[],
  );

  // 7. ReferralError contains the error message
  blocTest<ReferralBloc, ReferralState>(
    'ReferralError has non-empty message when exception is thrown',
    setUp: () {
      when(() => mockRepo.getMyReferral())
          .thenThrow(Exception('Service indisponible'));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralLoadRequested()),
    expect: () => [
      isA<ReferralLoading>(),
      predicate<ReferralState>(
        (s) => s is ReferralError && s.error.message.isNotEmpty,
      ),
    ],
  );

  // ── ReferralRedeemRequested tests ─────────────────────────────────────────

  // 8. Redeem success → [ReferralRedeemLoading, ReferralRedeemed]
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralRedeemLoading, ReferralRedeemed] when redeem succeeds',
    setUp: () {
      when(() => mockRepo.redeemCode(any())).thenAnswer((_) async {});
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralRedeemRequested('AISSA0012')),
    expect: () => [
      isA<ReferralRedeemLoading>(),
      isA<ReferralRedeemed>(),
    ],
  );

  // 9. referral-code-not-found → [ReferralRedeemLoading, ReferralRedeemError]
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralRedeemLoading, ReferralRedeemError] on referral-code-not-found',
    setUp: () {
      when(() => mockRepo.redeemCode(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          error: const NetworkException(
            'Code introuvable',
            code: 'referral-code-not-found',
          ),
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralRedeemRequested('INVALID')),
    expect: () => [
      isA<ReferralRedeemLoading>(),
      predicate<ReferralState>(
        (s) =>
            s is ReferralRedeemError &&
            s.error.code == 'referral-code-not-found',
      ),
    ],
  );

  // 10. self-referral → [ReferralRedeemLoading, ReferralRedeemError]
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralRedeemLoading, ReferralRedeemError] on self-referral',
    setUp: () {
      when(() => mockRepo.redeemCode(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          error: const NetworkException(
            'Auto-parrainage',
            code: 'self-referral',
          ),
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralRedeemRequested('MYOWNCODE')),
    expect: () => [
      isA<ReferralRedeemLoading>(),
      predicate<ReferralState>(
        (s) => s is ReferralRedeemError && s.error.code == 'self-referral',
      ),
    ],
  );

  // 11. already-referred → [ReferralRedeemLoading, ReferralRedeemError]
  blocTest<ReferralBloc, ReferralState>(
    'emits [ReferralRedeemLoading, ReferralRedeemError] on already-referred',
    setUp: () {
      when(() => mockRepo.redeemCode(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          error: const NetworkException(
            'Déjà parrainé',
            code: 'already-referred',
          ),
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const ReferralRedeemRequested('JEAN0234')),
    expect: () => [
      isA<ReferralRedeemLoading>(),
      predicate<ReferralState>(
        (s) => s is ReferralRedeemError && s.error.code == 'already-referred',
      ),
    ],
  );
}
