import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockAccountDeletionRepository mockRepo;
  late MockAnalyticsService mockAnalytics;
  late DeletionEligibilityCubit cubit;

  setUp(() {
    mockRepo = MockAccountDeletionRepository();
    mockAnalytics = MockAnalyticsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = DeletionEligibilityCubit(mockRepo, mockAnalytics);
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
        when(
          () => mockRepo.checkEligibility(),
        ).thenAnswer((_) async => const DeletionEligibility(canDelete: true));
        return cubit;
      },
      act: (c) => c.check(),
      expect: () => [
        isA<DeletionEligibilityState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.canDelete, 'canDelete', isTrue)
            .having(
              (s) => s.blockedReasonMessage,
              'blockedReasonMessage',
              isNull,
            ),
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
            .having(
              (s) => s.blockedReasonMessage,
              'blockedReasonMessage',
              contains('séquestre'),
            ),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'solde wallet positif → canDelete=false avec message explicite, '
      'isWalletBalanceBlocked=true (seul motif avec parcours self-service)',
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
            .having(
              (s) => s.blockedReasonMessage,
              'blockedReasonMessage',
              contains('wallet'),
            )
            .having(
              (s) => s.isWalletBalanceBlocked,
              'isWalletBalanceBlocked',
              isTrue,
            ),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'escrow actif → isWalletBalanceBlocked=false (aucun parcours self-service pour ce motif)',
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
        isA<DeletionEligibilityState>().having(
          (s) => s.isWalletBalanceBlocked,
          'isWalletBalanceBlocked',
          isFalse,
        ),
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
            .having(
              (s) => s.blockedReasonMessage,
              'blockedReasonMessage',
              isNotNull,
            ),
      ],
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'erreur réseau → fail-open, canDelete=true (le backend reste autoritaire à la tentative réelle)',
      build: () {
        when(
          () => mockRepo.checkEligibility(),
        ).thenThrow(Exception('network down'));
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

  group('requestWalletRefund()', () {
    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'succès → walletRefundRequested=true avec le ticket ouvert, analytics tracé',
      build: () {
        when(() => mockRepo.requestWalletRefund()).thenAnswer(
          (_) async => const [
            WalletRefundRequest(currency: 'CAD', amount: 45.00),
          ],
        );
        return cubit;
      },
      act: (c) => c.requestWalletRefund(),
      expect: () => [
        isA<DeletionEligibilityState>().having(
          (s) => s.isRequestingWalletRefund,
          'isRequestingWalletRefund',
          isTrue,
        ),
        isA<DeletionEligibilityState>()
            .having(
              (s) => s.isRequestingWalletRefund,
              'isRequestingWalletRefund',
              isFalse,
            )
            .having(
              (s) => s.walletRefundRequested,
              'walletRefundRequested',
              isTrue,
            )
            .having(
              (s) => s.walletRefundRequests.single.currency,
              'walletRefundRequests.single.currency',
              'CAD',
            ),
      ],
      verify: (_) {
        verify(
          () => mockAnalytics.logEvent(AnalyticsEvents.walletRefundRequested),
        ).called(1);
      },
    );

    blocTest<DeletionEligibilityCubit, DeletionEligibilityState>(
      'échec réseau → walletRefundError posé, walletRefundRequested reste false, rien tracé',
      build: () {
        when(
          () => mockRepo.requestWalletRefund(),
        ).thenThrow(Exception('network down'));
        return cubit;
      },
      act: (c) => c.requestWalletRefund(),
      expect: () => [
        isA<DeletionEligibilityState>().having(
          (s) => s.isRequestingWalletRefund,
          'isRequestingWalletRefund',
          isTrue,
        ),
        isA<DeletionEligibilityState>()
            .having(
              (s) => s.isRequestingWalletRefund,
              'isRequestingWalletRefund',
              isFalse,
            )
            .having(
              (s) => s.walletRefundRequested,
              'walletRefundRequested',
              isFalse,
            )
            .having(
              (s) => s.walletRefundError,
              'walletRefundError',
              isNotNull,
            ),
      ],
      verify: (_) {
        verifyNever(
          () => mockAnalytics.logEvent(AnalyticsEvents.walletRefundRequested),
        );
      },
    );
  });
}
