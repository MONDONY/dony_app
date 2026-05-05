import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepo;
  late UpgradeToProBloc bloc;

  const tEvent = UpgradeToProSubmitted(
    companyName: 'Ma Société SAS',
    siret: '12345678901234',
  );

  setUp(() {
    mockRepo = MockProfileRepository();
    bloc = UpgradeToProBloc(mockRepo);
  });

  tearDown(() => bloc.close());

  test('initial state is UpgradeToProInitial', () {
    expect(bloc.state, isA<UpgradeToProInitial>());
  });

  group('UpgradeToProSubmitted', () {
    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, Success] when upgradeToPro succeeds',
      build: () {
        when(
          () => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ),
        ).thenAnswer((_) async {});
        return bloc;
      },
      act: (b) => b.add(tEvent),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<UpgradeToProSuccess>(),
      ],
      verify: (_) {
        verify(
          () => mockRepo.upgradeToPro(
            companyName: 'Ma Société SAS',
            siret: '12345678901234',
          ),
        ).called(1);
      },
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, Error] with 409 message when repo throws 409',
      build: () {
        when(
          () => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ),
        ).thenThrow(Exception('409 Conflict'));
        return bloc;
      },
      act: (b) => b.add(tEvent),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<UpgradeToProError>().having(
          (s) => s.message,
          'message',
          'Un compte Stripe Connect existe déjà. Contactez le support.',
        ),
      ],
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, Error] with generic message on network error',
      build: () {
        when(
          () => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ),
        ).thenThrow(Exception('Network timeout'));
        return bloc;
      },
      act: (b) => b.add(tEvent),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<UpgradeToProError>().having(
          (s) => s.message,
          'message',
          'Une erreur est survenue. Veuillez réessayer.',
        ),
      ],
    );

    blocTest<UpgradeToProBloc, UpgradeToProState>(
      'emits [Loading, Error] with 409 message when error contains "already"',
      build: () {
        when(
          () => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ),
        ).thenThrow(Exception('Account already exists'));
        return bloc;
      },
      act: (b) => b.add(tEvent),
      expect: () => [
        isA<UpgradeToProLoading>(),
        isA<UpgradeToProError>().having(
          (s) => s.message,
          'message',
          'Un compte Stripe Connect existe déjà. Contactez le support.',
        ),
      ],
    );
  });
}
