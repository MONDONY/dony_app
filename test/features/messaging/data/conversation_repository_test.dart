import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
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

  group('getConversations', () {
    test('lit le contenu de la page', () async {
      when(() => dio.get('/conversations')).thenAnswer(
        (_) async => _ok({
          'content': [_conversationJson('a1')],
        }, '/conversations'),
      );

      final result = await repository.getConversations();

      expect(result.single.id, 'a1');
    });
  });
}
