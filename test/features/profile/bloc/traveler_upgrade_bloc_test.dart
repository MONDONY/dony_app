import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/traveler_upgrade_bloc.dart';
import 'package:dony/features/profile/data/traveler_upgrade_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTravelerUpgradeRepository extends Mock
    implements TravelerUpgradeRepository {}

UserModel _fakeUser() => const UserModel(
      id: 'user-123',
      kycStatus: 'VERIFIED',
      stripeAccountStatus: 'ONBOARDING_COMPLETE',
      status: 'ACTIVE',
      roles: ['SENDER', 'TRAVELER'],
    );

void main() {
  late MockTravelerUpgradeRepository mockRepo;

  setUp(() {
    mockRepo = MockTravelerUpgradeRepository();
  });

  test('état initial est TravelerUpgradeInitial', () {
    final bloc = TravelerUpgradeBloc(mockRepo);
    expect(bloc.state, const TravelerUpgradeInitial());
    bloc.close();
  });

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'émet [Loading, Success] quand l\'activation réussit',
    build: () {
      when(() => mockRepo.activateTravelerRole())
          .thenAnswer((_) async => _fakeUser());
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) => bloc.add(const TravelerUpgradeActivateRequested()),
    expect: () => [
      const TravelerUpgradeLoading(),
      TravelerUpgradeSuccess(_fakeUser()),
    ],
    verify: (_) {
      verify(() => mockRepo.activateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'émet [Loading, Error] avec ConflictException quand les prérequis KYC/Stripe manquent',
    build: () {
      when(() => mockRepo.activateTravelerRole()).thenThrow(
        const ConflictException('KYC ou Stripe non complété'),
      );
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) => bloc.add(const TravelerUpgradeActivateRequested()),
    expect: () => [
      const TravelerUpgradeLoading(),
      const TravelerUpgradeError(
        ConflictException('KYC ou Stripe non complété'),
      ),
    ],
    verify: (_) {
      verify(() => mockRepo.activateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'émet [Loading, Error] avec NetworkException pour toute erreur réseau',
    build: () {
      when(() => mockRepo.activateTravelerRole()).thenThrow(
        const NetworkException('Erreur réseau'),
      );
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) => bloc.add(const TravelerUpgradeActivateRequested()),
    expect: () => [
      const TravelerUpgradeLoading(),
      const TravelerUpgradeError(NetworkException('Erreur réseau')),
    ],
    verify: (_) {
      verify(() => mockRepo.activateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'ignore le second événement si déjà en Loading (protection double-tap)',
    build: () {
      when(() => mockRepo.activateTravelerRole()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _fakeUser();
      });
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) async {
      bloc.add(const TravelerUpgradeActivateRequested());
      bloc.add(const TravelerUpgradeActivateRequested());
    },
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const TravelerUpgradeLoading(),
      TravelerUpgradeSuccess(_fakeUser()),
    ],
    verify: (_) {
      verify(() => mockRepo.activateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'émet [Loading, Deactivated] quand la désactivation réussit',
    build: () {
      when(() => mockRepo.deactivateTravelerRole())
          .thenAnswer((_) async => _fakeUser());
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) => bloc.add(const TravelerUpgradeDeactivateRequested()),
    expect: () => [
      const TravelerUpgradeLoading(),
      TravelerUpgradeDeactivated(_fakeUser()),
    ],
    verify: (_) {
      verify(() => mockRepo.deactivateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'émet [Loading, Error] quand la désactivation échoue',
    build: () {
      when(() => mockRepo.deactivateTravelerRole()).thenThrow(
        const NetworkException('Erreur réseau'),
      );
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) => bloc.add(const TravelerUpgradeDeactivateRequested()),
    expect: () => [
      const TravelerUpgradeLoading(),
      const TravelerUpgradeError(NetworkException('Erreur réseau')),
    ],
    verify: (_) {
      verify(() => mockRepo.deactivateTravelerRole()).called(1);
    },
  );

  blocTest<TravelerUpgradeBloc, TravelerUpgradeState>(
    'ignore la désactivation si déjà en Loading (protection double-tap)',
    build: () {
      when(() => mockRepo.deactivateTravelerRole()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _fakeUser();
      });
      return TravelerUpgradeBloc(mockRepo);
    },
    act: (bloc) async {
      bloc.add(const TravelerUpgradeDeactivateRequested());
      bloc.add(const TravelerUpgradeDeactivateRequested());
    },
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const TravelerUpgradeLoading(),
      TravelerUpgradeDeactivated(_fakeUser()),
    ],
    verify: (_) {
      verify(() => mockRepo.deactivateTravelerRole()).called(1);
    },
  );
}
