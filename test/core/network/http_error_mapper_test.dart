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

    test(
      '405 Dio (corps RFC 7807 method-not-allowed) : NetworkException 405',
      () {
        final e = mapHttpError(
          _http(
            405,
            body: {
              'type': 'https://yadony.com/problems/method-not-allowed',
              'status': 405,
            },
          ),
        );
        expect(e, isA<NetworkException>());
        expect(e.code, '405');
      },
    );

    test('429 : le code du quota est conservé (code, sinon type)', () {
      final byCode = mapHttpError(
        _http(429, body: {'code': 'recipient-lookup-quota'}),
      );
      expect((byCode as RateLimitException).apiCode, 'recipient-lookup-quota');
      final byType = mapHttpError(
        _http(
          429,
          body: {'type': 'https://yadony.com/problems/recipient-lookup-quota'},
        ),
      );
      expect((byType as RateLimitException).apiCode, 'recipient-lookup-quota');
      final bare = mapHttpError(_http(429));
      expect((bare as RateLimitException).apiCode, isNull);
    });

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

    test('409 → propriétés RFC 7807 conservées dans extensions', () {
      final e = mapHttpError(
        _http(
          409,
          body: {
            'detail': 'Identifiant déjà pris',
            'code': 'username-taken',
            'suggestions': ['awa1', 'awa.d'],
            'nextChangeAt': '2026-12-20T10:00:00Z',
          },
        ),
      );

      expect(e, isA<ConflictException>());
      final c = e as ConflictException;
      expect(c.code, 'username-taken');
      expect(c.message, 'Identifiant déjà pris');
      expect(c.extensions?['suggestions'], ['awa1', 'awa.d']);
      expect(c.extensions?['nextChangeAt'], '2026-12-20T10:00:00Z');
    });

    test('404 → propriétés RFC 7807 conservées dans extensions', () {
      final e = mapHttpError(
        _http(
          404,
          body: {
            'type': 'https://api.yadony.com/problems/user-not-found',
            'detail': 'Introuvable',
          },
        ),
      );

      expect(e, isA<NotFoundException>());
      final n = e as NotFoundException;
      expect(n.message, 'Introuvable');
      expect(n.extensions?['type'], endsWith('user-not-found'));
    });

    test('404 sans corps → extensions nulles, message de repli inchangé', () {
      final e = mapHttpError(_http(404)) as NotFoundException;

      expect(e.extensions, isNull);
      expect(e.code, 'NOT_FOUND');
      expect(e.message, isNotEmpty);
    });

    test('409 sans corps → extensions nulles, message de repli inchangé', () {
      final e = mapHttpError(_http(409));

      expect(e, isA<ConflictException>());
      final c = e as ConflictException;
      expect(c.extensions, isNull);
      expect(c.code, isNull);
      expect(c.message, isNotEmpty);
    });

    test('409 sans propriété en plus : mêmes message et code qu avant', () {
      final e =
          mapHttpError(
                _http(409, body: {'detail': 'déjà scanné', 'code': 'x-y'}),
              )
              as ConflictException;

      expect(e.message, 'déjà scanné');
      expect(e.code, 'x-y');
      expect(e.extensions, {'detail': 'déjà scanné', 'code': 'x-y'});
    });

    test('422 bid-below-min-price → propriétés RFC 7807 conservées', () {
      final e = mapHttpError(
        _http(
          422,
          body: {
            'detail': "Ce voyageur n'accepte pas moins de 6.72 EUR/kg",
            'code': 'bid-below-min-price',
            'minPricePerKg': 6.72,
            'currency': 'EUR',
          },
        ),
      );

      expect(e, isA<ValidationException>());
      final v = e as ValidationException;
      expect(v.extensions?['minPricePerKg'], 6.72);
      expect(v.extensions?['currency'], 'EUR');
    });

    test('422 sans corps → aucune propriété', () {
      final e = mapHttpError(_http(422)) as ValidationException;
      expect(e.extensions, isNull);
    });

    // FLUTTER-CB (yadony-back #419) : remise tentée avant le départ.
    test('422 trip-not-departed → ValidationException, jamais rejouée', () {
      final e = mapHttpError(
        _http(
          422,
          body: {
            'detail': 'Trip has not departed yet',
            'code': 'trip-not-departed',
          },
        ),
      );

      expect(e, isA<ValidationException>());
      expect(e.code, 'trip-not-departed');
      expect(OfflineSyncService.isDefinitiveRejection(e), isTrue);
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

    test('503 sms-otp-disabled country-blocked : extensions conservées', () {
      final e = mapHttpError(
        _http(
          503,
          body: {
            'code': 'sms-otp-disabled',
            'detail': 'Pas de SMS vers la Côte d\'Ivoire',
            'reason': 'country-blocked',
            'callingCode': '225',
          },
        ),
      );

      expect(e, isA<ServiceUnavailableException>());
      expect(e.code, 'sms-otp-disabled');
      expect(isSmsCountryBlocked(e), isTrue);
      expect(
        (e as ServiceUnavailableException).extensions?['callingCode'],
        '225',
      );
    });

    test(
      'isSmsCountryBlocked : faux sans raison, autre code ou autre type',
      () {
        expect(isSmsCountryBlocked(mapHttpError(_http(503))), isFalse);
        expect(
          isSmsCountryBlocked(
            mapHttpError(_http(503, body: {'code': 'sms-otp-disabled'})),
          ),
          isFalse,
        );
        expect(
          isSmsCountryBlocked(
            mapHttpError(
              _http(503, body: {'code': 'x', 'reason': 'country-blocked'}),
            ),
          ),
          isFalse,
        );
        expect(
          isSmsCountryBlocked(
            const ConflictException('x', code: 'sms-otp-disabled'),
          ),
          isFalse,
        );
        expect(isSmsCountryBlocked(null), isFalse);
      },
    );

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
