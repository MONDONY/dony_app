import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_keyboard_scope.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockChatBloc extends MockBloc<ChatEvent, ChatState> implements ChatBloc {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');
const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

MessageModel _makeMsg({
  required String id,
  required String body,
  String senderId = 'uid-1',
  MessageType type = MessageType.text,
}) => MessageModel(
  id: id,
  senderId: senderId,
  body: body,
  type: type,
  sentAt: DateTime(2026, 4, 29, 10),
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

/// Ces tests ouvrent le menu du chat mais ne confirment jamais un blocage :
/// le dépôt n'a donc qu'à exister pour que le BLoC du dialog se construise.
class _StubBlockedUsersRepository implements BlockedUsersRepository {
  @override
  Future<List<BlockedUserModel>> fetchBlockedUsers() async => [];

  @override
  Future<void> blockUser(String blockedUserId) async {}

  @override
  Future<void> unblockUser(String userId) async {}
}

void main() {
  late MockChatBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(
      const ChatTextSendRequested(
        firestoreConversationId: 'x',
        conversationId: 'x',
        senderFirebaseUid: 'x',
        body: 'x',
      ),
    );
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
    // Vrai service (simple StreamController) : les tests de blocage veulent
    // observer le flux réel, pas un mock.
    if (!getIt.isRegistered<BlockEventsService>()) {
      getIt.registerSingleton<BlockEventsService>(BlockEventsService());
    }
    // Le dialog de confirmation de blocage résout son propre BLoC via getIt :
    // sans cet enregistrement, ouvrir « Bloquer » depuis le menu du chat lève.
    if (!getIt.isRegistered<BlockedUsersBloc>()) {
      getIt.registerFactory<BlockedUsersBloc>(
        () => BlockedUsersBloc(
          _StubBlockedUsersRepository(),
          getIt<AnalyticsService>(),
          getIt<BlockEventsService>(),
        ),
      );
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    bloc = MockChatBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => bloc.close());

  group('ChatScreen', () {
    testWidgets('shows skeleton when state is ChatLoading', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoading());
      await _pump(tester, bloc);

      expect(find.byType(DonyChatSkeleton), findsOneWidget);
    });

    testWidgets('shows empty prompt when conversation has no messages', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Démarrez la conversation !'), findsOneWidget);
    });

    testWidgets('renders message bubbles when messages present', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([_makeMsg(id: 'm1', body: 'Bonjour, colis reçu !')]),
      );
      await _pump(tester, bloc);

      expect(find.text('Bonjour, colis reçu !'), findsOneWidget);
    });

    testWidgets('shows participant name in app bar', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Modibo Coulibaly'), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const ChatError(NetworkException('Erreur de connexion')));
      await _pump(tester, bloc);

      expect(find.text('Connexion interrompue'), findsOneWidget);
    });

    testWidgets('footer texte : envoi présent, plus de bouton image/position', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'send'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'image'),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'map-pin'),
        findsNothing,
      );
    });

    // Régression : le champ du chat est multiligne (`maxLines: null`), ce qui
    // déclenche la barre « Terminé » de DonyKeyboardScope. Cette barre est
    // posée en surimpression juste au-dessus du clavier — exactement là où se
    // place le composer — et le recouvrait entièrement.
    testWidgets(
      'clavier ouvert : la barre « Terminé » ne recouvre pas le champ',
      (tester) async {
        when(() => bloc.state).thenReturn(const ChatLoaded([]));

        const screen = Size(390, 844); // iPhone 14
        const keyboard = 336.0; // clavier iOS avec barre de suggestions

        // `tester.view` pilote la vraie surface de rendu. Passer par un
        // MediaQuery injecté ne suffit pas : la surface resterait 800×600 et le
        // Scaffold calculerait sa hauteur sur des contraintes sans rapport.
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = screen;
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            // Comme en production : le scope enveloppe le Navigator racine.
            builder: (context, child) =>
                DonyKeyboardScope(child: child ?? const SizedBox.shrink()),
            home: BlocProvider<ChatBloc>.value(
              value: bloc,
              child: const ChatScreen(conversation: _conversation),
            ),
          ),
        );
        // Le focus pilote l'affichage de la barre.
        await tester.tap(find.byType(TextField));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);

        final doneBar = find.byKey(const Key('donyKeyboardDoneBar'));
        expect(
          doneBar,
          findsOneWidget,
          reason: 'champ multiligne → barre requise',
        );

        // Le champ doit rester au-dessus de la barre, pas dessous.
        final field = tester.getRect(find.byType(TextField));
        expect(field.bottom, lessThanOrEqualTo(tester.getRect(doneBar).top));
      },
    );

    testWidgets('texte valide → ChatTextSendRequested dispatché', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      await tester.enterText(find.byType(TextField), 'Bonjour Kadi');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'send'),
      );
      await tester.pump();

      verify(() => bloc.add(any(that: isA<ChatTextSendRequested>()))).called(1);
    });

    testWidgets('numéro de téléphone → bloqué (aucun envoi + avertissement)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
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
      expect(find.textContaining('garde les échanges'), findsOneWidget);
    });

    testWidgets('le menu ⋯ propose de signaler et de bloquer l interlocuteur', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Signaler Modibo Coulibaly'), findsOneWidget);
      expect(find.text('Bloquer Modibo Coulibaly'), findsOneWidget);
      expect(find.text('Supprimer la conversation'), findsOneWidget);
    });

    testWidgets(
      // I4 : « Bloquer X » depuis le menu ⋯ du chat doit ouvrir directement
      // le dialogue de confirmation (showBlockConfirmDialog), jamais un
      // second menu ⋯ intermédiaire (showBlockMenu) qui redirait le même
      // libellé une deuxième fois.
      'bloquer depuis le menu du chat ouvre directement le dialogue de confirmation',
      (tester) async {
        when(() => bloc.state).thenReturn(const ChatLoaded([]));
        await _pump(tester, bloc);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bloquer Modibo Coulibaly'));
        await tester.pumpAndSettle();

        // Le dialogue de confirmation est là, sans passer par un second menu
        // à une seule entrée qui répéterait « Bloquer Modibo Coulibaly ».
        expect(find.text('Bloquer Modibo ?'), findsOneWidget);
        expect(find.text('Bloquer Modibo Coulibaly'), findsNothing);
      },
    );

    testWidgets('signaler ouvre le formulaire avec la cible utilisateur', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));

      Object? pushedExtra;
      String? pushedPath;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider<ChatBloc>.value(
            value: bloc,
            child: ChatScreen(
              conversation: _conversation,
              onNavigate: (path, extra) {
                pushedPath = path;
                pushedExtra = extra;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler Modibo Coulibaly'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/settings/report-incident');
      expect(pushedExtra, {
        'targetType': IncidentTargetType.user,
        'targetId': 'uid-1',
      });
    });
  });

  // ── Réaction aux blocages ────────────────────────────────────────────────
  group('ChatScreen — blocage de l\'interlocuteur', () {
    /// Monte l'écran et collecte les navigations demandées.
    Future<List<String>> pumpAndCollect(WidgetTester tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      final routes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider<ChatBloc>.value(
            value: bloc,
            child: ChatScreen(
              conversation: _conversation,
              onNavigate: (path, _) => routes.add(path),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return routes;
    }

    testWidgets('bloquer l\'interlocuteur ramène à la liste', (tester) async {
      final routes = await pumpAndCollect(tester);

      getIt<BlockEventsService>().notifyBlocked('uid-1');
      await tester.pump(const Duration(milliseconds: 50));

      expect(routes, ['/messages']);
    });

    testWidgets('un déblocage laisse la conversation ouverte', (tester) async {
      final routes = await pumpAndCollect(tester);

      getIt<BlockEventsService>().notifyUnblocked('uid-1');
      await tester.pump(const Duration(milliseconds: 50));

      expect(routes, isEmpty);
    });

    testWidgets('bloquer quelqu\'un d\'autre ne quitte pas l\'écran', (
      tester,
    ) async {
      final routes = await pumpAndCollect(tester);

      getIt<BlockEventsService>().notifyBlocked('un-autre-uid');
      await tester.pump(const Duration(milliseconds: 50));

      expect(routes, isEmpty);
    });
  });
}
