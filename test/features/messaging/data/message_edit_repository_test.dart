import 'package:cloud_functions/cloud_functions.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late MessageEditRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    repo = MessageEditRepository(functions);
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
  });

  group('appels', () {
    test('editMessage envoie conversationId, messageId, text', () async {
      when(
        () => callable.call<Object?>(any()),
      ).thenAnswer((_) async => _MockResult());
      await repo.editMessage(
        firestoreConversationId: 'conv_1',
        messageId: 'm1',
        text: 'Salut',
      );
      verify(
        () => functions.httpsCallable(
          'editMessage',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Object?>({
          'conversationId': 'conv_1',
          'messageId': 'm1',
          'text': 'Salut',
        }),
      ).called(1);
    });

    test('deleteMessage envoie conversationId, messageId', () async {
      when(
        () => callable.call<Object?>(any()),
      ).thenAnswer((_) async => _MockResult());
      await repo.deleteMessage(
        firestoreConversationId: 'conv_1',
        messageId: 'm1',
      );
      verify(
        () => functions.httpsCallable(
          'deleteMessage',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Object?>({
          'conversationId': 'conv_1',
          'messageId': 'm1',
        }),
      ).called(1);
    });

    test('FirebaseFunctionsException → MessageEditException classée', () {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'window-expired',
          code: 'failed-precondition',
          details: const {'reason': 'window-expired'},
        ),
      );
      expect(
        repo.deleteMessage(firestoreConversationId: 'c', messageId: 'm'),
        throwsA(
          isA<MessageEditException>().having(
            (e) => e.failure,
            'failure',
            MessageEditFailure.windowExpired,
          ),
        ),
      );
    });

    test('fonction absente (not-found sans détails) → unavailable', () {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'NOT_FOUND', code: 'not-found'),
      );
      expect(
        repo.editMessage(
          firestoreConversationId: 'c',
          messageId: 'm',
          text: 't',
        ),
        throwsA(
          isA<MessageEditException>().having(
            (e) => e.failure,
            'failure',
            MessageEditFailure.unavailable,
          ),
        ),
      );
    });

    test('toute autre erreur (plugin absent) → other, jamais de plantage', () {
      when(() => callable.call<Object?>(any())).thenThrow(StateError('x'));
      expect(
        repo.editMessage(
          firestoreConversationId: 'c',
          messageId: 'm',
          text: 't',
        ),
        throwsA(
          isA<MessageEditException>().having(
            (e) => e.failure,
            'failure',
            MessageEditFailure.other,
          ),
        ),
      );
    });
  });

  group('classify', () {
    final cases = <(String, String?, MessageEditFailure)>[
      (
        'failed-precondition',
        'window-expired',
        MessageEditFailure.windowExpired,
      ),
      ('failed-precondition', 'conversation-locked', MessageEditFailure.locked),
      ('permission-denied', 'not-participant', MessageEditFailure.locked),
      (
        'failed-precondition',
        'conversation-disputed',
        MessageEditFailure.disputed,
      ),
      ('permission-denied', 'messaging-muted', MessageEditFailure.muted),
      (
        'invalid-argument',
        'invalid-content',
        MessageEditFailure.invalidContent,
      ),
      ('not-found', 'message-not-found', MessageEditFailure.notEditable),
      ('permission-denied', 'not-author', MessageEditFailure.notEditable),
      (
        'failed-precondition',
        'not-editable-type',
        MessageEditFailure.notEditable,
      ),
      (
        'failed-precondition',
        'already-deleted',
        MessageEditFailure.notEditable,
      ),
      ('not-found', null, MessageEditFailure.unavailable),
      ('unimplemented', null, MessageEditFailure.unavailable),
      ('unavailable', null, MessageEditFailure.unavailable),
      ('permission-denied', null, MessageEditFailure.notEditable),
      ('failed-precondition', null, MessageEditFailure.notEditable),
      ('invalid-argument', null, MessageEditFailure.invalidContent),
      ('internal', 'internal', MessageEditFailure.other),
      ('deadline-exceeded', null, MessageEditFailure.other),
    ];
    for (final (code, reason, expected) in cases) {
      test('$code / $reason → ${expected.name}', () {
        expect(
          MessageEditRepository.classify(
            code,
            reason == null ? null : {'reason': reason},
          ),
          expected,
        );
      });
    }
    test('details non Map ignorés', () {
      expect(
        MessageEditRepository.classify('internal', 'texte'),
        MessageEditFailure.other,
      );
    });
  });

  test('MessageEditException.toString', () {
    expect(
      const MessageEditException(MessageEditFailure.locked).toString(),
      'MessageEditException(locked)',
    );
  });

  group('MessageModel', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    MessageModel m({
      String sender = 'me',
      MessageType type = MessageType.text,
      Duration age = const Duration(minutes: 5),
      String? deletedAt,
    }) => MessageModel(
      id: 'm',
      senderId: sender,
      body: 'x',
      type: type,
      sentAt: now.subtract(age),
      deletedAt: deletedAt,
    );

    test('isEditableBy : auteur, texte, < 15 min, non supprimé', () {
      expect(m().isEditableBy('me', now), isTrue);
      expect(m().isEditableBy('', now), isFalse);
      expect(m(sender: 'autre').isEditableBy('me', now), isFalse);
      expect(m(type: MessageType.location).isEditableBy('me', now), isFalse);
      expect(m(type: MessageType.image).isEditableBy('me', now), isFalse);
      expect(m(type: MessageType.system).isEditableBy('me', now), isFalse);
      expect(m(deletedAt: 'x').isEditableBy('me', now), isFalse);
      expect(
        m(age: const Duration(minutes: 15)).isEditableBy('me', now),
        isFalse,
      );
      expect(
        m(
          age: const Duration(minutes: 14, seconds: 59),
        ).isEditableBy('me', now),
        isTrue,
      );
    });

    test('fromFirestore lit editedAt et deletedBy', () {
      final edited = MessageModel.fromFirestore('a', {
        'senderId': 'me',
        'body': 'corrigé',
        'type': 'TEXT',
        'sentAt': '2026-10-11T10:00:00.000Z',
        'editedAt': '2026-10-11T10:05:00.000Z',
      });
      expect(edited.isEdited, isTrue);
      expect(edited.editedAt, DateTime.utc(2026, 10, 11, 10, 5));
      expect(edited.isDeleted, isFalse);

      final deleted = MessageModel.fromFirestore('b', {
        'senderId': 'me',
        'body': null,
        'type': 'TEXT',
        'sentAt': '2026-10-11T10:00:00.000Z',
        'editedAt': '2026-10-11T10:05:00.000Z',
        'deletedAt': '2026-10-11T10:06:00.000Z',
        'deletedBy': 'author',
      });
      expect(deleted.isDeletedByAuthor, isTrue);
      expect(deleted.isEdited, isFalse, reason: 'supprimé prime sur modifié');

      final moderated = MessageModel.fromFirestore('c', {
        'senderId': 'me',
        'body': 'texte',
        'type': 'TEXT',
        'sentAt': '2026-10-11T10:00:00.000Z',
        'deletedAt': '2026-10-11T10:06:00.000Z',
      });
      expect(moderated.isDeleted, isTrue);
      expect(moderated.isDeletedByAuthor, isFalse);

      final weird = MessageModel.fromFirestore('d', {
        'senderId': 'me',
        'type': 'TEXT',
        'editedAt': 12345,
        'deletedBy': '  ',
      });
      expect(weird.editedAt, isNull);
      expect(weird.deletedBy, isNull);
    });
  });
}
