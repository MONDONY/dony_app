import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

const _me = 'uid-me';
const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly'),
);

MessageModel _msg(
  String id, {
  required String body,
  String senderId = _me,
  MessageType type = MessageType.text,
  DateTime? sentAt,
  DateTime? editedAt,
  String? deletedAt,
  String? deletedBy,
}) => MessageModel(
  id: id,
  senderId: senderId,
  body: body,
  type: type,
  sentAt: sentAt ?? DateTime.now().toUtc(),
  editedAt: editedAt,
  deletedAt: deletedAt,
  deletedBy: deletedBy,
);

/// Modification / suppression de ses messages (FLUTTER-MG).
void main() {
  late _MockChatBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const ChatReplyCancelled());
    if (!getIt.isRegistered<AnalyticsService>()) {
      getIt.registerSingleton<AnalyticsService>(
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
    }
    if (!getIt.isRegistered<BlockEventsService>()) {
      getIt.registerSingleton<BlockEventsService>(BlockEventsService());
    }
  });

  tearDownAll(() => GetIt.instance.reset());

  setUp(() {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr';
    addTearDown(() => Intl.defaultLocale = previousLocale);
    bloc = _MockChatBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.isClosed).thenReturn(false);
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const ChatScreen(
            conversation: _conversation,
            currentUidOverride: _me,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openMenu(WidgetTester tester, String text) async {
    await tester.longPress(find.text(text));
    await tester.pumpAndSettle();
  }

  group('menu d’appui long', () {
    testWidgets('mon message texte récent : « Modifier » et « Supprimer »', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'Je pars demain')]));
      await pump(tester);
      await openMenu(tester, 'Je pars demain');
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      // Pas de signalement de son propre message.
      expect(find.text('Signaler'), findsNothing);
    });

    testWidgets('au-delà de 15 minutes : ni « Modifier » ni « Supprimer »', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg(
            'm1',
            body: 'Message ancien',
            sentAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 16),
            ),
          ),
        ]),
      );
      await pump(tester);
      await openMenu(tester, 'Message ancien');
      expect(find.text('Répondre'), findsOneWidget);
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('message de l’interlocuteur : jamais modifiable', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([_msg('m1', body: 'Bonjour', senderId: 'uid-1')]),
      );
      await pump(tester);
      await openMenu(tester, 'Bonjour');
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('Signaler'), findsOneWidget);
    });

    testWidgets('fil en lecture seule : pas de modification', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatReadOnly([_msg('m1', body: 'Lecture seule')]));
      await pump(tester);
      await openMenu(tester, 'Lecture seule');
      expect(find.text('Modifier'), findsNothing);
    });
  });

  group('modifier', () {
    testWidgets('feuille pré-remplie, bouton actif après changement, envoi', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'Je pars demain')]));
      await pump(tester);
      await openMenu(tester, 'Je pars demain');
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le message'), findsOneWidget);
      final submit = find.byKey(const Key('chat-edit-submit'));
      expect(tester.widget<DonyButton>(submit).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('chat-edit-field')),
        'Je pars après-demain',
      );
      await tester.pump();
      expect(tester.widget<DonyButton>(submit).onPressed, isNotNull);

      await tester.tap(submit);
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatMessageEditRequested>())),
      ).captured;
      final event = captured.single as ChatMessageEditRequested;
      expect(event.messageId, 'm1');
      expect(event.text, 'Je pars après-demain');
      expect(find.text('Modifier le message'), findsNothing);
    });

    testWidgets('coordonnées refusées dans la feuille, rien n’est envoyé', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'Je pars demain')]));
      await pump(tester);
      await openMenu(tester, 'Je pars demain');
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat-edit-field')),
        'appelle le 06 12 34 56 78',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-edit-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le message'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<ChatMessageEditRequested>())));
    });
  });

  group('supprimer', () {
    testWidgets('confirmation puis événement de suppression', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'À supprimer')]));
      await pump(tester);
      await openMenu(tester, 'À supprimer');
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce message ?'), findsOneWidget);
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatMessageDeleteRequested>())),
      ).captured;
      expect((captured.single as ChatMessageDeleteRequested).messageId, 'm1');
    });

    testWidgets('annuler la confirmation : rien n’est envoyé', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'À garder')]));
      await pump(tester);
      await openMenu(tester, 'À garder');
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any(that: isA<ChatMessageDeleteRequested>())));
    });
  });

  group('affichage', () {
    testWidgets('message modifié : mention « modifié »', (tester) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg(
            'm1',
            body: 'Corrigé',
            senderId: 'uid-1',
            editedAt: DateTime.now().toUtc(),
          ),
        ]),
      );
      await pump(tester);
      expect(find.text('modifié'), findsOneWidget);
    });

    testWidgets('supprimé par l’auteur : « Message supprimé »', (tester) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg(
            'm1',
            body: '',
            senderId: 'uid-1',
            deletedAt: '2026-10-11T10:00:00.000Z',
            deletedBy: kDeletedByAuthor,
          ),
        ]),
      );
      await pump(tester);
      expect(find.text('Message supprimé'), findsOneWidget);
      expect(find.text('Message retiré par la modération'), findsNothing);
      expect(find.text('modifié'), findsNothing);
    });

    testWidgets('retiré par la modération : libellé distinct', (tester) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg(
            'm1',
            body: 'texte',
            senderId: 'uid-1',
            deletedAt: '2026-10-11T10:00:00.000Z',
          ),
        ]),
      );
      await pump(tester);
      expect(find.text('Message retiré par la modération'), findsOneWidget);
      expect(find.text('texte'), findsNothing);
    });

    testWidgets('échec : snackbar avec le message de la raison', (
      tester,
    ) async {
      final loaded = ChatLoaded([_msg('m1', body: 'Bonjour')]);
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable([
          const ChatMessageEditFailed(
            ChatMessageEditAction.edit,
            MessageEditFailure.unavailable,
          ),
          loaded,
        ]),
        initialState: loaded,
      );
      await pump(tester);
      await tester.pump();
      expect(find.textContaining('pas encore disponible'), findsOneWidget);
      // Le fil reste affiché.
      expect(find.text('Bonjour'), findsOneWidget);
    });
  });
}
