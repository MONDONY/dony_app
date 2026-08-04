import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

const _activeUser = UserModel(
  id: 'u1',
  roles: ['SENDER'],
  kycStatus: 'PENDING',
  status: 'ACTIVE',
);

void main() {
  late MockAccountDeletionRepository mockRepo;
  late AccountDeletionBloc bloc;

  setUp(() {
    mockRepo = MockAccountDeletionRepository();
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    analytics.onConfigured();
    bloc = AccountDeletionBloc(mockRepo, analytics);
  });

  tearDown(() => bloc.close());

  test('initial state is AccountDeletionInitial', () {
    expect(bloc.state, isA<AccountDeletionInitial>());
  });

  group('RequestDeletion', () {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionRequested] on success',
      build: () {
        when(() => mockRepo.requestDeletion()).thenAnswer((_) async {});
        return bloc;
      },
      act: (b) => b.add(const RequestDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionRequested>(),
      ],
      verify: (_) => verify(() => mockRepo.requestDeletion()).called(1),
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError(isEscrowBlocked: true)] on ValidationException',
      build: () {
        when(() => mockRepo.requestDeletion())
            .thenThrow(const ValidationException('active-transactions'));
        return bloc;
      },
      act: (b) => b.add(const RequestDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>().having(
          (s) => s.isEscrowBlocked,
          'isEscrowBlocked',
          isTrue,
        ),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError] on generic AppException',
      build: () {
        when(() => mockRepo.requestDeletion())
            .thenThrow(const NetworkException('Erreur réseau'));
        return bloc;
      },
      act: (b) => b.add(const RequestDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>().having(
          (s) => s.isEscrowBlocked,
          'isEscrowBlocked',
          isFalse,
        ),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError] on unexpected exception',
      build: () {
        when(() => mockRepo.requestDeletion()).thenThrow(Exception('Oops'));
        return bloc;
      },
      act: (b) => b.add(const RequestDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>(),
      ],
    );
  });

  group('ReactivateAccount', () {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountReactivated] on success',
      build: () {
        when(() => mockRepo.reactivateAccount())
            .thenAnswer((_) async => _activeUser);
        return bloc;
      },
      act: (b) => b.add(const ReactivateAccount()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountReactivated>().having(
          (s) => s.user.status,
          'user.status',
          'ACTIVE',
        ),
      ],
      verify: (_) => verify(() => mockRepo.reactivateAccount()).called(1),
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError] on AppException',
      build: () {
        when(() => mockRepo.reactivateAccount())
            .thenThrow(const NetworkException('Erreur réseau'));
        return bloc;
      },
      act: (b) => b.add(const ReactivateAccount()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>(),
      ],
    );
  });
}
