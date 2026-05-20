import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

final _userJson = {
  'id': 'user-123',
  'phoneNumber': '+33612345678',
  'roles': ['SENDER'],
  'kycStatus': 'PENDING',
  'status': 'ACTIVE',
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late AuthRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = AuthRemoteDatasource(mockClient);
  });

  group('register', () {
    test('returns UserModel on success', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
              '/auth/register',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              Response(data: _userJson, statusCode: 200, requestOptions: RequestOptions(path: '/auth/register')));

      final result = await datasource.register(
        phoneNumber: '+33612345678',
      );

      expect(result.id, 'user-123');
      expect(result.roles, ['SENDER']);
    });
  });

  group('getProfile', () {
    test('returns UserModel for current user', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/auth/me'))
          .thenAnswer((_) async =>
              Response(data: _userJson, statusCode: 200, requestOptions: RequestOptions(path: '/auth/me')));

      final result = await datasource.getProfile();

      expect(result.id, 'user-123');
    });
  });

  group('deleteAccount', () {
    test('calls DELETE and completes', () async {
      when(() => mockDio.delete<void>('/auth/me'))
          .thenAnswer((_) async =>
              Response(data: null, statusCode: 204, requestOptions: RequestOptions(path: '/auth/me')));

      await expectLater(datasource.deleteAccount(), completes);
    });
  });

  group('updateProfile', () {
    test('returns updated UserModel', () async {
      final updated = {..._userJson, 'firstName': 'Amadou', 'lastName': 'Diallo'};
      when(() => mockDio.patch<Map<String, dynamic>>(
              '/auth/me',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              Response(data: updated, statusCode: 200, requestOptions: RequestOptions(path: '/auth/me')));

      final result = await datasource.updateProfile(
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@dony.app',
        birthDate: DateTime(1990, 5, 15),
        city: 'Paris',
      );

      expect(result.firstName, 'Amadou');
    });

    test('handles null optional fields', () async {
      when(() => mockDio.patch<Map<String, dynamic>>(
              '/auth/me',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              Response(data: _userJson, statusCode: 200, requestOptions: RequestOptions(path: '/auth/me')));

      final result = await datasource.updateProfile();
      expect(result.id, 'user-123');
    });
  });

  group('sendEmailOtp', () {
    test('calls POST /auth/email-otp/send and completes', () async {
      when(() => mockDio.post<void>(
              '/auth/email-otp/send',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              Response(data: null, statusCode: 204, requestOptions: RequestOptions(path: '/auth/email-otp/send')));

      await expectLater(datasource.sendEmailOtp('user@example.com'), completes);
      verify(() => mockDio.post<void>(
            '/auth/email-otp/send',
            data: {'email': 'user@example.com'},
          )).called(1);
    });
  });

  group('verifyEmailOtp', () {
    test('calls POST /auth/email-otp/verify and returns customToken', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
              '/auth/email-otp/verify',
              data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'customToken': 'fake_token_123'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/auth/email-otp/verify'),
              ));

      final token = await datasource.verifyEmailOtp('user@example.com', '123456');
      expect(token, 'fake_token_123');
      verify(() => mockDio.post<Map<String, dynamic>>(
            '/auth/email-otp/verify',
            data: {'email': 'user@example.com', 'code': '123456'},
          )).called(1);
    });
  });

  group('registerWithEmail', () {
    test('returns UserModel on success', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
              '/auth/register',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              Response(data: _userJson, statusCode: 200, requestOptions: RequestOptions(path: '/auth/register')));

      final result = await datasource.registerWithEmail(
        email: 'user@example.com',
      );

      expect(result.id, 'user-123');
      verify(() => mockDio.post<Map<String, dynamic>>(
            '/auth/register',
            data: {'email': 'user@example.com'},
          )).called(1);
    });
  });
}
