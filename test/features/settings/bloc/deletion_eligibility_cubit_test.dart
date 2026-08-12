import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

void main() {
  late MockAccountDeletionRepository mockRepo;
  late DeletionEligibilityCubit cubit;

  setUp(() {
    mockRepo = MockAccountDeletionRepository();
    cubit = DeletionEligibilityCubit(mockRepo);
  });

  tearDown(() => cubit.close());

  test('initial state: isLoading=true, canDelete=true', () {
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.canDelete, isTrue);
    expect(cubit.state.blockedReasonMessage, isNull);
  });

  group('check()', () {
    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'aucun blocage → isLoading=false, canDelete=true',
      build: () {
        when(() => mockRepo.checkEligibility()).thenAnswer(
          (_) async => const DeletionEligibility(canDelete: true),
        );
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.canDelete, 'canDelete', isTrue)
            .having((s) => s.blockedReasonMessage, 'blockedReasonMessage', isNull),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'escrow actif → canDelete=false avec message explicite',
      build: () {
        when(() => mockRepo.checkEligibility()).thenAnswer(
          (_) async => const DeletionEligibility(
            canDelete: false,
            blockedReasonCode: 'active-transactions',
          ),
        );
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.canDelete, 'canDelete', isFalse)
            .having((s) => s.blockedReasonMessage, 'blockedReasonMessage',
                contains('séquestre')),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'solde wallet positif → canDelete=false avec message explicite',
      build: () {
        when(() => mockRepo.checkEligibility()).thenAnswer(
          (_) async => const DeletionEligibility(
            canDelete: false,
            blockedReasonCode: 'wallet-balance-not-empty',
          ),
        );
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.canDelete, 'canDelete', isFalse)
            .having((s) => s.blockedReasonMessage, 'blockedReasonMessage',
                contains('wallet')),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'code inconnu → message générique de repli',
      build: () {
        when(() => mockRepo.checkEligibility()).thenAnswer(
          (_) async => const DeletionEligibility(
            canDelete: false,
            blockedReasonCode: 'some-new-backend-code',
          ),
        );
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.canDelete, 'canDelete', isFalse)
            .having((s) => s.blockedReasonMessage, 'blockedReasonMessage', isNotNull),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'erreur réseau → fail-open, canDelete=true (le backend reste autoritaire à la tentative réelle)',
      build: () {
        when(() => mockRepo.checkEligibility())
            .thenThrow(Exception('network down'));
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.canDelete, 'canDelete', isTrue),
      ],
    );
  });
}
