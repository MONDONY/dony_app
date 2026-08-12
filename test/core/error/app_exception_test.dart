import 'package:dony/core/error/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppException', () {
    test('NetworkException stores message and optional code', () {
      const e = NetworkException('timeout', code: 'TIMEOUT');
      expect(e.message, 'timeout');
      expect(e.code, 'TIMEOUT');
      expect(e.toString(), contains('TIMEOUT'));
    });

    test('UnauthorizedException has default message and UNAUTHORIZED code', () {
      // ignore: prefer_const_constructors
      final e = UnauthorizedException();
      expect(e.message, 'Unauthorized');
      expect(e.code, 'UNAUTHORIZED');
    });

    test('UnauthorizedException accepts custom message', () {
      // ignore: prefer_const_constructors
      final e = UnauthorizedException('Token expired');
      expect(e.message, 'Token expired');
    });

    test('ForbiddenException has FORBIDDEN code', () {
      // ignore: prefer_const_constructors
      final e = ForbiddenException();
      expect(e.code, 'FORBIDDEN');
    });

    test('NotFoundException has NOT_FOUND code', () {
      // ignore: prefer_const_constructors
      final e = NotFoundException();
      expect(e.code, 'NOT_FOUND');
    });

    test('NotFoundException stocke resourceType optionnel', () {
      // ignore: prefer_const_constructors
      final e = NotFoundException(
        message: 'Annonce introuvable',
        resourceType: 'announcement',
      );
      expect(e.code, 'NOT_FOUND');
      expect(e.message, 'Annonce introuvable');
      expect(e.resourceType, 'announcement');
    });

    test('NotFoundException sans resourceType reste null', () {
      // ignore: prefer_const_constructors
      final e = NotFoundException();
      expect(e.resourceType, isNull);
    });

    test('ServerException has SERVER_ERROR code', () {
      // ignore: prefer_const_constructors
      final e = ServerException();
      expect(e.code, 'SERVER_ERROR');
    });

    test('StorageException accepts message and optional code', () {
      // ignore: prefer_const_constructors
      final e = StorageException('disk full', code: 'DISK');
      expect(e.message, 'disk full');
      expect(e.code, 'DISK');
    });

    test('ValidationException stores errors map', () {
      // ignore: prefer_const_constructors
      final e = ValidationException(
        'invalid',
        errors: {
          'email': ['required', 'invalid format'],
        },
      );
      expect(e.errors!['email'], hasLength(2));
      expect(e.props, contains(e.errors));
    });

    test('AppException equality via Equatable props', () {
      // ignore: prefer_const_constructors
      final a = NetworkException('err', code: 'X');
      // ignore: prefer_const_constructors
      final b = NetworkException('err', code: 'X');
      // ignore: prefer_const_constructors
      final c = NetworkException('other', code: 'X');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('NotFoundException equality inclut resourceType', () {
      // ignore: prefer_const_constructors
      final a = NotFoundException(resourceType: 'bid');
      // ignore: prefer_const_constructors
      final b = NotFoundException(resourceType: 'bid');
      // ignore: prefer_const_constructors
      final c = NotFoundException(resourceType: 'announcement');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes code and message', () {
      const e = NetworkException('net error', code: 'NET');
      expect(e.toString(), 'AppException(NET): net error');
    });
  });
}
