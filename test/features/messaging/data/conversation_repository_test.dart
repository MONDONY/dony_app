import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Map<String, dynamic> _conversationJson(String id) => {
  'id': id,
  'bidId': 'bid-$id',
  'firestoreConversationId': 'conv_$id',
  'otherParticipant': {'id': 'user-2', 'name': 'Fatou'},
  'hasUnread': false,
  'unreadCount': 0,
};

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient client;
  late MockDio dio;
  late ConversationRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = ConversationRepository(client);
  });

  group('getArchivedConversations', () {
    test('lit une page paginée ({content: [...]})', () async {
      when(() => dio.get('/conversations/archived')).thenAnswer(
        (_) async => _ok({
          'content': [_conversationJson('c1'), _conversationJson('c2')],
          'page': 0,
          'size': 2,
          'totalElements': 2,
          'totalPages': 1,
          'last': true,
        }, '/conversations/archived'),
      );

      final result = await repository.getArchivedConversations();

      expect(result.map((c) => c.id), ['c1', 'c2']);
      expect(result.first.otherParticipant.name, 'Fatou');
    });

    test('lit aussi la liste nue renvoyée par un serveur antérieur', () async {
      // Régression : le cast en Map sur une List levait une TypeError et
      // l'écran des archivées échouait dès que le serveur n'était pas à jour.
      when(() => dio.get('/conversations/archived')).thenAnswer(
        (_) async => _ok([_conversationJson('c9')], '/conversations/archived'),
      );

      final result = await repository.getArchivedConversations();

      expect(result.single.id, 'c9');
    });

    test(
      'rend une liste vide sur une page sans contenu ou un corps vide',
      () async {
        when(() => dio.get('/conversations/archived')).thenAnswer(
          (_) async => _ok(<String, dynamic>{}, '/conversations/archived'),
        );
        expect(await repository.getArchivedConversations(), isEmpty);

        when(
          () => dio.get('/conversations/archived'),
        ).thenAnswer((_) async => _ok(null, '/conversations/archived'));
        expect(await repository.getArchivedConversations(), isEmpty);
      },
    );
  });

  group('getConversationPage', () {
    Map<String, dynamic> dated(String id, String? at) => {
      ..._conversationJson(id),
      'lastMessageAt': at,
    };

    void stubList(dynamic data) {
      when(
        () => dio.get(
          '/conversations',
          queryParameters: {'size': ConversationRepository.pageSize},
        ),
      ).thenAnswer((_) async => _ok(data, '/conversations'));
    }

    test('demande une grande page et la dit complète sur `last`', () async {
      stubList({
        'content': [_conversationJson('a1')],
        'last': true,
      });

      final page = await repository.getConversationPage();

      expect(page.items.single.id, 'a1');
      expect(page.isComplete, isTrue);
    });

    test('une page suivie d\'autres, ou sans `last`, est incomplète', () async {
      stubList({
        'content': [_conversationJson('a1')],
        'last': false,
      });
      expect((await repository.getConversationPage()).isComplete, isFalse);

      stubList({
        'content': [_conversationJson('a1')],
      });
      expect((await repository.getConversationPage()).isComplete, isFalse);
    });

    test('un corps illisible rend une page vide et incomplète', () async {
      stubList(null);

      final page = await repository.getConversationPage();

      expect(page.items, isEmpty);
      expect(page.isComplete, isFalse);
    });

    test(
      'trie par dernier message, fils sans date en fin (serveur non trié)',
      () async {
        stubList({
          'content': [
            dated('old', '2026-09-01T10:00:00'),
            dated('undated', null),
            dated('recent', '2026-09-29T07:55:00'),
            dated('middle', '2026-09-15T10:00:00'),
          ],
          'last': true,
        });

        final page = await repository.getConversationPage();

        expect(page.items.map((c) => c.id), [
          'recent',
          'middle',
          'old',
          'undated',
        ]);
      },
    );
  });

  group('sortByLastMessage', () {
    test('garde l\'ordre reçu à égalité', () {
      final sorted = ConversationRepository.sortByLastMessage([
        ConversationModel.fromJson(_conversationJson('b')),
        ConversationModel.fromJson(_conversationJson('a')),
      ]);

      expect(sorted.map((c) => c.id), ['b', 'a']);
    });
  });
}
