import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');
const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

MessageModel _msg(
  String id, {
  String? body,
  String senderId = 'uid-1',
  MessageType type = MessageType.text,
  String? replyToId,
  String? deletedAt,
  DateTime? sentAt,
}) => MessageModel(
  id: id,
  senderId: senderId,
  body: body ?? 'corps $id',
  type: type,
  sentAt: sentAt ?? DateTime(2026, 10, 7, 10),
  replyToId: replyToId,
  deletedAt: deletedAt,
  latitude: type == MessageType.location ? 14.69 : null,
  longitude: type == MessageType.location ? -17.44 : null,
);

Future<void> _pump(WidgetTester tester, ChatBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<ChatBloc>.value(
        value: bloc,
        child: const ChatScreen(conversation: _conversation),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Finder get _quote => find.byKey(const Key('chat-quote-tap'));

/// Texte d'une citation (bloc au-dessus du contenu d'une bulle).
Finder _quoteText(String text) => find.descendant(
  of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_QuoteBlock'),
  matching: find.text(text),
);

/// Réponse à un message précis (FLUTTER-86).
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
  });

  tearDown(() => bloc.close());

  group('citation dans la bulle', () {
    testWidgets('message cité dans le fil : auteur + extrait, tappable', (
      tester,
    ) async {
      final original = _msg('m1', body: 'Le colis pèse 3 kg');
      when(() => bloc.state).thenReturn(
        ChatLoaded([_msg('r1', body: 'Parfait', replyToId: 'm1'), original]),
      );
      await _pump(tester, bloc);

      expect(_quote, findsOneWidget);
      expect(_quoteText('Modibo Coulibaly'), findsOneWidget);
      expect(_quoteText('Le colis pèse 3 kg'), findsOneWidget);
      expect(find.text('Parfait'), findsOneWidget);
    });

    testWidgets('mon propre message cité : auteur « Vous »', (tester) async {
      // FirebaseAuth absent en test : l'utilisateur courant a l'uid ''.
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg('r1', body: 'Oui', replyToId: 'm1'),
          _msg('m1', senderId: '', body: 'On part demain ?'),
        ]),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Vous'), findsOneWidget);
      expect(_quoteText('On part demain ?'), findsOneWidget);
    });

    testWidgets('ma propre réponse : citation dans ma bulle', (tester) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg('r1', senderId: '', body: 'Oui', replyToId: 'm1'),
          _msg('m1', body: 'Vous confirmez ?'),
        ]),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Modibo Coulibaly'), findsOneWidget);
      expect(_quoteText('Vous confirmez ?'), findsOneWidget);
    });

    testWidgets('photo, position et message supprimé : libellés dédiés', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _msg('r1', body: 'a', replyToId: 'img'),
          _msg('r2', body: 'b', replyToId: 'loc'),
          _msg('r3', body: 'c', replyToId: 'del'),
          _msg('img', type: MessageType.location).copyAsImage(),
          _msg('loc', type: MessageType.location),
          _msg('del', deletedAt: '2026-10-07T10:00:00Z'),
        ]),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Photo'), findsOneWidget);
      expect(_quoteText('Position'), findsOneWidget);
      expect(_quoteText('Message supprimé'), findsOneWidget);
    });

    testWidgets('hors du fil, en cours de lecture : « Chargement… »', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('r1', body: 'Oui', replyToId: 'old1')]));
      await _pump(tester, bloc);

      expect(_quoteText('Chargement…'), findsOneWidget);
      expect(_quote, findsNothing);
    });

    testWidgets('introuvable : « Message indisponible », sans auteur ni tap', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded(
          [_msg('r1', body: 'Oui', replyToId: 'gone')],
          quotedMessages: const {'gone': null},
        ),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Message indisponible'), findsOneWidget);
      expect(_quoteText('Modibo Coulibaly'), findsNothing);
      expect(_quote, findsNothing);
    });

    testWidgets('relu à l’unité (hors des 50 chargés) : affiché, sans tap', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded(
          [_msg('r1', body: 'Oui', replyToId: 'old1')],
          quotedMessages: {'old1': _msg('old1', body: 'Très ancien')},
        ),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Très ancien'), findsOneWidget);
      expect(_quoteText('Modibo Coulibaly'), findsOneWidget);
      expect(_quote, findsNothing);
    });

    testWidgets('fil en lecture seule : les citations restent affichées', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatReadOnly(
          [_msg('r1', body: 'Oui', replyToId: 'old1')],
          quotedMessages: {'old1': _msg('old1', body: 'Très ancien')},
        ),
      );
      await _pump(tester, bloc);

      expect(_quoteText('Très ancien'), findsOneWidget);
    });

    testWidgets('tap sur la citation : défile jusqu’au message cité', (
      tester,
    ) async {
      final base = DateTime(2026, 10, 7, 8);
      // Plus récent en tête (liste inversée) : r0 cite le plus ancien.
      final messages = [
        _msg('r0', body: 'Je réponds', replyToId: 'target', sentAt: base),
        for (var i = 1; i <= 40; i++)
          _msg(
            'f$i',
            body: 'Remplissage $i\nsur\nplusieurs\nlignes',
            sentAt: base.subtract(Duration(minutes: i)),
          ),
        _msg(
          'target',
          body: 'Message cible',
          sentAt: base.subtract(const Duration(minutes: 50)),
        ),
      ];
      when(() => bloc.state).thenReturn(ChatLoaded(messages));
      await _pump(tester, bloc);

      final bubble = find.widgetWithText(SelectableText, 'Message cible');
      expect(bubble, findsNothing);

      await tester.tap(_quote);
      await tester.pumpAndSettle();

      expect(bubble, findsOneWidget);
      // Surlignage bref, puis retour à la normale.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
    });
  });

  group('démarrer une réponse', () {
    testWidgets('appui long sur un texte → « Répondre » dans le menu', (
      tester,
    ) async {
      final m1 = _msg('m1', body: 'Tu arrives quand ?');
      when(() => bloc.state).thenReturn(ChatLoaded([m1]));
      await _pump(tester, bloc);

      await tester.longPress(find.text('Tu arrives quand ?'));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsOneWidget);
      // L'entrée « Copier le message » est toujours là.
      expect(find.text('Copier le message'), findsOneWidget);

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatReplyStarted>())),
      ).captured;
      expect((captured.single as ChatReplyStarted).message, m1);
      expect(find.text('Répondre'), findsNothing);
    });

    testWidgets('appui long sur une position → menu « Répondre »', (
      tester,
    ) async {
      final loc = _msg('loc', type: MessageType.location);
      when(() => bloc.state).thenReturn(ChatLoaded([loc]));
      await _pump(tester, bloc);

      await tester.longPress(find.text('Localisation partagée'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatReplyStarted>())),
      ).captured;
      expect((captured.single as ChatReplyStarted).message, loc);
    });

    testWidgets('appui long puis menu fermé sans choix : rien', (tester) async {
      final loc = _msg('loc', type: MessageType.location);
      when(() => bloc.state).thenReturn(ChatLoaded([loc]));
      await _pump(tester, bloc);

      await tester.longPress(find.text('Localisation partagée'));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<ChatReplyStarted>())));
    });

    testWidgets('balayage vers la droite sur la bulle → réponse', (
      tester,
    ) async {
      final m1 = _msg('m1', body: 'Balaye-moi');
      when(() => bloc.state).thenReturn(ChatLoaded([m1]));
      await _pump(tester, bloc);

      await tester.timedDrag(
        find.text('Balaye-moi'),
        const Offset(120, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatReplyStarted>())),
      ).captured;
      expect((captured.single as ChatReplyStarted).message, m1);
    });

    testWidgets('balayage trop court : la bulle revient, aucune réponse', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', body: 'Hop')]));
      await _pump(tester, bloc);

      await tester.timedDrag(
        find.text('Hop'),
        const Offset(30, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<ChatReplyStarted>())));
    });

    testWidgets('glissement vertical (défilement) : aucune réponse', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', body: 'Défile')]));
      await _pump(tester, bloc);

      await tester.timedDrag(
        find.text('Défile'),
        const Offset(10, -120),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<ChatReplyStarted>())));
    });

    testWidgets('balayage depuis le bord gauche : laissé au retour iOS', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', body: 'Bord')]));
      await _pump(tester, bloc);

      final row = tester.getCenter(find.text('Bord'));
      await tester.timedDragFrom(
        Offset(4, row.dy),
        const Offset(150, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<ChatReplyStarted>())));
    });

    testWidgets('action « Répondre » exposée au lecteur d’écran', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final m1 = _msg('m1', body: 'Accessible');
      when(() => bloc.state).thenReturn(ChatLoaded([m1]));
      await _pump(tester, bloc);

      // Fondu d'apparition terminé (à opacité nulle, la bulle est exclue de
      // l'arbre sémantique), puis parcours de tout l'arbre.
      await tester.pump(const Duration(seconds: 1));
      final labels = <String?>[];
      void visit(SemanticsNode node) {
        final ids = node.getSemanticsData().customSemanticsActionIds ?? [];
        labels.addAll(
          ids.map((id) => CustomSemanticsAction.getAction(id)?.label),
        );
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(labels, contains('Répondre'));
      handle.dispose();
    });

    testWidgets('fil en lecture seule ou message supprimé : pas de réponse', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatReadOnly([
          _msg('m1', body: 'Lecture seule'),
          _msg('d', deletedAt: '2026-10-07T10:00:00Z'),
        ]),
      );
      await _pump(tester, bloc);

      await tester.longPress(find.text('Lecture seule'));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsNothing);

      await tester.timedDrag(
        find.text('Lecture seule'),
        const Offset(120, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any(that: isA<ChatReplyStarted>())));
    });
  });

  group('barre « Réponse à … »', () {
    testWidgets('affichée pendant une réponse, ✕ annule', (tester) async {
      final m1 = _msg('m1', body: 'Le colis pèse 3 kg');
      when(() => bloc.state).thenReturn(ChatLoaded([m1], replyingTo: m1));
      await _pump(tester, bloc);

      expect(find.byKey(const Key('chat-reply-bar')), findsOneWidget);
      expect(find.text('Réponse à Modibo Coulibaly'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-reply-bar')),
          matching: find.text('Le colis pèse 3 kg'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('chat-reply-cancel')));
      await tester.pump();
      verify(() => bloc.add(any(that: isA<ChatReplyCancelled>()))).called(1);
    });

    testWidgets('réponse à son propre message : libellé dédié', (tester) async {
      final mine = _msg('m1', senderId: '', body: 'Je pars lundi');
      when(() => bloc.state).thenReturn(ChatLoaded([mine], replyingTo: mine));
      await _pump(tester, bloc);

      expect(find.text('Réponse à votre message'), findsOneWidget);
    });

    testWidgets('réponse à une photo : « Photo » dans la barre', (
      tester,
    ) async {
      final img = _msg('img').copyAsImage();
      when(() => bloc.state).thenReturn(ChatLoaded([], replyingTo: img));
      await _pump(tester, bloc);

      expect(
        find.descendant(
          of: find.byKey(const Key('chat-reply-bar')),
          matching: find.text('Photo'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-reply-bar')),
          matching: find.byWidgetPredicate(
            (w) => w is DonyIcon && w.name == 'image',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('absente hors réponse', (tester) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1')]));
      await _pump(tester, bloc);

      expect(find.byKey(const Key('chat-reply-bar')), findsNothing);
    });

    testWidgets('envoi : replyToId du message cité joint au texte validé', (
      tester,
    ) async {
      final m1 = _msg('m1', body: 'Tu arrives quand ?');
      when(() => bloc.state).thenReturn(ChatLoaded([m1], replyingTo: m1));
      await _pump(tester, bloc);

      await tester.enterText(find.byType(TextField), 'Demain matin');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'send'),
      );
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatTextSendRequested>())),
      ).captured;
      final event = captured.single as ChatTextSendRequested;
      expect(event.body, 'Demain matin');
      expect(event.replyToId, 'm1');
    });

    testWidgets('le validateur anti-contournement s’applique aux réponses', (
      tester,
    ) async {
      final m1 = _msg('m1', body: 'Votre numéro ?');
      when(() => bloc.state).thenReturn(ChatLoaded([m1], replyingTo: m1));
      await _pump(tester, bloc);

      await tester.enterText(
        find.byType(TextField),
        'appelle moi au 06 12 34 56 78',
      );
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'send'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      verifyNever(() => bloc.add(any(that: isA<ChatTextSendRequested>())));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('message ordinaire : replyToId null', (tester) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1')]));
      await _pump(tester, bloc);

      await tester.enterText(find.byType(TextField), 'Bonjour');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'send'),
      );
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChatTextSendRequested>())),
      ).captured;
      expect((captured.single as ChatTextSendRequested).replyToId, isNull);
    });
  });
}

extension on MessageModel {
  MessageModel copyAsImage() => MessageModel(
    id: id,
    senderId: senderId,
    imageUrl: 'https://cdn.example.com/p.jpg',
    type: MessageType.image,
    sentAt: sentAt,
  );
}
