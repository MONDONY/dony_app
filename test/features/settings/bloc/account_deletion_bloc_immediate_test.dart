import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/data/firebase_phone_reauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

class MockFirebasePhoneReauth extends Mock implements FirebasePhoneReauth {}

void main() {
  late MockAccountDeletionRepository mockRepo;
  late MockFirebasePhoneReauth mockReauth;
  late AccountDeletionBloc bloc;

  setUp(() {
    mockRepo = MockAccountDeletionRepository();
    mockReauth = MockFirebasePhoneReauth();
    bloc = AccountDeletionBloc(mockRepo, mockReauth);
  });

  tearDown(() => bloc.close());

  group('RequestOtpForImmediateDeletion', () {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, DeletionOtpSent] quand sendVerificationCode réussit',
      build: () {
        when(() => mockReauth.currentUserPhone).thenReturn('+33600000001');
        when(() => mockReauth.sendVerificationCode())
            .thenAnswer((_) async => 'verif-id-123');
        return bloc;
      },
      act: (b) => b.add(const RequestOtpForImmediateDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<DeletionOtpSent>()
            .having((s) => s.verificationId, 'verificationId', 'verif-id-123')
            .having((s) => s.phoneHint, 'phoneHint', '+33 ••••••• 01'),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError] si sendVerificationCode échoue',
      build: () {
        when(() => mockReauth.currentUserPhone).thenReturn('+33600000001');
        when(() => mockReauth.sendVerificationCode())
            .thenThrow(Exception('Firebase error'));
        return bloc;
      },
      act: (b) => b.add(const RequestOtpForImmediateDeletion()),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>(),
      ],
    );
  });

  group('ConfirmImmediateDeletion', () {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionImmediate] en cas de succès',
      build: () {
        when(() => mockReauth.reauthenticate('verif-id', '123456'))
            .thenAnswer((_) async {});
        when(() => mockRepo.deleteImmediately()).thenAnswer((_) async {});
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion(
          verificationId: 'verif-id', smsCode: '123456')),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionImmediate>(),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError(isEscrowBlocked)] si 422 active-transactions',
      build: () {
        when(() => mockReauth.reauthenticate(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockRepo.deleteImmediately())
            .thenThrow(const ValidationException('active-transactions'));
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion(
          verificationId: 'verif-id', smsCode: '123456')),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>()
            .having((s) => s.isEscrowBlocked, 'isEscrowBlocked', isTrue),
      ],
    );

    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'emits [Loading, AccountDeletionError(isReauthRequired)] si 401',
      build: () {
        when(() => mockReauth.reauthenticate(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockRepo.deleteImmediately())
            .thenThrow(const UnauthorizedException('reauth-required'));
        return bloc;
      },
      act: (b) => b.add(const ConfirmImmediateDeletion(
          verificationId: 'verif-id', smsCode: '123456')),
      expect: () => [
        isA<AccountDeletionLoading>(),
        isA<AccountDeletionError>()
            .having((s) => s.isReauthRequired, 'isReauthRequired', isTrue),
      ],
    );
  });
}
