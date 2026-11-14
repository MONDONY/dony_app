import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/network/capabilities_interceptor.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Adaptateur factice : note chaque requête et rend la réponse programmée.
class _Adapter implements HttpClientAdapter {
  int status = 200;
  Object body = const <String, dynamic>{};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _inquiryJson = {
  'id': 'c1',
  'firestoreConversationId': 'fs1',
  'kind': 'INQUIRY',
  'announcementId': 'a1',
  'inquiryMessageLimit': 10,
  'inquiryQuotaLifted': false,
  'otherParticipant': {'id': 'u2', 'name': 'Awa'},
};

void main() {
  late _Adapter adapter;
  late ConversationRepository repository;

  setUp(() {
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(CapabilitiesInterceptor());
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);
    repository = ConversationRepository(client);
  });

  group('openInquiry', () {
    test(
      'POST /conversations/inquiry avec announcementId, rend le modèle',
      () async {
        adapter.body = _inquiryJson;

        final model = await repository.openInquiry('a1');

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/conversations/inquiry');
        expect(request.data, {'announcementId': 'a1'});
        expect(model.id, 'c1');
        expect(model.isInquiry, isTrue);
        expect(model.bidId, isNull);
        expect(model.announcementId, 'a1');
      },
    );

    test('403 kyc-required : InquiryKycRequiredException', () async {
      adapter
        ..status = 403
        ..body = {'code': 'kyc-required', 'detail': 'KYC'};

      expect(
        repository.openInquiry('a1'),
        throwsA(isA<InquiryKycRequiredException>()),
      );
    });

    test('403 autre code : erreur d\'origine conservée', () async {
      adapter
        ..status = 403
        ..body = {'code': 'messaging-muted'};

      expect(repository.openInquiry('a1'), throwsA(isA<DioException>()));
    });

    test('404 announcement-not-found : InquiryUnavailableException', () async {
      adapter
        ..status = 404
        ..body = {'code': 'announcement-not-found'};

      await expectLater(
        repository.openInquiry('a1'),
        throwsA(
          isA<InquiryUnavailableException>().having(
            (e) => e.code,
            'code',
            'announcement-not-found',
          ),
        ),
      );
      expect(repository.inquiryUnsupported, isFalse);
    });

    test('405 (back sans la route) : non pris en charge, mémorisé', () async {
      adapter
        ..status = 405
        ..body = {'title': 'Method Not Allowed'};

      expect(repository.inquiryUnsupported, isFalse);
      await expectLater(
        repository.openInquiry('a1'),
        throwsA(isA<InquiryUnsupportedException>()),
      );
      expect(repository.inquiryUnsupported, isTrue);
    });

    test('404 sans code : non pris en charge, mémorisé', () async {
      adapter
        ..status = 404
        ..body = {'title': 'Not Found'};

      await expectLater(
        repository.openInquiry('a1'),
        throwsA(isA<InquiryUnsupportedException>()),
      );
      expect(repository.inquiryUnsupported, isTrue);
    });

    test('404 d\'un autre code : non pris en charge', () async {
      adapter
        ..status = 404
        ..body = {'code': 'conversation-not-found'};

      await expectLater(
        repository.openInquiry('a1'),
        throwsA(isA<InquiryUnsupportedException>()),
      );
    });

    test('après un refus 405 : plus aucun appel réseau', () async {
      adapter.status = 405;
      await expectLater(
        repository.openInquiry('a1'),
        throwsA(isA<InquiryUnsupportedException>()),
      );
      adapter
        ..status = 200
        ..body = _inquiryJson;

      await expectLater(
        repository.openInquiry('a2'),
        throwsA(isA<InquiryUnsupportedException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      '422 inquiry-announcement-closed : InquiryUnavailableException',
      () async {
        adapter
          ..status = 422
          ..body = {'code': 'inquiry-announcement-closed'};

        await expectLater(
          repository.openInquiry('a1'),
          throwsA(
            isA<InquiryUnavailableException>().having(
              (e) => e.code,
              'code',
              'inquiry-announcement-closed',
            ),
          ),
        );
        expect(repository.inquiryUnsupported, isFalse);
      },
    );

    test('422 autre code : erreur d\'origine conservée', () async {
      adapter
        ..status = 422
        ..body = {'code': 'autre'};

      expect(repository.openInquiry('a1'), throwsA(isA<DioException>()));
    });

    test('500 : erreur d\'origine conservée', () async {
      adapter
        ..status = 500
        ..body = {'code': 'boom'};

      expect(repository.openInquiry('a1'), throwsA(isA<DioException>()));
    });
  });

  group('en-tête X-Dony-Capabilities', () {
    final calls = <String, Future<void> Function(ConversationRepository)>{
      'getConversationPage': (r) => r.getConversationPage(),
      'getConversation': (r) => r.getConversation('c1'),
      'getByBidId': (r) => r.getByBidId('b1'),
      'getRecipientConversation': (r) => r.getRecipientConversation('b1'),
      'updateLastMessage': (r) => r.updateLastMessage('c1', 'salut'),
      'deleteConversation': (r) => r.deleteConversation('c1'),
      'restoreConversation': (r) => r.restoreConversation('c1'),
      'getArchivedConversations': (r) => r.getArchivedConversations(),
      'archiveConversation': (r) => r.archiveConversation('c1'),
      'unarchiveConversation': (r) => r.unarchiveConversation('c1'),
      'archiveConversations (lot)': (r) => r.archiveConversations(['c1']),
      'muteConversationNotifications': (r) =>
          r.muteConversationNotifications('c1'),
      'unmuteConversationNotifications': (r) =>
          r.unmuteConversationNotifications('c1'),
      'openInquiry': (r) => r.openInquiry('a1'),
    };

    for (final entry in calls.entries) {
      test('${entry.key} porte inquiry', () async {
        adapter.body = _inquiryJson;
        try {
          await entry.value(repository);
        } catch (_) {
          // Seul l'en-tête de la requête émise importe ici.
        }

        expect(adapter.requests, isNotEmpty);
        for (final request in adapter.requests) {
          expect(
            request.headers[CapabilitiesInterceptor.headerName],
            'inquiry',
            reason: '${request.method} ${request.path}',
          );
        }
      });
    }

    test('hors /conversations : pas d\'en-tête', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter
        ..interceptors.add(CapabilitiesInterceptor());
      await dio.get<dynamic>('/bids/b1');

      expect(
        adapter.requests.single.headers.containsKey(
          CapabilitiesInterceptor.headerName,
        ),
        isFalse,
      );
    });
  });
}
