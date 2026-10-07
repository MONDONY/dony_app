import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/bloc/conversation_notifications/conversation_notifications_cubit.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _FakeConversationListEvent extends Fake
    implements ConversationListEvent {}

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly'),
);

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/conversations/conv-1/mute'),
  response: Response(
    statusCode: code,
    requestOptions: RequestOptions(path: '/conversations/conv-1/mute'),
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late _MockChatBloc chatBloc;
  late _MockConversationListBloc listBloc;
  late _MockConversationRepository repo;
  late AnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(_FakeConversationListEvent());
    analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    if (!getIt.isRegistered<AnalyticsService>()) {
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
    if (!getIt.isRegistered<BlockEventsService>()) {
      getIt.registerSingleton<BlockEventsService>(BlockEventsService());
    }
  });

  tearDownAll(getIt.reset);

  setUp(() {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr';
    addTearDown(() => Intl.defaultLocale = previousLocale);
    chatBloc = _MockChatBloc();
    when(() => chatBloc.state).thenReturn(const ChatLoaded([]));
    listBloc = _MockConversationListBloc();
    when(() => listBloc.state).thenReturn(const ConversationListInitial());
    if (getIt.isRegistered<ConversationListBloc>()) {
      getIt.unregister<ConversationListBloc>();
    }
    getIt.registerSingleton<ConversationListBloc>(listBloc);
    repo = _MockConversationRepository();
  });

  tearDown(() async {
    await chatBloc.close();
    await listBloc.close();
  });

  Future<ConversationNotificationsCubit?> pump(
    WidgetTester tester, {
    bool muted = false,
    bool withCubit = true,
    Locale locale = AppL10n.fr,
  }) async {
    final conversation = _conversation.copyWith(notificationsMuted: muted);
    final cubit = withCubit
        ? ConversationNotificationsCubit(
            repo,
            getIt<AnalyticsService>(),
            conversation: conversation,
          )
        : null;
    if (cubit != null) addTearDown(cubit.close);
    Widget screen = BlocProvider<ChatBloc>.value(
      value: chatBloc,
      child: ChatScreen(conversation: conversation),
    );
    if (cubit != null) {
      screen = BlocProvider<ConversationNotificationsCubit>.value(
        value: cubit,
        child: screen,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return cubit;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  bool syncedWith(Object? e, {required bool muted}) =>
      e is ConversationNotificationsMuteSynced &&
      e.conversationId == 'conv-1' &&
      e.muted == muted;

  testWidgets('fil actif : « Mettre en sourdine », bascule et confirmation', (
    tester,
  ) async {
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenAnswer((_) async {});
    final cubit = await pump(tester);

    await openMenu(tester);
    expect(find.text('Mettre en sourdine'), findsOneWidget);
    expect(find.text('Réactiver les notifications'), findsNothing);

    await tester.tap(find.text('Mettre en sourdine'));
    await tester.pumpAndSettle();

    verify(() => repo.muteConversationNotifications('conv-1')).called(1);
    expect(cubit!.state.muted, isTrue);
    expect(
      find.text('Notifications coupées pour cette conversation'),
      findsOneWidget,
    );
    verify(
      () =>
          listBloc.add(any(that: predicate((e) => syncedWith(e, muted: true)))),
    ).called(greaterThanOrEqualTo(1));

    await openMenu(tester);
    expect(find.text('Réactiver les notifications'), findsOneWidget);
    expect(find.text('Mettre en sourdine'), findsNothing);
  });

  testWidgets('fil en sourdine : « Réactiver les notifications »', (
    tester,
  ) async {
    when(
      () => repo.unmuteConversationNotifications('conv-1'),
    ).thenAnswer((_) async {});
    await pump(tester, muted: true);

    await openMenu(tester);
    await tester.tap(find.text('Réactiver les notifications'));
    await tester.pumpAndSettle();

    verify(() => repo.unmuteConversationNotifications('conv-1')).called(1);
    expect(find.text('Notifications réactivées'), findsOneWidget);
  });

  testWidgets('échec (ancien back, 405) : retour arrière + erreur, pas de '
      'confirmation', (tester) async {
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenThrow(_status(405));
    final cubit = await pump(tester);

    await openMenu(tester);
    await tester.tap(find.text('Mettre en sourdine'));
    await tester.pumpAndSettle();

    expect(cubit!.state.muted, isFalse);
    expect(
      find.text('Notifications coupées pour cette conversation'),
      findsNothing,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    // La liste a suivi l'optimiste puis le retour arrière.
    verify(
      () => listBloc.add(
        any(that: predicate((e) => syncedWith(e, muted: false))),
      ),
    ).called(1);
    expect(tester.takeException(), isNull);

    await openMenu(tester);
    expect(find.text('Mettre en sourdine'), findsOneWidget);
  });

  testWidgets('sans cubit fourni : pas d entrée de sourdine', (tester) async {
    await pump(tester, withCubit: false);
    await openMenu(tester);
    expect(find.byKey(const Key('chat-menu-notifications')), findsNothing);
    expect(find.text('Signaler Modibo Coulibaly'), findsOneWidget);
  });

  testWidgets('libellés anglais', (tester) async {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previous);
    AppL10n.debugEnglishEnabled = true;
    addTearDown(() => AppL10n.debugEnglishEnabled = null);
    await pump(tester, locale: AppL10n.en);
    await openMenu(tester);
    expect(find.text('Mute conversation'), findsOneWidget);
  });

  testWidgets('sans liste enregistrée : la bascule ne plante pas', (
    tester,
  ) async {
    getIt.unregister<ConversationListBloc>();
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenAnswer((_) async {});
    final cubit = await pump(tester);
    unawaited(cubit!.toggle());
    await tester.pumpAndSettle();
    expect(cubit.state.muted, isTrue);
    expect(tester.takeException(), isNull);
  });
}
