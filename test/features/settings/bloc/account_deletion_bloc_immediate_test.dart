import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

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

  group('ConfirmImmediateDeletion', () {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionImmediate] en cas de succès',
      build: () {
        when(() => mockRepo.deleteImmediately()).thenAnswer((_) async {});
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionImmediate>(),
      ],
      verify: (_) => verify(() => mockRepo.deleteImmediately()).called(1),
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError(isEscrowBlocked)] si 422 active-transactions',
      build: () {
        when(() => mockRepo.deleteImmediately())
            .thenThrow(const ValidationException('active-transactions'));
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>()
            .having((s) => s.isEscrowBlocked, 'isEscrowBlocked', isTrue),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError] sur une erreur générique',
      build: () {
        when(() => mockRepo.deleteImmediately())
            .thenThrow(const NetworkException('Erreur réseau'));
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>()
            .having((s) => s.isEscrowBlocked, 'isEscrowBlocked', isFalse),
      ],
    );
  });
}
