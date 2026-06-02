import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReferralRepository extends Mock implements ReferralRepository {}

void main() {
  // Clipboard.setData requires binding to be initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReferralRepository mockRepo;

  setUp(() {
    mockRepo = MockReferralRepository();
  });

  ReferralBloc buildBloc() => ReferralBloc(mockRepo);

  const testInfo = ReferralInfo(
    code: 'DONY-ABC123',
    shareUrl: 'https://dony.app/invite/DONY-ABC123',
    totalInvited: 5,
    signedUp: 3,
    rewarded: 2,
    totalEarnedCents: 1000,
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
}
