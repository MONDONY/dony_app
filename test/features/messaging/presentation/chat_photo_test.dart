import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/chat_image_cache.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_photo_viewer_screen.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/messaging/presentation/widgets/chat_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _MockConvRepo extends Mock implements ConversationRepository {}

/// PNG 1×1 valide : Image.memory le décode sans erreur.
final kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

const _participant = ParticipantModel(id: 'uid-1', name: 'Awa Diallo');

ConversationModel _conv({
  bool readOnly = false,
  String? bidStatus,
  bool mediaAllowed = false,
}) => ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  readOnly: readOnly,
  bidStatus: bidStatus,
  mediaAllowed: mediaAllowed,
);

MessageModel _image(
  String id, {
  bool expired = false,
  String senderId = 'uid-1',
}) => MessageModel(
  id: id,
  senderId: senderId,
  type: MessageType.image,
  imageKey: 'messaging/conv_bid-1/${id}_full.jpg',
  thumbKey: 'messaging/conv_bid-1/${id}_thumb.jpg',
  imageExpired: expired,
  sentAt: DateTime(2026, 10, 7, 10),
);

MessageModel _text(String id, String body) => MessageModel(
  id: id,
  senderId: 'uid-1',
  body: body,
  type: MessageType.text,
  sentAt: DateTime(2026, 10, 7, 10),
);

void main() {
  late _MockChatBloc bloc;
  late _MockConvRepo repo;
  late List<(String, Object?)> routes;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(ChatImageVariant.thumb);
    registerFallbackValue(const ChatImageRetryRequested('x'));
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
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
    repo = _MockConvRepo();
    when(
      () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
    ).thenAnswer((_) async => kPng);
    if (getIt.isRegistered<ChatImageCache>()) {
      getIt.unregister<ChatImageCache>();
    }
    getIt.registerSingleton<ChatImageCache>(ChatImageCache(repo));
    routes = [];
  });

  tearDown(() => bloc.close());

  Future<void> pump(
    WidgetTester tester, {
    required ConversationModel conversation,
    Future<Uint8List?> Function(ImageSource)? pick,
    Future<bool?> Function(Uint8List)? preview,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: ChatScreen(
            conversation: conversation,
            onNavigate: (path, extra) => routes.add((path, extra)),
            pickPhotoOverride: pick,
            previewPhotoOverride: preview,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final attach = find.byKey(const Key('chat-attach-button'));

  group('trombone : règle d’état', () {
    test('masqué / grisé / actif', () {
      expect(
        chatAttachStateFor(_conv(), mediaAllowed: true, readOnly: false),
        ChatAttachState.enabled,
      );
      expect(
        chatAttachStateFor(_conv(), mediaAllowed: false, readOnly: false),
        ChatAttachState.locked,
      );
      expect(
        chatAttachStateFor(
          _conv(bidStatus: 'BID_ACCEPTED'),
          mediaAllowed: false,
          readOnly: false,
        ),
        ChatAttachState.locked,
      );
      for (final status in ['TRIP_CANCELLED', 'DELIVERY_CONFIRMED']) {
        expect(
          chatAttachStateFor(
            _conv(bidStatus: status),
            mediaAllowed: false,
            readOnly: false,
          ),
          ChatAttachState.hidden,
          reason: status,
        );
      }
      expect(
        chatAttachStateFor(_conv(), mediaAllowed: true, readOnly: true),
        ChatAttachState.hidden,
      );
      expect(
        chatAttachStateFor(
          _conv(readOnly: true),
          mediaAllowed: true,
          readOnly: false,
        ),
        ChatAttachState.hidden,
      );
      const deleted = ConversationModel(
        id: 'c',
        bidId: 'b',
        firestoreConversationId: 'f',
        otherParticipant: _participant,
        deletedBySelf: true,
      );
      expect(
        chatAttachStateFor(deleted, mediaAllowed: true, readOnly: false),
        ChatAttachState.hidden,
      );
    });
  });

  group('trombone dans la saisie', () {
    testWidgets('masqué : bid annulé', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await pump(tester, conversation: _conv(bidStatus: 'TRIP_CANCELLED'));
      expect(attach, findsNothing);
    });

    testWidgets('masqué : fil en lecture seule', (tester) async {
      when(() => bloc.state).thenReturn(const ChatReadOnly([]));
      await pump(tester, conversation: _conv());
      expect(attach, findsNothing);
    });

    testWidgets('grisé : le tap explique, « OK » referme', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await pump(tester, conversation: _conv());
      expect(attach, findsOneWidget);

      await tester.tap(attach);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Les photos seront disponibles une fois la demande acceptée et payée.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('chat-photo-locked-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-photo-locked-message')), findsNothing);
    });

    testWidgets('actif : galerie → aperçu → envoi au bloc', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const ChatLoaded([], mediaAllowed: true));
      ImageSource? picked;
      Uint8List? previewed;
      await pump(
        tester,
        conversation: _conv(mediaAllowed: true),
        pick: (source) async {
          picked = source;
          return kPng;
        },
        preview: (bytes) async {
          previewed = bytes;
          return true;
        },
      );

      await tester.tap(attach);
      await tester.pumpAndSettle();
      expect(find.text('Prendre une photo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-photo-source-gallery')));
      await tester.pumpAndSettle();

      expect(picked, ImageSource.gallery);
      expect(previewed, kPng);
      final event = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<ChatImageSendRequested>().single;
      expect(event.conversationId, 'conv-1');
      expect(event.bytes, kPng);
      expect(event.replyToId, isNull);
    });

    testWidgets('actif : appareil photo, aperçu annulé → rien n’est envoyé', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const ChatLoaded([], mediaAllowed: true));
      ImageSource? picked;
      await pump(
        tester,
        conversation: _conv(mediaAllowed: true),
        pick: (source) async {
          picked = source;
          return kPng;
        },
        preview: (_) async => false,
      );

      await tester.tap(attach);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-photo-source-camera')));
      await tester.pumpAndSettle();

      expect(picked, ImageSource.camera);
      verifyNever(() => bloc.add(any(that: isA<ChatImageSendRequested>())));
    });

    testWidgets('sélection en erreur → message « image non prise en charge »', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const ChatLoaded([], mediaAllowed: true));
      await pump(
        tester,
        conversation: _conv(mediaAllowed: true),
        pick: (_) async => throw Exception('video'),
        preview: (_) async => true,
      );

      await tester.tap(attach);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-photo-source-gallery')));
      await tester.pump();

      expect(
        find.text('Image non supportée ou trop volumineuse'),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any(that: isA<ChatImageSendRequested>())));
    });

    testWidgets('mediaAllowed relu par le bloc : le trombone s’active', (
      tester,
    ) async {
      // La conversation dit non, le bloc (après relecture) dit oui.
      when(
        () => bloc.state,
      ).thenReturn(const ChatLoaded([], mediaAllowed: true));
      await pump(tester, conversation: _conv());
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: attach, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, 1);
    });
  });

  group('bulles photo', () {
    testWidgets('photo du back : miniature puis tap → visionneuse', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_image('p1')]));
      await pump(tester, conversation: _conv());
      await tester.pump();

      expect(find.byKey(const Key('chat-photo-ready')), findsOneWidget);
      verify(
        () => repo.fetchImage('conv-1', 'p1', variant: ChatImageVariant.thumb),
      ).called(1);

      await tester.tap(find.byKey(const Key('chat-photo-ready')));
      final (path, extra) = routes.single;
      expect(path, '/chat/photo');
      final args = extra! as ChatPhotoViewerArgs;
      expect(args.conversationId, 'conv-1');
      expect(args.messageId, 'p1');
    });

    testWidgets(
      'photo purgée (imageExpired) : « Photo expirée » sans requête',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(ChatLoaded([_image('p1', expired: true)]));
        await pump(tester, conversation: _conv());

        expect(find.text('Photo expirée'), findsOneWidget);
        verifyNever(
          () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
        );
      },
    );

    testWidgets('410 du back : « Photo expirée »', (tester) async {
      when(
        () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            statusCode: 410,
            requestOptions: RequestOptions(path: '/x'),
          ),
        ),
      );
      when(() => bloc.state).thenReturn(ChatLoaded([_image('p1')]));
      await pump(tester, conversation: _conv());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Photo expirée'), findsOneWidget);
    });

    testWidgets('échec réseau : « Touchez pour réessayer » relance', (
      tester,
    ) async {
      var calls = 0;
      when(
        () => repo.fetchImage(any(), any(), variant: any(named: 'variant')),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return kPng;
      });
      when(() => bloc.state).thenReturn(ChatLoaded([_image('p1')]));
      await pump(tester, conversation: _conv());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Touchez pour réessayer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-photo-retry')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('chat-photo-ready')), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('bulle locale en cours puis en échec : Réessayer / Supprimer', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded(
          const [],
          mediaAllowed: true,
          pendingImages: [
            PendingChatImage(localId: 'local-2', bytes: kPng),
            PendingChatImage(
              localId: 'local-1',
              bytes: kPng,
              status: PendingChatImageStatus.failed,
            ),
          ],
        ),
      );
      await pump(tester, conversation: _conv(mediaAllowed: true));

      expect(find.text('Envoi…'), findsOneWidget);
      expect(find.text('Non envoyée'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-pending-retry')));
      await tester.tap(find.byKey(const Key('chat-pending-discard')));
      final events = verify(() => bloc.add(captureAny())).captured;
      expect(
        events.whereType<ChatImageRetryRequested>().single.localId,
        'local-1',
      );
      expect(
        events.whereType<ChatImageDiscardRequested>().single.localId,
        'local-1',
      );
    });

    testWidgets('signal d’échec d’envoi → message selon la cause', (
      tester,
    ) async {
      const loaded = ChatLoaded([], mediaAllowed: true);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable(const [
          ChatImageSendFailed(ChatImageFailure.rateLimited),
          loaded,
        ]),
        initialState: loaded,
      );
      await pump(tester, conversation: _conv(mediaAllowed: true));
      await tester.pump();

      expect(
        find.text(
          'Vous avez envoyé beaucoup de photos. Réessayez dans quelques minutes.',
        ),
        findsOneWidget,
      );
    });

    for (final (failure, text) in const [
      (
        ChatImageFailure.notAllowed,
        'L\'envoi de photos n\'est plus possible dans cette conversation.',
      ),
      (ChatImageFailure.other, 'La photo n\'a pas pu être envoyée.'),
    ]) {
      testWidgets('signal ${failure.name} → « $text »', (tester) async {
        const loaded = ChatLoaded([]);
        when(() => bloc.state).thenReturn(loaded);
        whenListen(
          bloc,
          Stream<ChatState>.fromIterable([
            ChatImageSendFailed(failure),
            loaded,
          ]),
          initialState: loaded,
        );
        await pump(tester, conversation: _conv());
        await tester.pump();
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('signal invalid → message image non prise en charge', (
      tester,
    ) async {
      const loaded = ChatLoaded([]);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable(const [
          ChatImageSendFailed(ChatImageFailure.invalid),
          loaded,
        ]),
        initialState: loaded,
      );
      await pump(tester, conversation: _conv());
      await tester.pump();
      expect(
        find.text('Image non supportée ou trop volumineuse'),
        findsOneWidget,
      );
    });
  });

  group('signaler un message', () {
    testWidgets('appui long sur une photo reçue → « Signaler » ouvre le '
        'signalement du message', (tester) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_image('p1')]));
      await pump(tester, conversation: _conv());
      await tester.pump();

      await tester.longPress(find.byKey(const Key('chat-photo-ready')));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsOneWidget);
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      final (path, extra) = routes.single;
      expect(path, '/settings/report-incident');
      expect(extra, {
        'targetType': IncidentTargetType.message,
        'targetId': 'conv-1',
        'messageId': 'p1',
      });
    });

    testWidgets('fil en lecture seule : « Signaler » reste proposé', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatReadOnly([_image('p1')]));
      await pump(tester, conversation: _conv(readOnly: true));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('chat-photo-ready')));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsNothing);
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      expect(routes.single.$1, '/settings/report-incident');
    });

    testWidgets('appui long sur un texte reçu → « Signaler » dans le menu', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_text('t1', 'Bonjour Awa')]));
      await pump(tester, conversation: _conv());

      await tester.longPress(find.text('Bonjour Awa'));
      await tester.pumpAndSettle();
      // Menu natif plein : « Signaler » peut passer dans le débordement.
      if (find.text('Signaler').evaluate().isEmpty) {
        await tester.tap(find.byType(IconButton).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      final (path, extra) = routes.single;
      expect(path, '/settings/report-incident');
      expect((extra! as Map)['messageId'], 't1');
    });
  });
}
