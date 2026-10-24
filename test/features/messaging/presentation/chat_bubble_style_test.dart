import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
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
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Awa Diallo'),
);

MessageModel _msg(
  String id,
  String senderId,
  String body, {
  DateTime? sentAt,
  DateTime? readAt,
}) => MessageModel(
  id: id,
  senderId: senderId,
  body: body,
  type: MessageType.text,
  sentAt: sentAt ?? DateTime(2025, 10, 6, 14, 5),
  readAt: readAt,
);

void main() {
  late _MockChatBloc bloc;

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
    bloc = _MockChatBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });
  tearDown(() => bloc.close());

  Future<ThemeData> pump(
    WidgetTester tester,
    List<MessageModel> messages, {
    ThemeData? theme,
  }) async {
    when(() => bloc.state).thenReturn(ChatLoaded(messages));
    final t = theme ?? AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: t,
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const ChatScreen(
            conversation: _conversation,
            currentUidOverride: 'me',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return t;
  }

  Finder shellWith(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byType(DonyChatBubbleShell),
  );

  BoxDecoration decorationOf(WidgetTester tester, Finder shell) {
    final container = find.descendant(
      of: shell,
      matching: find.byKey(const Key('chat-bubble-shell')),
    );
    return tester.widget<Container>(container).decoration! as BoxDecoration;
  }

  testWidgets('ma bulle : couleur primaire, avec heure dans la bulle', (
    tester,
  ) async {
    final t = await pump(tester, [_msg('m1', 'me', 'Je passe demain')]);
    final shell = shellWith('Je passe demain');
    expect(shell, findsOneWidget);
    expect(decorationOf(tester, shell).color, t.colorScheme.primary);
    expect(
      find.descendant(of: shell, matching: find.text('14:05')),
      findsOneWidget,
    );
  });

  testWidgets('bulle de l’autre : surface avec contour, sans ombre', (
    tester,
  ) async {
    final t = await pump(tester, [_msg('m1', 'uid-1', 'Bonjour')]);
    final d = decorationOf(tester, shellWith('Bonjour'));
    expect(d.color, t.colorScheme.surface);
    expect(d.border, Border.all(color: t.colorScheme.outlineVariant));
    expect(d.boxShadow, isNull);
  });

  testWidgets('séparateur de date partagé entre deux jours', (tester) async {
    await pump(tester, [
      _msg('m1', 'uid-1', 'Hier', sentAt: DateTime(2025, 10, 5, 9)),
      _msg('m2', 'me', 'Aujourd’hui', sentAt: DateTime(2025, 10, 6, 9)),
    ]);
    expect(find.byType(DonyChatDateSeparator), findsNWidgets(2));
    expect(find.text('5 octobre 2025'), findsOneWidget);
    expect(find.text('6 octobre 2025'), findsOneWidget);
  });

  testWidgets('thème sombre : les deux bulles se rendent sans exception', (
    tester,
  ) async {
    await pump(tester, [
      _msg('m1', 'uid-1', 'Bonjour'),
      _msg('m2', 'me', 'Salut'),
    ], theme: AppTheme.dark());
    expect(tester.takeException(), isNull);
    expect(shellWith('Bonjour'), findsOneWidget);
    expect(shellWith('Salut'), findsOneWidget);
  });
}
