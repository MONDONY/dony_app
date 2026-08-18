import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_keyboard_scope.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
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
  });
}
