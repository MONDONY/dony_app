import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _http(int status, {Map<String, Object?>? body}) {
  final options = RequestOptions(path: '/tracking/events');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('mapHttpError', () {
    test(
      '400 → ValidationException, refus définitif pour la file hors-ligne',
      () {
        // Classé NetworkException auparavant : un scan refusé en 400 par le back
        // était rejoué à chaque retour du réseau.
        final e = mapHttpError(
          _http(
            400,
            body: {'detail': 'Requête illisible', 'code': 'bad-request'},
          ),
        );

        expect(e, isA<ValidationException>());
        expect(e.code, 'bad-request');
        expect(e.message, 'Requête illisible');
        expect(OfflineSyncService.isDefinitiveRejection(e), isTrue);
      },
    );

    test('409 → ConflictException avec le code RFC 7807', () {
      final e = mapHttpError(
        _http(
          409,
          body: {'detail': 'déjà scanné', 'code': 'depart-already-scanned'},
        ),
      );

      expect(e, isA<ConflictException>());
      expect(e.code, 'depart-already-scanned');
    });

    test('422 → ValidationException avec les violations par champ', () {
      final e = mapHttpError(
        _http(
          422,
          body: {
            'detail': 'Paramètres de requête invalides',
            'violations': {'phoneNumber': 'format E.164 attendu'},
          },
        ),
      );

      expect(e, isA<ValidationException>());
      expect((e as ValidationException).errors, {
        'phoneNumber': ['format E.164 attendu'],
      });
    });

    test('5xx → ServerException, conservée par la file hors-ligne', () {
      final e = mapHttpError(_http(503));

      expect(e, isA<ServerException>());
      expect(OfflineSyncService.isDefinitiveRejection(e), isFalse);
    });

    test(
      'statut inconnu (418) → NetworkException portant le statut en code',
      () {
        final e = mapHttpError(_http(418));

        expect(e, isA<NetworkException>());
        expect(e.code, '418');
      },
    );
  });
}
