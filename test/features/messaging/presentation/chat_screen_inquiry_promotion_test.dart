import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestore extends Mock implements FirestoreChatRepository {}

class _MockConversations extends Mock implements ConversationRepository {}

typedef _Parent = ({
  String? askerId,
  bool quotaLifted,
  bool exists,
  bool fromCache,
});

_Parent _parent({bool lifted = false}) =>
    (askerId: _me, quotaLifted: lifted, exists: true, fromCache: false);

const _me = 'uid-asker';
const _fsId = 'conv_q';

/// Conversation telle que l'écran l'a reçue à l'ouverture.
const _inquiry = ConversationModel(
  id: 'conv-q',
  firestoreConversationId: _fsId,
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa Diallo'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'ann-9',
  inquiryMessageLimit: 10,
  tripOrigin: 'Paris',
  tripDestination: 'Dakar',
);

/// La même conversation une fois la demande créée : le back rend le `bidId`
/// et le type ordinaire.
const _promoted = ConversationModel(
  id: 'conv-q',
  firestoreConversationId: _fsId,
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa Diallo'),
  bidId: 'bid-1',
  tripOrigin: 'Paris',
  tripDestination: 'Dakar',
);

void main() {
  late _MockFirestore fs;
  late _MockConversations conversations;
  late StreamController<_Parent> parentCtrl;
  late StreamController<int> sentCtrl;
  late List<String> pushed;

  final quotaBar = find.byKey(const Key('inquiry-quota-bar'));
  final bookingButton = find.byKey(const Key('inquiry-booking-button'));
  final lockedBar = find.byKey(const Key('inquiry-locked-bar'));
  final composer = find.byType(DonyChatComposer);
  final tripBanner = find.byKey(const Key('chat-trip-banner'));

  setUpAll(() async {
    await initializeDateFormatting('fr');
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
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'fr';
    addTearDown(() => Intl.defaultLocale = previous);
    fs = _MockFirestore();
    conversations = _MockConversations();
    parentCtrl = StreamController<_Parent>.broadcast();
    sentCtrl = StreamController<int>.broadcast();
    pushed = [];
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
      () => fs.inquiryParentStream(_fsId),
    ).thenAnswer((_) => parentCtrl.stream);
    when(() => fs.inquirySentStream(_fsId)).thenAnswer((_) => sentCtrl.stream);
    when(
      () => conversations.getConversation('conv-q'),
    ).thenAnswer((_) async => _promoted);
  });

  tearDown(() async {
    await parentCtrl.close();
    await sentCtrl.close();
  });

  Future<ChatBloc> pumpScreen(
    WidgetTester tester, {
    ConversationModel conversation = _inquiry,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    unawaited(analytics.onConfigured());
    final bloc = ChatBloc(fs, conversations, analytics);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: ChatScreen(
            conversation: conversation,
            currentUidOverride: _me,
            onNavigate: (path, _) => pushed.add(path),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return bloc;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> emitLimited(WidgetTester tester, int sent) async {
    parentCtrl.add(_parent());
    await settle(tester);
    sentCtrl.add(sent);
    await settle(tester);
  }

  testWidgets('quota levé par le back : bandeau, carte et verrou disparaissent '
      'sans quitter l\'écran, puis reviennent au reverrouillage', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emitLimited(tester, 3);

    expect(quotaBar, findsOneWidget);
    expect(find.text('7 messages restants'), findsOneWidget);
    expect(bookingButton, findsOneWidget);
    expect(composer, findsOneWidget);

    // La demande est créée : le back lève le plafond.
    parentCtrl.add(_parent(lifted: true));
    await settle(tester);
    expect(quotaBar, findsNothing);
    expect(bookingButton, findsNothing);
    expect(lockedBar, findsNothing);
    expect(composer, findsOneWidget);
    expect(pushed, isEmpty, reason: 'aucune navigation');

    // Le plafond est rétabli : retour en mode limité, compteur exact. Le back
    // rend de nouveau le fil de questions, relu par le bloc.
    when(
      () => conversations.getConversation('conv-q'),
    ).thenAnswer((_) async => _inquiry);
    parentCtrl.add(_parent());
    await settle(tester);
    sentCtrl.add(3);
    await settle(tester);
    expect(quotaBar, findsOneWidget);
    expect(find.text('7 messages restants'), findsOneWidget);
    expect(bookingButton, findsOneWidget);
    expect(pushed, isEmpty);
  });

  testWidgets('ouvert promu (déjà levé) puis reverrouillé : barre de quota '
      'et carte de réservation reviennent (I4)', (tester) async {
    const promotedWithTrip = ConversationModel(
      id: 'conv-q',
      firestoreConversationId: _fsId,
      otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa Diallo'),
      bidId: 'bid-1',
      announcementId: 'ann-9',
      inquiryQuotaLifted: true,
      tripOrigin: 'Paris',
      tripDestination: 'Dakar',
    );
    when(
      () => conversations.getConversation('conv-q'),
    ).thenAnswer((_) async => _inquiry);
    await pumpScreen(tester, conversation: promotedWithTrip);
    parentCtrl.add(_parent(lifted: true));
    await settle(tester);
    expect(quotaBar, findsNothing);
    expect(composer, findsOneWidget);

    // La demande s'est terminée sans être acceptée : le back reverrouille.
    parentCtrl.add(_parent());
    await settle(tester);
    sentCtrl.add(4);
    await settle(tester);
    expect(quotaBar, findsOneWidget);
    expect(find.text('6 messages restants'), findsOneWidget);
    expect(bookingButton, findsOneWidget);
    await tester.tap(bookingButton);
    await tester.pump();
    expect(pushed, ['/traveler/ann-9']);
  });

  testWidgets('plafond atteint puis levé : le verrou cède la place au '
      'composeur', (tester) async {
    await pumpScreen(tester);
    await emitLimited(tester, 10);
    expect(lockedBar, findsOneWidget);
    expect(composer, findsNothing);

    parentCtrl.add(_parent(lifted: true));
    await settle(tester);
    expect(lockedBar, findsNothing);
    expect(bookingButton, findsNothing);
    expect(composer, findsOneWidget);
  });

  testWidgets('après la levée, le modèle relu remplace celui de l\'ouverture : '
      'la bannière du trajet mène au colis', (tester) async {
    await pumpScreen(tester);
    await emitLimited(tester, 3);

    // Levée par le seul flux du document parent : une seule relecture.
    parentCtrl.add(_parent(lifted: true));
    await settle(tester);
    verify(() => conversations.getConversation('conv-q')).called(1);

    pushed.clear();
    await tester.tap(tripBanner);
    await tester.pump();
    expect(pushed, ['/bids/bid-1']);
  });

  testWidgets('retour de la fiche du trajet : la conversation est relue et le '
      'fil passe en direct', (tester) async {
    await pumpScreen(tester);
    await emitLimited(tester, 3);

    await tester.tap(bookingButton);
    await settle(tester);

    expect(pushed, ['/traveler/ann-9']);
    verify(() => conversations.getConversation('conv-q')).called(1);
    expect(quotaBar, findsNothing);
    expect(bookingButton, findsNothing);
    expect(composer, findsOneWidget);
  });

  testWidgets('relecture en échec : le chat reste utilisable avec l\'ancien '
      'modèle', (tester) async {
    when(
      () => conversations.getConversation('conv-q'),
    ).thenThrow(StateError('réseau'));
    await pumpScreen(tester);
    await emitLimited(tester, 3);

    parentCtrl.add(_parent(lifted: true));
    await settle(tester);

    expect(quotaBar, findsNothing);
    expect(composer, findsOneWidget);
    expect(tester.takeException(), isNull);
    // Ancien modèle : la bannière rouvre encore la fiche du trajet.
    await tester.tap(tripBanner);
    await tester.pump();
    expect(pushed, ['/traveler/ann-9']);
  });
}
