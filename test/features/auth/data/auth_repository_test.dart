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
    when(() => mockDs.register(
          phoneNumber: any(named: 'phoneNumber'),
          roles: any(named: 'roles'),
        )).thenAnswer((_) async => _user);

    final result = await repo.register(phoneNumber: '+33612345678', roles: ['SENDER']);
    expect(result.id, 'u1');
  });

  test('getProfile delegates to datasource', () async {
    when(() => mockDs.getProfile()).thenAnswer((_) async => _user);

    final result = await repo.getProfile();
    expect(result.phoneNumber, '+33612345678');
  });

  test('deleteAccount delegates to datasource', () async {
    when(() => mockDs.deleteAccount()).thenAnswer((_) async {});

    await expectLater(repo.deleteAccount(), completes);
  });

  test('updateProfile delegates to datasource', () async {
    when(() => mockDs.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          email: any(named: 'email'),
          birthDate: any(named: 'birthDate'),
          city: any(named: 'city'),
        )).thenAnswer((_) async => _user);

    final result = await repo.updateProfile(firstName: 'Amadou');
    expect(result.id, 'u1');
  });

  test('sendEmailOtp delegates to datasource', () async {
    when(() => mockDs.sendEmailOtp('user@example.com'))
        .thenAnswer((_) async {});

    await expectLater(repo.sendEmailOtp('user@example.com'), completes);
    verify(() => mockDs.sendEmailOtp('user@example.com')).called(1);
  });

  test('verifyEmailOtp delegates to datasource', () async {
    when(() => mockDs.verifyEmailOtp('user@example.com', '123456'))
        .thenAnswer((_) async {});

    await expectLater(repo.verifyEmailOtp('user@example.com', '123456'), completes);
    verify(() => mockDs.verifyEmailOtp('user@example.com', '123456')).called(1);
  });

  test('registerWithEmail delegates to datasource', () async {
    when(() => mockDs.registerWithEmail(
          email: 'user@example.com',
          roles: ['SENDER'],
        )).thenAnswer((_) async => _user);

    final result = await repo.registerWithEmail(
      email: 'user@example.com',
      roles: ['SENDER'],
    );
    expect(result.id, 'u1');
    verify(() => mockDs.registerWithEmail(
          email: 'user@example.com',
          roles: ['SENDER'],
        )).called(1);
  });
}
