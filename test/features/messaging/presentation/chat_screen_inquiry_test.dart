import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

const _inquiry = ConversationModel(
  id: 'conv-q',
  firestoreConversationId: 'conv_q',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa Diallo'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'ann-9',
  inquiryMessageLimit: 10,
  tripOrigin: 'Paris',
  tripDestination: 'Dakar',
);

const _ordinary = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa Diallo'),
  tripOrigin: 'Paris',
  tripDestination: 'Dakar',
);

MessageModel _msg(String id, String body) => MessageModel(
  id: id,
  senderId: 'uid-1',
  body: body,
  type: MessageType.text,
  sentAt: DateTime(2026, 11, 13, 10),
);

Future<void> _pump(
  WidgetTester tester,
  ChatBloc bloc,
  ConversationModel conversation, {
  void Function(String, Object?)? onNavigate,
  Locale locale = AppL10n.fr,
  AuthBloc? auth,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          if (auth != null) BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<ChatBloc>.value(value: bloc),
        ],
        child: ChatScreen(conversation: conversation, onNavigate: onNavigate),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late _MockChatBloc bloc;
  final analyticsBackend = MockAnalyticsBackend();
  final bookingButton = find.byKey(const Key('inquiry-booking-button'));
  final quotaBar = find.byKey(const Key('inquiry-quota-bar'));
  final lockedBar = find.byKey(const Key('inquiry-locked-bar'));
  final composer = find.byType(DonyChatComposer);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const ChatSubscribeRequested('x'));
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(analyticsBackend);
      await analytics.onConfigured();
      getIt.registerSingleton<AnalyticsService>(analytics);
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
    bloc = _MockChatBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    clearInteractions(analyticsBackend);
  });

  tearDown(() => bloc.close());

  void expectNoInquiryUi() {
    expect(quotaBar, findsNothing);
    expect(bookingButton, findsNothing);
    expect(lockedBar, findsNothing);
    expect(find.text('Faire une demande'), findsNothing);
    expect(find.byKey(const Key('inquiry-note')), findsNothing);
  }

  group('ChatScreen, question avant réservation', () {
    testWidgets('demandeur : bandeau, carte, bannière du trajet, sans pièce '
        'jointe', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 4));
      await _pump(tester, bloc, _inquiry);

      expect(quotaBar, findsOneWidget);
      expect(find.text('4 messages restants'), findsOneWidget);
      expect(bookingButton, findsOneWidget);
      expect(find.text('Prêt à réserver ?'), findsOneWidget);
      expect(find.text('Trajet lié'), findsOneWidget);
      expect(find.byKey(const Key('chat-trip-banner')), findsOneWidget);
      expect(composer, findsOneWidget);
      expect(find.byKey(const Key('chat-attach-button')), findsNothing);
    });

    testWidgets('abonnement : plafond, annonce et mode limité transmis', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoading());
      await _pump(tester, bloc, _inquiry);
      final event =
          verify(() => bloc.add(captureAny())).captured.first
              as ChatSubscribeRequested;
      expect(event.inquiryLimited, isTrue);
      expect(event.inquiryMessageLimit, 10);
      expect(event.announcementId, 'ann-9');
      expect(event.conversationKind, ConversationModel.kindInquiry);
    });

    testWidgets('ouverture mesurée avec le type de conversation (I5)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoading());
      await _pump(tester, bloc, _inquiry);
      verify(
        () => analyticsBackend.capture(AnalyticsEvents.conversationOpened, {
          'context': 'conversation',
          'kind': ConversationModel.kindInquiry,
        }),
      ).called(1);
    });

    testWidgets('« Faire une demande » de la carte mesuré, source card (I5)', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 7));
      await _pump(tester, bloc, _inquiry, onNavigate: (_, _) {});
      await tester.tap(bookingButton);
      await tester.pump();
      final events = verify(() => bloc.add(captureAny())).captured;
      expect(
        events.whereType<ChatInquiryBookingTapped>().single.source,
        InquiryBookingSource.card,
      );
    });

    testWidgets('« Faire une demande » du verrou mesuré, source lock (I5)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ChatLoaded([], inquiryRemaining: 0, inquiryLimitReached: true),
      );
      await _pump(tester, bloc, _inquiry, onNavigate: (_, _) {});
      await tester.tap(bookingButton);
      await tester.pump();
      final events = verify(() => bloc.add(captureAny())).captured;
      expect(
        events.whereType<ChatInquiryBookingTapped>().single.source,
        InquiryBookingSource.lock,
      );
    });

    testWidgets('0 restant : verrou à la place du composeur, sans carte', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded(
          [_msg('m1', 'Bonjour')],
          inquiryRemaining: 0,
          inquiryLimitReached: true,
        ),
      );
      await _pump(tester, bloc, _inquiry);

      expect(lockedBar, findsOneWidget);
      expect(composer, findsNothing);
      expect(quotaBar, findsNothing);
      expect(bookingButton, findsOneWidget);
      expect(find.byKey(const Key('inquiry-booking-card')), findsNothing);
    });

    testWidgets('créateur (pas de compteur) : aucun élément de question', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')]));
      await _pump(tester, bloc, _inquiry);

      expectNoInquiryUi();
      expect(composer, findsOneWidget);
    });

    testWidgets('fil levé : plus rien, même avec le modèle périmé', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')]));
      await _pump(tester, bloc, _inquiry.copyWith(mediaAllowed: true));
      expectNoInquiryUi();
    });

    testWidgets('conversation ordinaire : rien', (tester) async {
      when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')]));
      await _pump(tester, bloc, _ordinary);

      expectNoInquiryUi();
    });

    testWidgets('« Faire une demande » ouvre /traveler/<annonce>', (
      tester,
    ) async {
      String? pushed;
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 7));
      await _pump(
        tester,
        bloc,
        _inquiry,
        onNavigate: (path, _) => pushed = path,
      );
      await tester.tap(bookingButton);
      await tester.pump();
      expect(pushed, '/traveler/ann-9');
    });

    testWidgets('bouton du verrou : même navigation', (tester) async {
      String? pushed;
      when(() => bloc.state).thenReturn(
        const ChatLoaded([], inquiryRemaining: 0, inquiryLimitReached: true),
      );
      await _pump(
        tester,
        bloc,
        _inquiry,
        onNavigate: (path, _) => pushed = path,
      );
      await tester.tap(bookingButton);
      await tester.pump();
      expect(pushed, '/traveler/ann-9');
    });

    testWidgets('fil vide du demandeur : note d\'accueil et carte', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const ChatLoaded([], inquiryRemaining: 10));
      await _pump(tester, bloc, _inquiry);

      expect(
        find.text(
          'Vous pouvez envoyer 10 messages avant de réserver. '
          'Texte seul, sans photo.',
        ),
        findsOneWidget,
      );
      expect(bookingButton, findsOneWidget);
      expect(quotaBar, findsOneWidget);
    });

    testWidgets('fil vide ordinaire : état vide habituel, sans note', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc, _ordinary);
      expect(find.text('Démarrez la conversation !'), findsOneWidget);
      expectNoInquiryUi();
    });

    testWidgets('refus au plafond : message de limite', (tester) async {
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable([
          const ChatSendRejected(ChatLoaded([]), inquiryLimit: true),
        ]),
        initialState: const ChatLoaded([], inquiryRemaining: 1),
      );
      await _pump(tester, bloc, _inquiry);
      expect(
        find.text('Limite de messages atteinte. Réservez pour continuer.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('anglais à 360 dp : aucune exception', (tester) async {
      Intl.defaultLocale = 'en';
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Hello')], inquiryRemaining: 2));
      await _pump(tester, bloc, _inquiry, locale: AppL10n.en);
      expect(find.text('Make a request'), findsOneWidget);
      expect(find.text('Linked trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChatScreen, cas limites de la question', () {
    testWidgets(
      'demandeur sans compteur connu : aucune carte, barre ni verrou',
      (tester) async {
        when(() => bloc.state).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')]));
        await _pump(tester, bloc, _inquiry);
        expectNoInquiryUi();
        expect(composer, findsOneWidget);
      },
    );

    testWidgets('fil en sourdine admin : barre de quota masquée', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 4));
      final auth = _MockAuthBloc();
      registerFallbackValue(const AuthProfileRefreshRequested());
      when(() => auth.isClosed).thenReturn(false);
      when(() => auth.state).thenReturn(
        AuthAuthenticated(
          UserModel(
            id: 'me',
            roles: const ['SENDER'],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            messagingMutedUntil: DateTime.now().add(const Duration(days: 2)),
          ),
        ),
      );
      await _pump(tester, bloc, _inquiry, auth: auth);
      expect(find.text('Messagerie suspendue'), findsOneWidget);
      expect(quotaBar, findsNothing);
      expect(composer, findsNothing);
    });

    testWidgets('sans annonce : bandeau non cliquable', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 4));
      await _pump(
        tester,
        bloc,
        const ConversationModel(
          id: 'conv-q',
          firestoreConversationId: 'conv_q',
          otherParticipant: ParticipantModel(id: 'uid-1', name: 'Moussa'),
          kind: ConversationModel.kindInquiry,
          tripOrigin: 'Paris',
          tripDestination: 'Dakar',
        ),
      );
      final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('chat-trip-banner')),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('bouton de réservation avec icône d\'envoi', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ChatLoaded([_msg('m1', 'Bonjour')], inquiryRemaining: 4));
      await _pump(tester, bloc, _inquiry);
      expect(
        find.descendant(of: bookingButton, matching: find.byType(DonyIcon)),
        findsOneWidget,
      );
    });
  });

  group('trackingPathFor / inquiryTripPathFor', () {
    test('question : fiche du trajet, pas de suivi', () {
      expect(inquiryTripPathFor(_inquiry), '/traveler/ann-9');
      expect(inquiryTripPathFor(_ordinary), isNull);
      expect(trackingPathFor(_inquiry), '/messages');
      expect(trackingPathFor(_ordinary), '/bids/bid-1');
    });
  });

  group('ConversationTile', () {
    testWidgets('question sans aperçu : texte localisé', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ConversationTile(conversation: _inquiry)),
        ),
      );
      expect(find.text('Poser une question'), findsOneWidget);
    });
  });
}
