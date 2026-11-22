import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

class _MockDatasource extends Mock implements CancellationRemoteDatasource {}

const _path = '/cancellations/bids/bid-1/fee-preview';

Response<dynamic> _ok(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: _path),
);

/// Erreur telle que l'intercepteur de l'ApiClient la livre : l'AppException
/// rangée dans `DioException.error`.
DioException _failure(int status, AppException error) => DioException(
  requestOptions: RequestOptions(path: _path),
  response: Response(
    statusCode: status,
    requestOptions: RequestOptions(path: _path),
  ),
  type: DioExceptionType.badResponse,
  error: error,
);

void main() {
  group('CancellationFeePreviewModel.fromJson', () {
    test('réponse normale en euros', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': 0.20,
        'fee': 20.00,
        'currency': 'EUR',
        'refundAmount': 80.00,
        'nextTierAt': '2026-12-05T10:00:00Z',
      });
      expect(m.rate, 0.2);
      expect(m.fee, 20);
      expect(m.refundAmount, 80);
      expect(m.currency, 'EUR');
      expect(m.nextTierAt, DateTime.utc(2026, 12, 5, 10));
      expect(m.hasFee, isTrue);
      expect(m.ratePercent, 20);
      expect(m.willRise, isTrue);
    });

    test('aucun frais : zéros sans décimale, pas de hausse annoncée', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': 0,
        'fee': 0,
        'currency': 'EUR',
        'refundAmount': 80.00,
      });
      expect(m.fee, 0);
      expect(m.rate, 0);
      expect(m.hasFee, isFalse);
      expect(m.nextTierAt, isNull);
      expect(m.willRise, isFalse);
    });

    test('nextTierAt absent au palier le plus cher', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': 0.30,
        'fee': 30.00,
        'currency': 'EUR',
        'refundAmount': 70.00,
      });
      expect(m.hasFee, isTrue);
      expect(m.ratePercent, 30);
      expect(m.nextTierAt, isNull);
    });

    test('franc CFA : montants entiers', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': 0.3,
        'fee': 19678,
        'currency': 'xof',
        'refundAmount': 45922,
      });
      expect(m.fee, 19678);
      expect(m.refundAmount, 45922);
      expect(m.currency, 'XOF');
    });

    test('espèces : tout à zéro', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': 0,
        'fee': 0,
        'currency': 'XOF',
        'refundAmount': 0,
      });
      expect(m.hasFee, isFalse);
      expect(m.refundAmount, 0);
    });

    test('décimales en texte, champs absents ou illisibles → 0', () {
      final m = CancellationFeePreviewModel.fromJson(const {
        'rate': '0.10',
        'fee': ' 12.5 ',
        'refundAmount': 'n/a',
        'currency': '  ',
        'nextTierAt': 'pas une date',
      });
      expect(m.rate, 0.1);
      expect(m.fee, 12.5);
      expect(m.refundAmount, 0);
      expect(m.currency, isNull);
      expect(m.nextTierAt, isNull);

      final empty = CancellationFeePreviewModel.fromJson(const {});
      expect(empty.fee, 0);
      expect(empty.hasFee, isFalse);
    });

    test('égalité par valeur', () {
      const a = CancellationFeePreviewModel(
        rate: 0.2,
        fee: 20,
        refundAmount: 80,
        currency: 'EUR',
      );
      const b = CancellationFeePreviewModel(
        rate: 0.2,
        fee: 20,
        refundAmount: 80,
        currency: 'EUR',
      );
      expect(a, b);
    });
  });

  group('CancellationRemoteDatasource.getFeePreview', () {
    late _MockApiClient client;
    late _MockDio dio;
    late CancellationRemoteDatasource datasource;

    setUp(() {
      client = _MockApiClient();
      dio = _MockDio();
      when(() => client.dio).thenReturn(dio);
      datasource = CancellationRemoteDatasource(client);
    });

    test('GET /cancellations/bids/{bidId}/fee-preview → modèle', () async {
      when(() => dio.get(_path)).thenAnswer(
        (_) async => _ok({
          'rate': 0.2,
          'fee': 20.0,
          'currency': 'EUR',
          'refundAmount': 80.0,
          'nextTierAt': '2026-12-05T10:00:00Z',
        }),
      );

      final m = await datasource.getFeePreview('bid-1');

      expect(m.fee, 20);
      expect(m.refundAmount, 80);
      expect(m.nextTierAt, isNotNull);
      verify(() => dio.get(_path)).called(1);
    });

    test('corps qui n\'est pas un objet → FormatException', () async {
      when(() => dio.get(_path)).thenAnswer((_) async => _ok('<html>'));
      expect(
        () => datasource.getFeePreview('bid-1'),
        throwsA(isA<FormatException>()),
      );
    });

    for (final (label, status, error, type) in [
      (
        '403 (pas l\'expéditeur)',
        403,
        const ForbiddenException('Forbidden', 'forbidden'),
        ForbiddenException,
      ),
      (
        '404 (back antérieur ou colis inconnu)',
        404,
        const NotFoundException(apiCode: 'bid-not-found'),
        NotFoundException,
      ),
    ]) {
      test('$label : l\'erreur remonte telle que l\'intercepteur la livre', () {
        when(() => dio.get(_path)).thenThrow(_failure(status, error));
        expect(
          () => datasource.getFeePreview('bid-1'),
          throwsA(
            isA<DioException>().having(
              (e) => unwrapDioError(e).runtimeType,
              'erreur',
              type,
            ),
          ),
        );
      });
    }

    test('hors ligne : OfflineException', () {
      when(() => dio.get(_path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        () => datasource.getFeePreview('bid-1'),
        throwsA(
          isA<DioException>().having(
            unwrapDioError,
            'erreur',
            isA<OfflineException>(),
          ),
        ),
      );
    });
  });

  test('CancellationRepository.getFeePreview délègue au datasource', () async {
    final ds = _MockDatasource();
    const preview = CancellationFeePreviewModel(
      rate: 0.1,
      fee: 10,
      refundAmount: 90,
    );
    when(() => ds.getFeePreview('bid-1')).thenAnswer((_) async => preview);

    final result = await CancellationRepository(ds).getFeePreview('bid-1');

    expect(result, preview);
    verify(() => ds.getFeePreview('bid-1')).called(1);
  });
}
