import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

typedef _Parent = ({
  String? askerId,
  bool quotaLifted,
  bool exists,
  bool fromCache,
});

_Parent _p(
  String? asker, {
  bool lifted = false,
  bool exists = true,
  bool fromCache = false,
}) =>
    (askerId: asker, quotaLifted: lifted, exists: exists, fromCache: fromCache);

const _conv = 'conv_inq';
const _me = 'uid-asker';

ChatSubscribeRequested _subscribe({
  bool limited = true,
  int? limit = 10,
  String announcementId = 'ann-1',
}) => ChatSubscribeRequested(
  _conv,
  currentUserUid: _me,
  conversationId: 'api-1',
  inquiryLimited: limited,
  inquiryMessageLimit: limit,
  announcementId: announcementId,
);

ChatTextSendRequested _send([String body = 'Bonjour', String? replyToId]) =>
    ChatTextSendRequested(
      firestoreConversationId: _conv,
      conversationId: 'api-1',
      senderFirebaseUid: _me,
      body: body,
      replyToId: replyToId,
    );

ConversationModel _conversation({bool lifted = false}) => ConversationModel(
  id: 'api-1',
  firestoreConversationId: _conv,
  otherParticipant: const ParticipantModel(id: 'o', name: 'Owner'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'ann-1',
  inquiryMessageLimit: lifted ? null : 10,
  inquiryQuotaLifted: lifted,
);

const _direct = ConversationModel(
  id: 'api-1',
  firestoreConversationId: _conv,
  otherParticipant: ParticipantModel(id: 'o', name: 'Owner'),
  bidId: 'bid-1',
);

void main() {
  late MockFirestoreChatRepository fs;
  late MockConversationRepository conv;
  late StreamController<int> sentCtrl;
  late StreamController<_Parent> parentCtrl;

  void stubWrite(Future<void> Function() answer) {
    when(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    fs = MockFirestoreChatRepository();
    conv = MockConversationRepository();
    sentCtrl = StreamController<int>.broadcast();
    parentCtrl = StreamController<_Parent>.broadcast();
    when(() => fs.messagesStream(any())).thenAnswer((_) => Stream.value([]));
    when(
      () => fs.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(() => fs.markConversationRead(any(), any())).thenAnswer((_) async {});
    when(
      () => fs.markMessagesRead(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        currentUserUid: any(named: 'currentUserUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => fs.perConversationUnreadStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => fs.inquiryParentStream(_conv),
    ).thenAnswer((_) => parentCtrl.stream);
    when(() => fs.inquirySentStream(_conv)).thenAnswer((_) => sentCtrl.stream);
    when(() => fs.getMessage(any(), any())).thenAnswer((_) async => null);
    stubWrite(() async {});
    when(() => conv.updateLastMessage(any(), any())).thenAnswer((_) async {});
    when(
      () => conv.getConversation('api-1'),
    ).thenAnswer((_) async => _conversation());
  });

  tearDown(() async {
    await sentCtrl.close();
    await parentCtrl.close();
  });

  /// Premier appel : flux vivant du test ; ensuite : valeur relue au recalage.
  void freshSent(int value) {
    var calls = 0;
    when(
      () => fs.inquirySentStream(_conv),
    ).thenAnswer((_) => calls++ == 0 ? sentCtrl.stream : Stream.value(value));
  }

  ChatBloc makeBloc({Duration? parentTimeout, Duration? reconcileTimeout}) {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return ChatBloc(
      fs,
      conv,
      analytics,
      inquiryParentTimeout: parentTimeout ?? const Duration(seconds: 5),
      inquiryReconcileTimeout: reconcileTimeout ?? const Duration(seconds: 10),
    );
  }

  Future<ChatBloc> open(
    ChatSubscribeRequested event, {
    int? sent,
    String? asker = _me,
    bool parent = true,
    bool emitSent = true,
    Duration? parentTimeout,
    Duration? reconcileTimeout,
  }) async {
    final bloc = makeBloc(
      parentTimeout: parentTimeout,
      reconcileTimeout: reconcileTimeout,
    );
    bloc.add(event);
    await pumpEventQueue();
    if (parent) {
      parentCtrl.add(_p(asker));
      await pumpEventQueue();
    }
    if (emitSent && parent && asker == _me) {
      sentCtrl.add(sent ?? 0);
      await pumpEventQueue();
    }
    return bloc;
  }

  ChatLoaded loaded(ChatBloc b) => b.state as ChatLoaded;

  VerificationResult verifySentBefore(int? n, {String? body}) => verify(
    () => fs.sendTextMessage(
      firestoreConversationId: _conv,
      senderFirebaseUid: _me,
      body: body ?? any(named: 'body'),
      replyToId: any(named: 'replyToId'),
      inquirySentBefore: n,
    ),
  );

  void neverSentBefore(int? n, {String? body}) => verifyNever(
    () => fs.sendTextMessage(
      firestoreConversationId: _conv,
      senderFirebaseUid: _me,
      body: body ?? any(named: 'body'),
      replyToId: any(named: 'replyToId'),
      inquirySentBefore: n,
    ),
  );

  void verifyNoWrite() => verifyNever(
    () => fs.sendTextMessage(
      firestoreConversationId: any(named: 'firestoreConversationId'),
      senderFirebaseUid: any(named: 'senderFirebaseUid'),
      body: any(named: 'body'),
      replyToId: any(named: 'replyToId'),
      inquirySentBefore: any(named: 'inquirySentBefore'),
    ),
  );

  void failFirstWrite([Object? error]) {
    var calls = 0;
    stubWrite(() async {
      if (calls++ == 0) throw error ?? InquiryLimitReachedException();
    });
  }

  test('abonnement : inquiryRemaining = 10 - sent', () async {
    final bloc = await open(_subscribe(), sent: 3);
    expect(loaded(bloc).inquiryRemaining, 7);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    await bloc.close();
  });

  test('compteur absent du flux : 10 restants', () async {
    final bloc = await open(_subscribe());
    expect(loaded(bloc).inquiryRemaining, 10);
    await bloc.close();
  });

  test('limite nulle : repli sur 10', () async {
    final bloc = await open(_subscribe(limit: null), sent: 4);
    expect(loaded(bloc).inquiryRemaining, 6);
    await bloc.close();
  });

  test('le 10e envoi laisse 0 et verrouille', () async {
    final bloc = await open(_subscribe(), sent: 9);
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(9).called(1);
    expect(loaded(bloc).inquiryRemaining, 0);
    expect(loaded(bloc).inquiryLimitReached, isTrue);
    await bloc.close();
  });

  test('réponse citée : replyToId transmis dans le chemin INQUIRY', () async {
    final bloc = await open(_subscribe(), sent: 1);
    bloc.add(_send('Re', 'msgA'));
    await pumpEventQueue();
    verify(
      () => fs.sendTextMessage(
        firestoreConversationId: _conv,
        senderFirebaseUid: _me,
        body: 'Re',
        replyToId: 'msgA',
        inquirySentBefore: 1,
      ),
    ).called(1);
    await bloc.close();
  });

  test('envoi à 0 restant : refusé sans appel au dépôt, texte gardé', () async {
    final bloc = await open(_subscribe(), sent: 10);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('mon texte'));
    await pumpEventQueue();
    verifyNoWrite();
    final rejected = emitted.whereType<ChatSendRejected>().single;
    expect(rejected.text, 'mon texte');
    expect(rejected.inquiryLimit, isTrue);
    verifyNever(() => conv.openInquiry(any()));
    await sub.cancel();
    await bloc.close();
  });

  test('refus des règles : recalage puis un seul nouvel essai', () async {
    failFirstWrite();
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation());
    freshSent(4);
    final bloc = await open(_subscribe(), sent: 2);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send());
    await pumpEventQueue();
    verify(() => conv.openInquiry('ann-1')).called(1);
    verifySentBefore(2).called(1);
    verifySentBefore(4).called(1);
    expect(emitted.whereType<ChatSendRejected>(), isEmpty);
    expect(emitted.whereType<ChatSendFailed>(), isEmpty);
    expect(loaded(bloc).inquiryRemaining, 5);
    await sub.cancel();
    await bloc.close();
  });

  test(
    'second refus avec place restante : rejet générique, texte gardé',
    () async {
      stubWrite(() async => throw InquiryLimitReachedException());
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) async => _conversation());
      freshSent(6);
      final bloc = await open(_subscribe(), sent: 6);
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(_send('garde-moi'));
      await pumpEventQueue();
      final rejected = emitted.whereType<ChatSendRejected>().single;
      expect(rejected.text, 'garde-moi');
      expect(rejected.inquiryLimit, isFalse);
      verifySentBefore(6).called(2);
      expect(loaded(bloc).inquiryRemaining, 4);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('relecture au plafond : rejet « limite », aucun second essai', () async {
    failFirstWrite();
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation());
    freshSent(10);
    final bloc = await open(_subscribe(), sent: 8);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('x'));
    await pumpEventQueue();
    final rejected = emitted.whereType<ChatSendRejected>().single;
    expect(rejected.inquiryLimit, isTrue);
    expect(rejected.text, 'x');
    verifySentBefore(8).called(1);
    neverSentBefore(10);
    expect(loaded(bloc).inquiryRemaining, 0);
    await sub.cancel();
    await bloc.close();
  });

  test(
    'commit probablement réussi : pas de réécriture, pas de doublon',
    () async {
      failFirstWrite();
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) async => _conversation());
      when(() => fs.getMessage(_conv, 'inq3')).thenAnswer(
        (_) async => MessageModel(
          id: 'inq3',
          senderId: _me,
          body: 'Bonjour',
          type: MessageType.text,
          sentAt: DateTime.now(),
        ),
      );
      freshSent(3);
      final bloc = await open(_subscribe(), sent: 2);
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(2).called(1);
      neverSentBefore(3);
      expect(emitted.whereType<ChatSendRejected>(), isEmpty);
      expect(emitted.whereType<ChatSendFailed>(), isEmpty);
      expect(loaded(bloc).inquiryRemaining, 7);
      verify(() => conv.updateLastMessage('api-1', 'Bonjour')).called(1);
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'même compteur mais autre message : nouvel essai avec le compteur frais',
    () async {
      failFirstWrite();
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) async => _conversation());
      when(() => fs.getMessage(_conv, 'inq3')).thenAnswer(
        (_) async => MessageModel(
          id: 'inq3',
          senderId: _me,
          body: 'Autre texte',
          type: MessageType.text,
          sentAt: DateTime(2026),
        ),
      );
      freshSent(3);
      final bloc = await open(_subscribe(), sent: 2);
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(2).called(1);
      verifySentBefore(3).called(1);
      await bloc.close();
    },
  );

  test('quota levé au recalage : renvoi ordinaire', () async {
    failFirstWrite();
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation(lifted: true));
    final bloc = await open(_subscribe(), sent: 5);
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null).called(1);
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    await bloc.close();
  });

  test(
    'openInquiry échoue : échec réessayable, texte gardé, un seul écrit',
    () async {
      failFirstWrite();
      when(() => conv.openInquiry('ann-1')).thenThrow(Exception('réseau'));
      final bloc = await open(_subscribe(), sent: 2);
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      final event = _send('mon texte');
      bloc.add(event);
      await pumpEventQueue();
      final failed = emitted.whereType<ChatSendFailed>().single;
      expect(failed.text, 'mon texte');
      expect(failed.retry, same(event));
      verifySentBefore(2).called(1);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('openInquiry trop lent : échec réessayable', () async {
    failFirstWrite();
    when(() => conv.openInquiry('ann-1')).thenAnswer(
      (_) => Future<ConversationModel>.error(TimeoutException('lent')),
    );
    final bloc = await open(_subscribe(), sent: 2);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send());
    await pumpEventQueue();
    expect(emitted.whereType<ChatSendFailed>(), hasLength(1));
    await sub.cancel();
    await bloc.close();
  });

  test(
    'annonce inconnue : pas d\'appel openInquiry, relecture et nouvel essai',
    () async {
      failFirstWrite();
      freshSent(4);
      final bloc = await open(_subscribe(announcementId: ''), sent: 2);
      bloc.add(_send());
      await pumpEventQueue();
      verifyNever(() => conv.openInquiry(any()));
      verifySentBefore(4).called(1);
      await bloc.close();
    },
  );

  test('not-found sur le compteur absent : même recalage', () async {
    failFirstWrite(
      FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
    );
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation());
    freshSent(0);
    final bloc = await open(_subscribe(), sent: 3);
    bloc.add(_send());
    await pumpEventQueue();
    verify(() => conv.openInquiry('ann-1')).called(1);
    verifySentBefore(0).called(1);
    await bloc.close();
  });

  test(
    'levée par le document parent : efface compteur, verrou et abonnement',
    () async {
      final bloc = await open(_subscribe(), sent: 10);
      expect(loaded(bloc).inquiryLimitReached, isTrue);
      parentCtrl.add(_p(_me, lifted: true));
      await pumpEventQueue();
      expect(loaded(bloc).inquiryRemaining, isNull);
      expect(loaded(bloc).inquiryLimitReached, isFalse);
      expect(sentCtrl.hasListener, isFalse);
      expect(parentCtrl.hasListener, isTrue); // gardé pour un reverrouillage
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(null).called(1);
      await bloc.close();
      expect(parentCtrl.hasListener, isFalse);
    },
  );

  group('relecture de la conversation après la levée', () {
    test('levée : relue une fois, le modèle à jour est dans l\'état', () async {
      when(
        () => conv.getConversation('api-1'),
      ).thenAnswer((_) async => _direct);
      final bloc = await open(_subscribe(), sent: 4);
      expect(loaded(bloc).conversation, isNull);
      parentCtrl.add(_p(_me, lifted: true));
      await pumpEventQueue();
      verify(() => conv.getConversation('api-1')).called(1);
      expect(loaded(bloc).conversation?.bidId, 'bid-1');
      expect(loaded(bloc).conversation?.isInquiry, isFalse);
      // Un second signal de levée ne relit rien.
      parentCtrl.add(_p(_me, lifted: true));
      bloc.add(const ChatConversationRefreshRequested());
      await pumpEventQueue();
      await bloc.close();
    });

    test(
      'échec de lecture : ancien modèle gardé, nouvel essai possible',
      () async {
        var calls = 0;
        when(() => conv.getConversation('api-1')).thenAnswer((_) async {
          if (calls++ == 0) throw StateError('réseau');
          return _direct;
        });
        final bloc = await open(_subscribe(), sent: 4);
        parentCtrl.add(_p(_me, lifted: true));
        await pumpEventQueue();
        expect(loaded(bloc).conversation, isNull);
        expect(loaded(bloc).inquiryRemaining, isNull); // la levée tient
        bloc.add(const ChatConversationRefreshRequested());
        await pumpEventQueue();
        expect(loaded(bloc).conversation?.bidId, 'bid-1');
        await bloc.close();
      },
    );

    test(
      'retour de la fiche du trajet : levée constatée par le back',
      () async {
        when(
          () => conv.getConversation('api-1'),
        ).thenAnswer((_) async => _direct);
        final bloc = await open(_subscribe(), sent: 10);
        expect(loaded(bloc).inquiryLimitReached, isTrue);
        bloc.add(const ChatConversationRefreshRequested());
        await pumpEventQueue();
        expect(loaded(bloc).inquiryLimitReached, isFalse);
        expect(loaded(bloc).inquiryRemaining, isNull);
        expect(loaded(bloc).conversation?.bidId, 'bid-1');
        await bloc.close();
      },
    );

    test('retour sans demande créée : rien ne change', () async {
      final bloc = await open(_subscribe(), sent: 10);
      bloc.add(const ChatConversationRefreshRequested());
      await pumpEventQueue();
      expect(loaded(bloc).inquiryLimitReached, isTrue);
      expect(loaded(bloc).conversation, isNull);
      await bloc.close();
    });

    test('reverrouillage : le modèle relu est oublié', () async {
      when(
        () => conv.getConversation('api-1'),
      ).thenAnswer((_) async => _direct);
      final bloc = await open(_subscribe(), sent: 4);
      parentCtrl.add(_p(_me, lifted: true));
      await pumpEventQueue();
      expect(loaded(bloc).conversation, isNotNull);
      parentCtrl.add(_p(_me));
      await pumpEventQueue();
      expect(loaded(bloc).conversation, isNull);
      await bloc.close();
    });
  });

  test('quotaLifted reçu du document parent : levée en direct', () async {
    final bloc = await open(_subscribe(), sent: 10);
    parentCtrl.add(_p(_me, lifted: true));
    await pumpEventQueue();
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    expect(sentCtrl.hasListener, isFalse);
    await bloc.close();
  });

  test('conversation ordinaire : aucun champ, aucun abonnement', () async {
    final bloc = await open(_subscribe(limited: false), parent: false);
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    verifyNever(() => fs.inquirySentStream(any()));
    verifyNever(() => fs.inquiryParentStream(any()));
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null).called(1);
    await bloc.close();
  });

  test('créateur de l\'annonce : jamais de compteur ni de limite', () async {
    final bloc = await open(_subscribe(), sent: 10, asker: 'autre-uid');
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    verifyNever(() => fs.inquirySentStream(any()));
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null).called(1);
    await bloc.close();
  });

  test(
    'envoi avant la lecture du parent : attend, puis écrit avec le compteur',
    () async {
      final bloc = await open(_subscribe(), parent: false);
      bloc.add(_send());
      await pumpEventQueue();
      verifyNoWrite();
      parentCtrl.add(_p(_me));
      await pumpEventQueue();
      verifyNoWrite(); // le compteur n'a pas encore émis
      sentCtrl.add(0);
      await pumpEventQueue();
      verifySentBefore(0).called(1);
      await bloc.close();
    },
  );

  test(
    'parent jamais lu : échec réessayable, texte gardé, aucun écrit',
    () async {
      final bloc = await open(
        _subscribe(),
        parent: false,
        parentTimeout: const Duration(milliseconds: 50),
      );
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(_send('à garder'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final failed = emitted.whereType<ChatSendFailed>().single;
      expect(failed.text, 'à garder');
      verifyNoWrite();
      await sub.cancel();
      await bloc.close();
    },
  );

  test('flux du parent en erreur : l\'envoi échoue proprement', () async {
    final bloc = await open(
      _subscribe(),
      parent: false,
      parentTimeout: const Duration(milliseconds: 50),
    );
    parentCtrl.addError(Exception('hors ligne'));
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(emitted.whereType<ChatSendFailed>(), hasLength(1));
    verifyNoWrite();
    await sub.cancel();
    await bloc.close();
  });

  test('deux envois rapprochés : écritures ordonnées, sans refus', () async {
    final gate = Completer<void>();
    var calls = 0;
    stubWrite(() async {
      if (calls++ == 0) await gate.future;
    });
    final bloc = await open(_subscribe(), sent: 3);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('un'));
    bloc.add(_send('deux'));
    await pumpEventQueue();
    verifySentBefore(3, body: 'un').called(1);
    neverSentBefore(4, body: 'deux');
    gate.complete();
    await pumpEventQueue();
    verifySentBefore(4, body: 'deux').called(1);
    expect(emitted.whereType<ChatSendRejected>(), isEmpty);
    expect(loaded(bloc).inquiryRemaining, 5);
    await sub.cancel();
    await bloc.close();
  });

  test('fermeture : abonnements quota et parent annulés', () async {
    final bloc = await open(_subscribe(), sent: 1);
    expect(sentCtrl.hasListener, isTrue);
    expect(parentCtrl.hasListener, isTrue);
    await bloc.close();
    expect(sentCtrl.hasListener, isFalse);
    expect(parentCtrl.hasListener, isFalse);
  });

  test(
    'réouverture d\'un autre fil : abonnements précédents annulés',
    () async {
      final bloc = await open(_subscribe(), sent: 1);
      bloc.add(_subscribe(limited: false));
      await pumpEventQueue();
      expect(sentCtrl.hasListener, isFalse);
      expect(parentCtrl.hasListener, isFalse);
      await bloc.close();
    },
  );

  test('position et photo non envoyées dans une INQUIRY sous quota', () async {
    final bloc = await open(_subscribe(), sent: 1);
    bloc.add(
      const ChatLocationSendRequested(
        firestoreConversationId: _conv,
        conversationId: 'api-1',
        senderFirebaseUid: _me,
        latitude: 1,
        longitude: 2,
      ),
    );
    bloc.add(
      ChatImageSendRequested(
        conversationId: 'api-1',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    await pumpEventQueue();
    verifyNever(
      () => fs.sendLocationMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        replyToId: any(named: 'replyToId'),
      ),
    );
    verifyNever(
      () => conv.sendImage(any(), any(), replyToId: any(named: 'replyToId')),
    );
    expect(loaded(bloc).pendingImages, isEmpty);
    await bloc.close();
  });

  test('restant masqué tant que le compteur n\'a pas émis', () async {
    final bloc = await open(_subscribe(), emitSent: false);
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    sentCtrl.add(4);
    await pumpEventQueue();
    expect(loaded(bloc).inquiryRemaining, 6);
    await bloc.close();
  });

  test(
    'envoi avant le compteur serveur (1), même texte : écrit inq2, sans faux doublon',
    () async {
      when(() => fs.getMessage(_conv, 'inq1')).thenAnswer(
        (_) async => MessageModel(
          id: 'inq1',
          senderId: _me,
          body: 'Bonjour',
          type: MessageType.text,
          sentAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      final bloc = await open(_subscribe(), emitSent: false);
      bloc.add(_send());
      await pumpEventQueue();
      verifyNoWrite();
      sentCtrl.add(1);
      await pumpEventQueue();
      verifySentBefore(1, body: 'Bonjour').called(1);
      verifyNever(() => fs.getMessage(any(), any()));
      expect(loaded(bloc).inquiryRemaining, 8);
      await bloc.close();
    },
  );

  test('compteur jamais émis : échec réessayable, texte gardé', () async {
    final bloc = await open(
      _subscribe(),
      emitSent: false,
      parentTimeout: const Duration(milliseconds: 50),
    );
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('à garder'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(emitted.whereType<ChatSendFailed>().single.text, 'à garder');
    verifyNoWrite();
    await sub.cancel();
    await bloc.close();
  });

  test(
    '« Merci » puis « Merci » légitimes : le 2e n\'est pas pris pour un doublon',
    () async {
      var calls = 0;
      stubWrite(() async {
        if (calls++ == 1) throw InquiryLimitReachedException();
      });
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) async => _conversation());
      when(() => fs.getMessage(_conv, 'inq2')).thenAnswer(
        (_) async => MessageModel(
          id: 'inq2',
          senderId: _me,
          body: 'Merci',
          type: MessageType.text,
          sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      freshSent(2);
      final bloc = await open(_subscribe(), sent: 0);
      bloc.add(_send('Merci'));
      await pumpEventQueue();
      // Le serveur est déjà à 2 (un autre appareil) : inq2 existe, ancien.
      bloc.add(_send('Merci'));
      await pumpEventQueue();
      verifySentBefore(1, body: 'Merci').called(1); // tentative refusée
      verifySentBefore(2, body: 'Merci').called(1); // nouvel essai
      await bloc.close();
    },
  );

  test('créateur : les envois restent concurrents', () async {
    final gate = Completer<void>();
    var calls = 0;
    stubWrite(() async {
      if (calls++ == 0) await gate.future;
    });
    final bloc = await open(_subscribe(), asker: 'autre-uid');
    bloc.add(_send('un'));
    bloc.add(_send('deux'));
    await pumpEventQueue();
    verifySentBefore(null, body: 'deux').called(1);
    gate.complete();
    await bloc.close();
  });

  test('conversation ordinaire : les envois restent concurrents', () async {
    final gate = Completer<void>();
    var calls = 0;
    stubWrite(() async {
      if (calls++ == 0) await gate.future;
    });
    final bloc = await open(_subscribe(limited: false), parent: false);
    bloc.add(_send('un'));
    bloc.add(_send('deux'));
    await pumpEventQueue();
    verifySentBefore(null, body: 'deux').called(1);
    gate.complete();
    await bloc.close();
  });

  test('quota levé pendant le recalage : envoi ordinaire', () async {
    failFirstWrite();
    when(() => conv.openInquiry('ann-1')).thenAnswer((_) async {
      parentCtrl.add(_p(_me, lifted: true));
      await Future<void>.delayed(Duration.zero);
      return _conversation();
    });
    freshSent(4);
    final bloc = await open(_subscribe(), sent: 2);
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(2).called(1);
    verifySentBefore(null).called(1);
    await bloc.close();
  });

  test(
    'instantané vide du cache ignoré, puis serveur : demandeur connu',
    () async {
      final bloc = await open(_subscribe(), parent: false);
      parentCtrl.add(_p(null, exists: false, fromCache: true));
      await pumpEventQueue();
      bloc.add(_send());
      await pumpEventQueue();
      verifyNoWrite();
      parentCtrl.add(_p(_me));
      await pumpEventQueue();
      sentCtrl.add(0);
      await pumpEventQueue();
      verifySentBefore(0).called(1);
      await bloc.close();
    },
  );

  test(
    'document absent côté serveur : pas demandeur, envoi ordinaire',
    () async {
      final bloc = await open(_subscribe(), parent: false);
      parentCtrl.add(_p(null, exists: false));
      await pumpEventQueue();
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(null).called(1);
      await bloc.close();
    },
  );

  test('askerId nul : jamais de compteur', () async {
    final bloc = await open(_subscribe(), asker: null);
    expect(loaded(bloc).inquiryRemaining, isNull);
    verifyNever(() => fs.inquirySentStream(any()));
    await bloc.close();
  });

  test(
    'erreur du flux parent : inconnu, réabonnement à l\'envoi suivant',
    () async {
      final bloc = await open(_subscribe(), sent: 0);
      parentCtrl.addError(Exception('hors ligne'));
      await pumpEventQueue();
      bloc.add(_send('x'));
      await pumpEventQueue();
      verifyNoWrite();
      verify(() => fs.inquiryParentStream(_conv)).called(2);
      parentCtrl.add(_p(_me));
      await pumpEventQueue();
      sentCtrl.add(0);
      await pumpEventQueue();
      verifySentBefore(0).called(1);
      await bloc.close();
    },
  );

  test(
    'fermeture pendant l\'attente du parent : rien d\'écrit ni d\'émis',
    () async {
      final bloc = await open(_subscribe(), parent: false);
      bloc.add(_send());
      await pumpEventQueue();
      await bloc.close();
      await pumpEventQueue();
      verifyNoWrite();
    },
  );

  test(
    'levée puis reverrouillage : de nouveau limité, compteur exact',
    () async {
      final bloc = await open(_subscribe(), sent: 4);
      parentCtrl.add(_p(_me, lifted: true));
      await pumpEventQueue();
      expect(loaded(bloc).inquiryRemaining, isNull);
      parentCtrl.add(_p(_me));
      await pumpEventQueue();
      expect(sentCtrl.hasListener, isTrue);
      expect(loaded(bloc).inquiryRemaining, isNull); // compteur pas encore relu
      sentCtrl.add(7);
      await pumpEventQueue();
      expect(loaded(bloc).inquiryRemaining, 3);
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(7).called(1);
      await bloc.close();
    },
  );

  test(
    'openInquiry réellement lent : échec réessayable, la file n\'est pas bloquée',
    () async {
      failFirstWrite();
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) => Completer<ConversationModel>().future);
      final bloc = await open(
        _subscribe(),
        sent: 2,
        reconcileTimeout: const Duration(milliseconds: 50),
      );
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(_send('un'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(emitted.whereType<ChatSendFailed>(), hasLength(1));
      await sub.cancel();
      await bloc.close();
    },
  );
}
