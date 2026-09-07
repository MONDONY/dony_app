import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late SupportRepository repository;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = SupportRepository(mockClient);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Existing endpoints
  // ──────────────────────────────────────────────────────────────────────────

  group('loadTickets', () {
    test('désérialise le contenu paginé et le compteur de non-lus', () async {
      when(
        () => mockDio.get(
          '/support/tickets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok({
          'content': [
            {
              'id': 't1',
              'category': 'PAYMENT',
              'subject': 'Aide paiement',
              'status': 'NEW',
              'unreadCount': 3,
            },
          ],
        }, '/support/tickets'),
      );

      final tickets = await repository.loadTickets();
      expect(tickets, hasLength(1));
      expect(tickets.first.unreadCount, 3);
    });
  });

  group('createTicket', () {
    test('transmet les attachmentKeys dans le body', () async {
      when(
        () => mockDio.post('/support/tickets', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _ok({
          'id': 't2',
          'category': 'PAYMENT',
          'subject': 'Aide',
          'status': 'NEW',
        }, '/support/tickets'),
      );

      await repository.createTicket(
        category: 'PAYMENT',
        subject: 'Aide',
        attachmentKeys: const ['support/u1/1_a.jpg'],
      );

      final captured =
          verify(
                () => mockDio.post(
                  '/support/tickets',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured['attachmentKeys'], ['support/u1/1_a.jpg']);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // New endpoints — Task 8
  // ──────────────────────────────────────────────────────────────────────────

  test('rend le nombre de non-lus renvoyé par le serveur', () async {
    when(
      () => mockDio.get('/support/unread-count'),
    ).thenAnswer((_) async => _ok({'count': 3}, '/support/unread-count'));

    expect(await repository.loadUnreadCount(), 3);
  });

  test('marque un fil lu sans rien attendre en retour', () async {
    when(() => mockDio.post('/support/tickets/t1/read')).thenAnswer(
      (_) async => Response(
        statusCode: 204,
        requestOptions: RequestOptions(path: '/support/tickets/t1/read'),
      ),
    );

    await expectLater(repository.markRead('t1'), completes);
  });

  test('rend la clé distante après un upload', () async {
    // Créer un vrai fichier temporaire : MultipartFile.fromFile lit le filesystem.
    final tmpFile = File(
      '${Directory.systemTemp.path}/test_support_attachment.jpg',
    );
    tmpFile.writeAsBytesSync([0xFF, 0xD8, 0xFF]);

    addTearDown(tmpFile.deleteSync);

    when(
      () => mockDio.post('/support/attachments', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => _ok({
        'key': 'support/u1/1_a.jpg',
        'url': 'https://signed',
      }, '/support/attachments'),
    );

    expect(
      await repository.uploadAttachment(tmpFile.path),
      'support/u1/1_a.jpg',
    );
  });

  test(
    'lit les pièces jointes et le compteur dans le détail d\'un ticket',
    () async {
      when(() => mockDio.get('/support/tickets/t1')).thenAnswer(
        (_) async => _ok({
          'id': 't1',
          'category': 'PAYMENT',
          'subject': 'Aide',
          'status': 'ASSIGNED',
          'unreadCount': 2,
          'messages': [
            {
              'id': 'm1',
              'authorType': 'ADMIN',
              'content': 'Bonjour',
              'attachments': [
                {
                  'id': 'a1',
                  'url': 'https://signed',
                  'contentType': 'image/jpeg',
                },
              ],
            },
          ],
        }, '/support/tickets/t1'),
      );

      final ticket = await repository.loadTicket('t1');
      expect(ticket.unreadCount, 2);
      expect(ticket.messages.single.attachments.single.url, 'https://signed');
    },
  );

  test('envoie les clés de pièces jointes avec le message', () async {
    when(
      () => mockDio.post(
        '/support/tickets/t1/messages',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _ok({
        'id': 'm2',
        'authorType': 'USER',
        'content': 'Voici',
      }, '/support/tickets/t1/messages'),
    );

    await repository.sendMessage('t1', 'Voici', const ['support/u1/1_a.jpg']);

    final captured =
        verify(
              () => mockDio.post(
                '/support/tickets/t1/messages',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    expect(captured['attachmentKeys'], ['support/u1/1_a.jpg']);
    expect(captured['content'], 'Voici');
  });
}
