import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

DioException _err(int status, {Object? data}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  test('401 sans detail → repli français', () {
    final e = appExceptionFromDioError(_err(401));
    expect(e, isA<UnauthorizedException>());
    expect(e.message, 'Session expirée');
  });

  test('401 sans detail, langue anglaise → repli anglais', () {
    useEnglish();
    expect(appExceptionFromDioError(_err(401)).message, 'Session expired');
  });

  test('detail du serveur prioritaire sur le repli', () {
    final e = appExceptionFromDioError(
      _err(409, data: {'detail': 'Déjà pris', 'code': 'already-taken'}),
    );
    expect(e, isA<ConflictException>());
    expect(e.message, 'Déjà pris');
    expect(e.code, 'already-taken');
  });

  test('422 : violations reprises', () {
    final e = appExceptionFromDioError(
      _err(
        422,
        data: {
          'violations': {'kg': 'Trop lourd'},
        },
      ),
    );
    expect(e, isA<ValidationException>());
    expect((e as ValidationException).errors, {
      'kg': ['Trop lourd'],
    });
    expect(e.message, 'Données invalides');
  });

  test('429, 500 et autres statuts', () {
    expect(appExceptionFromDioError(_err(429)), isA<RateLimitException>());
    expect(appExceptionFromDioError(_err(503)), isA<ServerException>());
    expect(appExceptionFromDioError(_err(403)), isA<ForbiddenException>());
    expect(appExceptionFromDioError(_err(404)), isA<NotFoundException>());
    expect(appExceptionFromDioError(_err(418)), isA<NetworkException>());
  });
}
