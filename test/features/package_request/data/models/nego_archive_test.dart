import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(int status, [Map<String, dynamic>? data]) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

Map<String, dynamic> _threadJson({Object? archived}) => {
  'id': 'th-1',
  'packageRequestId': 'pr-1',
  'travelerId': 'tr-1',
  'travelerTravelDate': '2026-06-15',
  'travelerAvailableKg': 10.0,
  'status': 'EXPIRED',
  'currentPriceEur': 30.0,
  'roundsCount': 1,
  'lastActivityAt': '2026-05-10T10:00:00Z',
  'createdAt': '2026-05-10T10:00:00Z',
  'archived': ?archived,
};

void main() {
  group('classifyNegoArchiveError — exceptions déjà traduites', () {
    test('409 → stillOpen', () {
      expect(
        classifyNegoArchiveError(
          const ConflictException('x', code: kNegotiationStillOpenCode),
        ),
        NegoArchiveOutcome.stillOpen,
      );
    });

    test('403 → gone', () {
      expect(
        classifyNegoArchiveError(const ForbiddenException()),
        NegoArchiveOutcome.gone,
      );
    });

    test('404 métier (code) → gone', () {
      expect(
        classifyNegoArchiveError(
          const NotFoundException(apiCode: 'thread/not-found'),
        ),
        NegoArchiveOutcome.gone,
      );
    });

    test('404 sans code (route inconnue, backend ancien) → unsupported', () {
      expect(
        classifyNegoArchiveError(const NotFoundException()),
        NegoArchiveOutcome.unsupported,
      );
    });

    test('405 → unsupported', () {
      expect(
        classifyNegoArchiveError(const NetworkException('x', code: '405')),
        NegoArchiveOutcome.unsupported,
      );
    });

    test('hors ligne, 5xx ou inconnu → failed', () {
      expect(
        classifyNegoArchiveError(const OfflineException()),
        NegoArchiveOutcome.failed,
      );
      expect(
        classifyNegoArchiveError(const ServerException()),
        NegoArchiveOutcome.failed,
      );
      expect(
        classifyNegoArchiveError(Exception('boom')),
        NegoArchiveOutcome.failed,
      );
    });

    test('DioException portant une AppException : on lit l\'AppException', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const ConflictException('x'),
      );
      expect(classifyNegoArchiveError(e), NegoArchiveOutcome.stillOpen);
    });
  });

  group('classifyNegoArchiveError — DioException brute', () {
    test('409', () {
      expect(
        classifyNegoArchiveError(
          _dio(409, {'code': kNegotiationStillOpenCode}),
        ),
        NegoArchiveOutcome.stillOpen,
      );
    });

    test('403', () {
      expect(classifyNegoArchiveError(_dio(403)), NegoArchiveOutcome.gone);
    });

    test('404 avec code → gone, sans code → unsupported', () {
      expect(
        classifyNegoArchiveError(_dio(404, {'code': 'negotiation-not-found'})),
        NegoArchiveOutcome.gone,
      );
      expect(
        classifyNegoArchiveError(_dio(404, {'type': 'x/not-found'})),
        NegoArchiveOutcome.unsupported,
      );
    });

    test('405 → unsupported', () {
      expect(
        classifyNegoArchiveError(_dio(405)),
        NegoArchiveOutcome.unsupported,
      );
    });

    test('500 → failed', () {
      expect(classifyNegoArchiveError(_dio(500)), NegoArchiveOutcome.failed);
    });
  });

  group('NegoArchiveResult', () {
    test('isSuccess et égalité par seq', () {
      const a = NegoArchiveResult(
        id: 'x',
        action: NegoArchiveAction.archive,
        outcome: NegoArchiveOutcome.success,
        seq: 1,
      );
      const b = NegoArchiveResult(
        id: 'x',
        action: NegoArchiveAction.archive,
        outcome: NegoArchiveOutcome.success,
        seq: 2,
      );
      expect(a.isSuccess, isTrue);
      expect(a == b, isFalse);
      expect(
        const NegoArchiveResult(
          id: 'x',
          action: NegoArchiveAction.delete,
          outcome: NegoArchiveOutcome.gone,
          seq: 3,
        ).isSuccess,
        isFalse,
      );
    });
  });

  group('champ archived (contrat yadony-back #423)', () {
    test('NegotiationThread : absent → false, présent → lu', () {
      expect(NegotiationThread.fromJson(_threadJson()).archived, isFalse);
      expect(
        NegotiationThread.fromJson(_threadJson(archived: true)).archived,
        isTrue,
      );
      expect(
        NegotiationThread.fromJson(_threadJson(archived: true)),
        isNot(NegotiationThread.fromJson(_threadJson())),
      );
    });

    test('BidNegotiationSummary : absent → false, présent → lu', () {
      final base = {'bidId': 'b', 'announcementId': 'a', 'status': 'REJECTED'};
      expect(BidNegotiationSummary.fromJson(base).archived, isFalse);
      expect(
        BidNegotiationSummary.fromJson({...base, 'archived': true}).archived,
        isTrue,
      );
    });

    test('BidNegotiation : archived lu, isFinished suit les statuts', () {
      BidNegotiation n(String status, {bool? archived}) =>
          BidNegotiation.fromJson({
            'bidId': 'b',
            'announcementId': 'a',
            'status': status,
            'archived': ?archived,
          });
      expect(n('REJECTED').archived, isFalse);
      expect(n('REJECTED', archived: true).archived, isTrue);
      for (final open in kBidNegotiationOpenStatuses) {
        expect(n(open).isFinished, isFalse, reason: open);
      }
      for (final done in ['REJECTED', 'CANCELLED', 'EXPIRED', 'PAID']) {
        expect(n(done).isFinished, isTrue, reason: done);
      }
    });
  });
}
