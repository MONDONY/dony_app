import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');

ConversationModel _conversation({String? bidStatus}) => ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  bidStatus: bidStatus,
);

void main() {
  late _MockChatBloc bloc;
  late _MockConversationListBloc listBloc;
  late StreamController<ChatState> states;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const ConversationRemovedLocally('x'));
    registerFallbackValue(
      const ChatConversationDeleteRequested(
        conversationId: 'x',
        firestoreConversationId: 'x',
      ),
    );
  });

  setUp(() {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr';
    addTearDown(() => Intl.defaultLocale = previousLocale);
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
    getIt.registerSingleton<BlockEventsService>(BlockEventsService());
    listBloc = _MockConversationListBloc();
    getIt.registerSingleton<ConversationListBloc>(listBloc);
    bloc = _MockChatBloc();
    states = StreamController<ChatState>.broadcast();
  });

  tearDown(() async {
    await states.close();
    await GetIt.instance.reset();
  });

  /// Le chat est poussé sur une liste, pour que `context.pop()` y revienne.
  Future<void> pump(
    WidgetTester tester,
    ChatState initial, {
    ConversationModel? conversation,
  }) async {
    whenListen(bloc, states.stream, initialState: initial);
    final router = GoRouter(
      initialLocation: '/messages/chat',
      routes: [
        GoRoute(
          path: '/messages',
          builder: (_, _) => const Scaffold(body: Text('liste')),
          routes: [
            GoRoute(
              path: 'chat',
              builder: (_, _) => BlocProvider<ChatBloc>.value(
                value: bloc,
                child: ChatScreen(
                  conversation: conversation ?? _conversation(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('suppression de la conversation', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer la conversation'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('annuler referme le dialogue sans rien supprimer', (
      tester,
    ) async {
      await pump(tester, const ChatLoaded([]));
      await openDialog(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(
        () => bloc.add(any(that: isA<ChatConversationDeleteRequested>())),
      );
    });

    testWidgets('confirmer envoie la suppression au BLoC', (tester) async {
      await pump(tester, const ChatLoaded([]));
      await openDialog(tester);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      final event =
          verify(
                () => bloc.add(
                  captureAny(that: isA<ChatConversationDeleteRequested>()),
                ),
              ).captured.single
              as ChatConversationDeleteRequested;
      expect(event.conversationId, 'conv-1');
      expect(event.firestoreConversationId, 'conv_bid-1');
    });

    testWidgets('conversation supprimée : retirée de la liste, retour', (
      tester,
    ) async {
      await pump(tester, const ChatLoaded([]));
      states.add(const ChatConversationDeleted());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final removed =
          verify(() => listBloc.add(captureAny())).captured.single
              as ConversationRemovedLocally;
      expect(removed.conversationId, 'conv-1');
      expect(find.text('liste'), findsOneWidget);
      expect(find.text('Conversation supprimée'), findsWidgets);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  testWidgets('connexion perdue : « Réessayer » se réabonne au fil', (
    tester,
  ) async {
    await pump(tester, const ChatError(NetworkException('réseau')));
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    final event =
        verify(
              () => bloc.add(captureAny(that: isA<ChatSubscribeRequested>())),
            ).captured.last
            as ChatSubscribeRequested;
    expect(event.firestoreConversationId, 'conv_bid-1');
    expect(event.conversationId, 'conv-1');
    expect(event.isReadOnly, isFalse);
  });

  testWidgets('erreur ponctuelle pendant le fil : avis d\'erreur', (
    tester,
  ) async {
    await pump(tester, const ChatLoaded([]));
    states.add(const ChatError(NetworkException('réseau')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Le fil cède la place à l'état « connexion interrompue ».
    expect(find.text('Connexion interrompue'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  group('bandeau d\'état de la demande', () {
    for (final (status, label) in [
      ('BID_ACCEPTED', 'Offre acceptée'),
      ('DELIVERY_CONFIRMED', 'Livraison confirmée'),
      ('TRIP_CANCELLED', 'Trajet annulé'),
    ]) {
      testWidgets('$status → « $label »', (tester) async {
        await pump(
          tester,
          const ChatLoaded([]),
          conversation: _conversation(bidStatus: status),
        );
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('statut sans bandeau : rien', (tester) async {
      await pump(
        tester,
        const ChatLoaded([]),
        conversation: _conversation(bidStatus: 'PENDING'),
      );
      expect(find.text('Offre acceptée'), findsNothing);
      expect(find.text('Trajet annulé'), findsNothing);
    });
  });

  testWidgets('bulles : supprimées, position, lu et séparateur « Hier »', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final at = DateTime(yesterday.year, yesterday.month, yesterday.day, 12);
    await pump(
      tester,
      ChatLoaded([
        MessageModel(
          id: 'm1',
          senderId: 'uid-1',
          body: 'texte effacé',
          type: MessageType.text,
          sentAt: at,
          deletedAt: '2026-10-10T12:00:00Z',
        ),
        MessageModel(
          id: 'm2',
          senderId: '',
          body: 'effacé aussi',
          type: MessageType.text,
          sentAt: at.add(const Duration(minutes: 1)),
          deletedAt: '2026-10-10T12:00:00Z',
        ),
        MessageModel(
          id: 'm3',
          senderId: '',
          type: MessageType.location,
          sentAt: at.add(const Duration(minutes: 2)),
          latitude: 14.69375,
          longitude: -17.44406,
        ),
        MessageModel(
          id: 'm3b',
          senderId: 'uid-1',
          type: MessageType.location,
          sentAt: at.add(const Duration(minutes: 2, seconds: 30)),
          latitude: 5.36,
          longitude: -4.0083,
        ),
        MessageModel(
          id: 'm4',
          senderId: '',
          body: 'Bien reçu',
          type: MessageType.text,
          sentAt: at.add(const Duration(minutes: 3)),
          readAt: at.add(const Duration(minutes: 4)),
        ),
        MessageModel(
          id: 'm5',
          senderId: 'system',
          body: 'ancien message',
          type: MessageType.system,
          sentAt: at.add(const Duration(minutes: 5)),
          deletedAt: '2026-10-10T12:00:00Z',
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Message supprimé'), findsNWidgets(3));
    expect(find.text('texte effacé'), findsNothing);
    expect(find.textContaining(', -17.4441'), findsOneWidget);
    expect(find.text('5.3600, -4.0083'), findsOneWidget);
    expect(find.text('Bien reçu'), findsOneWidget);
  });
}
