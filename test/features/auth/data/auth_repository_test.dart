import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

const _user = UserModel(
  id: 'u1',
  phoneNumber: '+33612345678',
  roles: ['SENDER'],
  kycStatus: 'PENDING',
  status: 'ACTIVE',
);

void main() {
  late MockAuthRemoteDatasource mockDs;
  late AuthRepository repo;

  setUp(() {
    mockDs = MockAuthRemoteDatasource();
    repo = AuthRepository(mockDs);
  });

  test('register delegates to datasource', () async {
    when(
      () => mockDs.register(phoneNumber: any(named: 'phoneNumber')),
    ).thenAnswer((_) async => _user);

    final result = await repo.register(phoneNumber: '+33612345678');
    expect(result.id, 'u1');
  });

  test('getProfile delegates to datasource', () async {
    when(() => mockDs.getProfile()).thenAnswer((_) async => _user);

    final result = await repo.getProfile();
    expect(result.phoneNumber, '+33612345678');
  });

  test('claimGuestData delegates to datasource', () async {
    when(() => mockDs.claimGuestData('token-anon')).thenAnswer((_) async {});

    await expectLater(repo.claimGuestData('token-anon'), completes);
    verify(() => mockDs.claimGuestData('token-anon')).called(1);
  });

  test('deleteAccount delegates to datasource', () async {
    when(() => mockDs.deleteAccount()).thenAnswer((_) async {});

    await expectLater(repo.deleteAccount(), completes);
  });

  test('updateProfile delegates to datasource', () async {
    when(
      () => mockDs.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        birthDate: any(named: 'birthDate'),
        city: any(named: 'city'),
      ),
    ).thenAnswer((_) async => _user);

    final result = await repo.updateProfile(firstName: 'Amadou');
    expect(result.id, 'u1');
  });

  test('sendEmailOtp delegates to datasource', () async {
    when(
      () => mockDs.sendEmailOtp('user@example.com'),
    ).thenAnswer((_) async {});

    await expectLater(repo.sendEmailOtp('user@example.com'), completes);
    verify(() => mockDs.sendEmailOtp('user@example.com')).called(1);
  });

  test('verifyEmailOtp delegates to datasource', () async {
    when(
      () => mockDs.verifyEmailOtp('user@example.com', '123456'),
    ).thenAnswer((_) async => 'fake_custom_token');

    final token = await repo.verifyEmailOtp('user@example.com', '123456');
    expect(token, 'fake_custom_token');
    verify(() => mockDs.verifyEmailOtp('user@example.com', '123456')).called(1);
  });

  test('attachEmail delegates to datasource', () async {
    when(
      () => mockDs.attachEmail(email: 'user@example.com', code: '123456'),
    ).thenAnswer((_) async => _user);

    final result = await repo.attachEmail(
      email: 'user@example.com',
      code: '123456',
    );
    expect(result.id, 'u1');
    verify(
      () => mockDs.attachEmail(email: 'user@example.com', code: '123456'),
    ).called(1);
  });

  test('sendPhoneOtp delegates to datasource', () async {
    when(() => mockDs.sendPhoneOtp('+221701234567')).thenAnswer((_) async {});

    await expectLater(repo.sendPhoneOtp('+221701234567'), completes);
    verify(() => mockDs.sendPhoneOtp('+221701234567')).called(1);
  });

  test('verifyPhoneOtp delegates to datasource', () async {
    when(
      () => mockDs.verifyPhoneOtp('+221701234567', '123456'),
    ).thenAnswer((_) async => 'fake_custom_token');

    final token = await repo.verifyPhoneOtp('+221701234567', '123456');
    expect(token, 'fake_custom_token');
    verify(() => mockDs.verifyPhoneOtp('+221701234567', '123456')).called(1);
  });

  test('attachPhone delegates to datasource', () async {
    when(
      () => mockDs.attachPhone(phoneNumber: '+221701234567', code: '123456'),
    ).thenAnswer((_) async => _user);

    final result = await repo.attachPhone(
      phoneNumber: '+221701234567',
      code: '123456',
    );
    expect(result.id, 'u1');
    verify(
      () => mockDs.attachPhone(phoneNumber: '+221701234567', code: '123456'),
    ).called(1);
  });

  test('registerWithEmail delegates to datasource', () async {
    when(
      () => mockDs.registerWithEmail(email: 'user@example.com'),
    ).thenAnswer((_) async => _user);

    final result = await repo.registerWithEmail(email: 'user@example.com');
    expect(result.id, 'u1');
    verify(() => mockDs.registerWithEmail(email: 'user@example.com')).called(1);
  });
}
