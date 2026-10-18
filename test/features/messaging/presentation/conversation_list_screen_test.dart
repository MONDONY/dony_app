import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/bloc/conversation_selection/conversation_selection_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/conversation_list_screen.dart';
import 'package:dony/features/support/bloc/support_summary_cubit.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/features/support/presentation/widgets/support_conversation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/l10n_test_helpers.dart';

class MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _FakeConversationListEvent extends Fake
    implements ConversationListEvent {}

class _MockSupportRepository extends Mock implements SupportRepository {}

class _MockAssistantBloc extends MockBloc<AssistantEvent, AssistantState>
    implements AssistantBloc {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Aïcha Bah');
final _conv = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  lastMessagePreview: 'Bonjour !',
  // `now()` exactement, et non `now() - 5 min` : entre 00 h 00 et 00 h 05 ce
  // décalage bascule le message sur la veille et le fait sortir de la section
  // « AUJOURD'HUI » — le test échouait cinq minutes par jour.
  lastMessageAt: DateTime.now(),
  hasUnread: true,
  unreadCount: 2,
);
final _convNow = ConversationModel(
  id: 'conv-5',
  bidId: 'bid-5',
  firestoreConversationId: 'conv_bid-5',
  otherParticipant: const ParticipantModel(id: 'uid-5', name: 'Kadiatou'),
  lastMessagePreview: 'Maintenant',
  lastMessageAt: DateTime.now(),
);
final _convDaysAgo = ConversationModel(
  id: 'conv-3',
  bidId: 'bid-3',
  firestoreConversationId: 'conv_bid-3',
  otherParticipant: const ParticipantModel(id: 'uid-3', name: 'Fatoumata'),
  lastMessagePreview: 'À demain',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 3)),
);
final _convWeeksAgo = ConversationModel(
  id: 'conv-4',
  bidId: 'bid-4',
  firestoreConversationId: 'conv_bid-4',
  otherParticipant: const ParticipantModel(id: 'uid-4', name: 'Oumar'),
  lastMessagePreview: 'Merci',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 10)),
);

GoRouter _buildRouter(ConversationListBloc bloc) => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => BlocProvider<ConversationListBloc>.value(
        value: bloc,
        child: const ConversationListScreen(),
      ),
    ),
    GoRoute(
      path: '/conversations/:id',
      builder: (_, _) => const Scaffold(body: Text('Chat')),
    ),
    GoRoute(
      path: '/assistant',
      builder: (_, state) => Scaffold(
        body: Text('ecran-assistant-${state.uri.queryParameters['source']}'),
      ),
    ),
    GoRoute(
      path: '/support',
      builder: (_, _) => const Scaffold(body: Text('ecran-support')),
    ),
    GoRoute(
      path: '/messages/archives',
      builder: (_, _) => const Scaffold(body: Text('ecran-archives')),
    ),
    GoRoute(
      path: '/support/tickets/:id',
      builder: (_, state) =>
          Scaffold(body: Text('fil-${state.pathParameters['id']}')),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, ConversationListBloc bloc) async {
  // La tuile Support Yadony épinglée en tête consomme ~70 px. On agrandit la
  // surface de test pour éviter que les états « vide » ou « erreur » ne causent
  // un overflow de rendu (qui ferait échouer le test).
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(bloc),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeConversationListEvent());
    registerFallbackValue(const AssistantOpened('bubble'));
    // ConversationTile formate l'heure du dernier message en français : sans
    // cette initialisation, toute tuile rendue lève LocaleDataException.
    await initializeDateFormatting('fr');
  });

  late MockConversationListBloc bloc;
  late _MockSupportRepository mockSupportRepository;
  late SupportUnreadCubit supportUnreadCubit;
  late SupportSummaryCubit supportSummaryCubit;
  late _MockAssistantBloc assistantBloc;

  setUp(() {
    // L'icône de l'assistant lit `AssistantBloc` (singleton) via `getIt` :
    // visible seulement une fois la sonde `GET /assistant/status` positive.
    assistantBloc = _MockAssistantBloc();
    when(
      () => assistantBloc.state,
    ).thenReturn(const AssistantState(available: true));
    if (getIt.isRegistered<AssistantBloc>()) getIt.unregister<AssistantBloc>();
    getIt.registerSingleton<AssistantBloc>(assistantBloc);
    bloc = MockConversationListBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    // Enregistre SupportUnreadCubit dans GetIt pour que ConversationListScreen
    // puisse l'obtenir via getIt<SupportUnreadCubit>().
    mockSupportRepository = _MockSupportRepository();
    when(
      () => mockSupportRepository.loadUnreadCount(),
    ).thenAnswer((_) async => 0);
    // Par défaut, back antérieur au résumé (404 → null).
    when(
      () => mockSupportRepository.getSummary(),
    ).thenAnswer((_) async => null);
    supportSummaryCubit = SupportSummaryCubit(mockSupportRepository);
    supportUnreadCubit = SupportUnreadCubit(
      mockSupportRepository,
      summaryCubit: supportSummaryCubit,
    );
    if (getIt.isRegistered<SupportUnreadCubit>()) {
      getIt.unregister<SupportUnreadCubit>();
    }
    if (getIt.isRegistered<SupportSummaryCubit>()) {
      getIt.unregister<SupportSummaryCubit>();
    }
    getIt.registerLazySingleton<SupportUnreadCubit>(() => supportUnreadCubit);
    getIt.registerLazySingleton<SupportSummaryCubit>(() => supportSummaryCubit);
    if (getIt.isRegistered<ConversationSelectionCubit>()) {
      getIt.unregister<ConversationSelectionCubit>();
    }
    getIt.registerFactoryParam<
      ConversationSelectionCubit,
      ConversationSelectionSource,
      void
    >((source, _) => ConversationSelectionCubit(source: source));
  });

  tearDown(() async {
    await bloc.close();
    if (getIt.isRegistered<AssistantBloc>()) getIt.unregister<AssistantBloc>();
    if (getIt.isRegistered<ConversationSelectionCubit>()) {
      getIt.unregister<ConversationSelectionCubit>();
    }
    if (getIt.isRegistered<SupportUnreadCubit>()) {
      getIt.unregister<SupportUnreadCubit>();
    }
    if (getIt.isRegistered<SupportSummaryCubit>()) {
      getIt.unregister<SupportSummaryCubit>();
    }
    await supportUnreadCubit.close();
    await supportSummaryCubit.close();
  });

  group('ConversationListScreen · icône assistant', () {
    const icon = Key('messages-header-assistant');

    setUp(() {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
    });

    testWidgets('visible quand la sonde a déclaré l\'assistant disponible', (
      tester,
    ) async {
      await _pump(tester, bloc);

      expect(find.byKey(icon), findsOneWidget);
      expect(find.byTooltip("Ouvrir l'assistant"), findsOneWidget);
    });

    testWidgets('toucher l\'icône ouvre /assistant avec la source', (
      tester,
    ) async {
      await _pump(tester, bloc);

      await tester.tap(find.byKey(icon));
      await tester.pumpAndSettle();

      expect(find.text('ecran-assistant-messages_header'), findsOneWidget);
      // C'est l'écran de l'assistant qui envoie `AssistantOpened` : l'icône
      // ne le double pas.
      verifyNever(() => assistantBloc.add(any()));
    });

    testWidgets('RB10 : absente tant que l\'assistant n\'est pas disponible', (
      tester,
    ) async {
      when(() => assistantBloc.state).thenReturn(const AssistantState());
      await _pump(tester, bloc);

      expect(find.byKey(icon), findsNothing);
    });

    testWidgets('RB10 : absente quand l\'assistant est coupé (disabled)', (
      tester,
    ) async {
      when(
        () => assistantBloc.state,
      ).thenReturn(const AssistantState(available: true, disabled: true));
      await _pump(tester, bloc);

      expect(find.byKey(icon), findsNothing);
    });

    testWidgets(
      'sans AssistantBloc enregistré, l\'icône est absente sans erreur',
      (tester) async {
        getIt.unregister<AssistantBloc>();
        await _pump(tester, bloc);

        expect(tester.takeException(), isNull);
        expect(find.byKey(icon), findsNothing);
      },
    );

    testWidgets('RB10 : apparaît quand la sonde répond, sans recharger', (
      tester,
    ) async {
      whenListen(
        assistantBloc,
        Stream.value(const AssistantState(available: true)),
        initialState: const AssistantState(),
      );
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: _buildRouter(bloc),
        ),
      );
      expect(find.byKey(icon), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(icon), findsOneWidget);
    });
  });

  group('ConversationListScreen', () {
    testWidgets('affiche le header Messages dans tous les états', (
      tester,
    ) async {
      for (final state in [
        const ConversationListLoading() as ConversationListState,
        const ConversationListLoaded([]),
        const ConversationListError(NetworkException('err')),
      ]) {
        when(() => bloc.state).thenReturn(state);
        await _pump(tester, bloc);
        expect(
          find.text('Messages'),
          findsOneWidget,
          reason: 'header manquant pour $state',
        );
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'search bar manquante pour $state',
        );
      }
    });

    testWidgets('shows skeleton when state is Loading', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoading());
      await _pump(tester, bloc);

      expect(find.byType(DonyConversationTileSkeleton), findsWidgets);
    });

    testWidgets('shows empty state when no conversations', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Aucun message'), findsOneWidget);
    });

    testWidgets(
      // « Messages » est identique en anglais : c'est l'état vide qui prouve
      // que l'écran est bien traduit.
      'en anglais : état vide et pastilles de filtre traduits',
      (tester) async {
        useEnglish();
        when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
        await _pump(tester, bloc);

        expect(find.text('No messages'), findsOneWidget);
        expect(find.text('Aucun message'), findsNothing);
        expect(find.text('All'), findsNothing);
        expect(find.text('Unread'), findsNothing);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets('renders conversation tile with participant name', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
      expect(find.text('Bonjour !'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      when(() => bloc.state).thenReturn(
        const ConversationListError(NetworkException('Erreur réseau')),
      );
      await _pump(tester, bloc);

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('retry button dispatches ConversationsLoadRequested', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationListError(NetworkException('Erreur réseau')),
      );
      await _pump(tester, bloc);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(
        () => bloc.add(const ConversationsLoadRequested()),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets("affiche section AUJOURD'HUI pour message récent", (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text("AUJOURD'HUI"), findsOneWidget);
    });

    testWidgets('affiche section CETTE SEMAINE pour message de 3 jours', (
      tester,
    ) async {
      await initializeDateFormatting('fr');
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convDaysAgo]));
      await _pump(tester, bloc);

      expect(find.text('CETTE SEMAINE'), findsOneWidget);
      expect(find.text('Fatoumata'), findsOneWidget);
    });

    testWidgets('affiche section PLUS ANCIEN pour message de 10 jours', (
      tester,
    ) async {
      await initializeDateFormatting('fr');
      when(
        () => bloc.state,
      ).thenReturn(ConversationListLoaded([_convWeeksAgo]));
      await _pump(tester, bloc);

      expect(find.text('PLUS ANCIEN'), findsOneWidget);
      expect(find.text('Oumar'), findsOneWidget);
    });

    testWidgets('affiche pills de filtre quand searchQuery est vide', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      // YADONY-FLUTTER-PROD-W : « Tous » et « Non lus » ont disparu.
      expect(find.text('Tous'), findsNothing);
      expect(find.text('Non lus'), findsNothing);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Terminés'), findsOneWidget);
    });

    testWidgets('« Terminés » touché : dispatch du filtre done', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      await tester.tap(find.byKey(const Key('conversation-filter-done')));
      await tester.pump();

      verify(
        () => bloc.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.done,
            searchQuery: '',
          ),
        ),
      ).called(1);
    });

    group('En cours / Terminés', () {
      ConversationModel conv(
        String id,
        String name, {
        String? bidStatus,
        bool unread = false,
      }) => ConversationModel(
        id: id,
        bidId: 'bid-$id',
        firestoreConversationId: 'conv_$id',
        otherParticipant: ParticipantModel(id: 'u-$id', name: name),
        bidStatus: bidStatus,
        hasUnread: unread,
        unreadCount: unread ? 1 : 0,
        lastMessageAt: DateTime.now(),
      );

      final cancelledRead = conv('a', 'Annulé Lu', bidStatus: 'TRIP_CANCELLED');
      final deliveredUnread = conv(
        'b',
        'Livré Nonlu',
        bidStatus: 'DELIVERY_CONFIRMED',
        unread: true,
      );
      final pending = conv('c', 'Offre Attente');

      testWidgets('par défaut « En cours » : livré non lu et offre en attente '
          'affichés, annulé lu rangé', (tester) async {
        when(() => bloc.state).thenReturn(
          ConversationListLoaded([cancelledRead, deliveredUnread, pending]),
        );
        await _pump(tester, bloc);

        expect(find.text('Livré Nonlu'), findsOneWidget);
        expect(find.text('Offre Attente'), findsOneWidget);
        expect(find.text('Annulé Lu'), findsNothing);
      });

      testWidgets('« Terminés » : annulé lu seulement', (tester) async {
        when(() => bloc.state).thenReturn(
          ConversationListLoaded([
            cancelledRead,
            deliveredUnread,
            pending,
          ], filter: ConversationFilter.done),
        );
        await _pump(tester, bloc);

        expect(find.text('Annulé Lu'), findsOneWidget);
        expect(find.text('Livré Nonlu'), findsNothing);
        expect(find.text('Offre Attente'), findsNothing);
      });

      testWidgets('« En cours » vide alors que tout est terminé : renvoi '
          'vers « Terminés »', (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(ConversationListLoaded([cancelledRead]));
        await _pump(tester, bloc);

        expect(find.byKey(const Key('conversation-empty-active')), findsOne);
        expect(find.text('Aucune conversation en cours'), findsOneWidget);
      });

      testWidgets('« Terminés » vide : texte dédié', (tester) async {
        when(() => bloc.state).thenReturn(
          ConversationListLoaded([pending], filter: ConversationFilter.done),
        );
        await _pump(tester, bloc);

        expect(find.byKey(const Key('conversation-empty-done')), findsOne);
        expect(find.text('Aucune conversation terminée'), findsOneWidget);
      });

      testWidgets('aucune conversation : texte historique', (tester) async {
        when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
        await _pump(tester, bloc);

        expect(find.text('Aucun message'), findsOneWidget);
      });
    });

    testWidgets('taper dans le champ dispatch ConversationFilterChanged', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      await tester.enterText(find.byType(TextField), 'Dakar');
      await tester.pump();

      verify(
        () => bloc.add(
          any(
            that: predicate<ConversationListEvent>(
              (e) =>
                  e is ConversationFilterChanged &&
                  e.searchQuery == 'Dakar' &&
                  e.filter == ConversationFilter.active,
              'is ConversationFilterChanged(filter: active, searchQuery: Dakar)',
            ),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping conversation tile navigates to chat', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.tap(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets(
      'FLUTTER-PF : un rechargement garde la position de défilement',
      (tester) async {
        final many = [
          for (var i = 0; i < 30; i++)
            ConversationModel(
              id: 'conv-$i',
              bidId: 'bid-$i',
              firestoreConversationId: 'conv_bid-$i',
              otherParticipant: ParticipantModel(
                id: 'uid-$i',
                name: 'Personne $i',
              ),
              lastMessagePreview: 'Message $i',
              lastMessageAt: DateTime.now(),
            ),
        ];
        final states = StreamController<ConversationListState>.broadcast();
        addTearDown(states.close);
        when(() => bloc.state).thenReturn(ConversationListLoaded(many));
        when(() => bloc.stream).thenAnswer((_) => states.stream);
        await _pump(tester, bloc);
        await tester.pumpAndSettle();

        final list = find.byKey(
          const PageStorageKey<String>('conversation-list'),
        );
        final listScrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        await tester.drag(list, const Offset(0, -900));
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(listScrollable);
        final offset = scrollable.position.pixels;
        expect(offset, greaterThan(0));

        // Rechargement silencieux au retour d'une conversation : nouvel état
        // Loaded, la liste reste à la même position.
        final reloaded = ConversationListLoaded([...many]);
        when(() => bloc.state).thenReturn(reloaded);
        states.add(reloaded);
        await tester.pumpAndSettle();

        expect(
          tester.state<ScrollableState>(listScrollable).position.pixels,
          offset,
        );
      },
    );

    testWidgets(
      'après retour du chat (pop), recharge la liste pour refléter le '
      'dernier message envoyé/lu',
      (tester) async {
        when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
        await _pump(tester, bloc);
        clearInteractions(bloc);

        await tester.tap(find.text('Aïcha Bah'));
        await tester.pumpAndSettle();
        expect(find.text('Chat'), findsOneWidget);

        Navigator.of(tester.element(find.text('Chat'))).pop();
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(const ConversationsLoadRequested()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets('_formatTime shows maintenant for sub-1-minute message', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convNow]));
      await _pump(tester, bloc);

      expect(find.text('Kadiatou'), findsOneWidget);
      expect(find.text('maintenant'), findsOneWidget);
    });

    testWidgets(
      'en anglais : heure du dernier message et section AUJOURD\'HUI traduites',
      (tester) async {
        useEnglish();
        when(() => bloc.state).thenReturn(ConversationListLoaded([_convNow]));
        await _pump(tester, bloc);

        expect(find.text('Kadiatou'), findsOneWidget);
        expect(find.text('just now'), findsOneWidget);
        expect(find.text('TODAY'), findsOneWidget);
      },
    );

    testWidgets('empty state adapté quand searchQuery non vide', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const ConversationListLoaded([], searchQuery: 'xyz'));
      await _pump(tester, bloc);

      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets(
      'swipe Supprimer + confirmation dispatche ConversationDeleteRequested '
      'même sous un Navigator imbriqué (shell branch)',
      (tester) async {
        when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
        // Reproduit la prod : l'écran vit dans le Navigator imbriqué d'un
        // StatefulShellBranch alors que showDialog pousse sur le root navigator.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => BlocProvider<ConversationListBloc>.value(
                  value: bloc,
                  child: const ConversationListScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.drag(find.text('Aïcha Bah'), const Offset(-300, 0));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();
        expect(find.text('Supprimer la conversation ?'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Supprimer'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verify(
          () => bloc.add(
            any(
              that: predicate<ConversationListEvent>(
                (e) =>
                    e is ConversationDeleteRequested &&
                    e.conversationId == 'conv-1',
                'is ConversationDeleteRequested(conv-1)',
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Annuler dans le dialog ne dispatche pas ConversationDeleteRequested',
      (tester) async {
        when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => BlocProvider<ConversationListBloc>.value(
                  value: bloc,
                  child: const ConversationListScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.drag(find.text('Aïcha Bah'), const Offset(-300, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(
          () => bloc.add(
            any(
              that: predicate<ConversationListEvent>(
                (e) => e is ConversationDeleteRequested,
                'is ConversationDeleteRequested',
              ),
            ),
          ),
        );
      },
    );

    testWidgets('pull-to-refresh dispatches ConversationsLoadRequested', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 100));

      verify(
        () => bloc.add(const ConversationsLoadRequested()),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('affiche la ligne épinglée Support Yadony en tête de liste', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(
        find.byType(SupportConversationTile),
        findsOneWidget,
        reason:
            'La tuile Support Yadony doit toujours être présente en tête, '
            'indépendamment de la liste des conversations.',
      );
      expect(find.text('Support Yadony'), findsOneWidget);
    });

    testWidgets(
      'la ligne Support défile avec les conversations, en tête (FLUTTER-A8)',
      (tester) async {
        final convs = [
          for (var i = 0; i < 20; i++)
            ConversationModel(
              id: 'conv-$i',
              bidId: 'bid-$i',
              firestoreConversationId: 'conv_bid-$i',
              otherParticipant: ParticipantModel(
                id: 'uid-$i',
                name: 'Personne $i',
              ),
              lastMessagePreview: 'Message $i',
              lastMessageAt: DateTime.now(),
            ),
        ];
        when(() => bloc.state).thenReturn(ConversationListLoaded(convs));
        await _pump(tester, bloc);

        final support = find.byType(SupportConversationTile);
        final top = tester.getTopLeft(support).dy;
        // La ligne Support est au-dessus de la première conversation.
        expect(top, lessThan(tester.getTopLeft(find.text('Personne 0')).dy));

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Elle n'est plus figée sous l'en-tête : elle est remontée avec la
        // liste, et reste montée hors écran (pas de rechargement au retour).
        expect(
          tester
              .getTopLeft(
                find.byType(SupportConversationTile, skipOffstage: false),
              )
              .dy,
          lessThan(top),
        );
      },
    );
  });

  testWidgets('la ligne Support montre l aperçu du résumé serveur', (
    tester,
  ) async {
    when(() => mockSupportRepository.getSummary()).thenAnswer(
      (_) async => const SupportSummary(
        unreadCount: 2,
        openTicketCount: 1,
        latestTicket: SupportSummaryTicket(
          id: 'ticket-1',
          subject: 'Colis bloqué',
          lastMessagePreview: 'Votre colis est arrivé',
          lastMessageFromAdmin: true,
          unreadCount: 2,
        ),
      ),
    );
    when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
    await _pump(tester, bloc);

    expect(find.text('Yadony : Votre colis est arrivé'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    verifyNever(() => mockSupportRepository.loadUnreadCount());
  });

  testWidgets('ancien back : la ligne Support garde l invitation', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
    await _pump(tester, bloc);

    expect(find.textContaining('Une question'), findsOneWidget);
    verify(() => mockSupportRepository.loadUnreadCount()).called(1);
  });

  // L ouverture directe du fil (PR #430) privait l utilisateur d une
  // conversation ouverte du bouton « Nouvelle demande » : quel que soit le
  // nombre de conversations, la ligne ouvre l écran Support.
  for (final openCount in [0, 1, 2]) {
    testWidgets(
      'tap sur la ligne Support avec $openCount conversation(s) ouverte(s) : '
      'ouvre l écran Support',
      (tester) async {
        when(() => mockSupportRepository.getSummary()).thenAnswer(
          (_) async => SupportSummary(
            unreadCount: openCount,
            openTicketCount: openCount,
            latestTicket: const SupportSummaryTicket(
              id: 'ticket-1',
              subject: 'Colis bloqué',
              lastMessagePreview: 'Votre colis est arrivé',
              lastMessageFromAdmin: true,
            ),
          ),
        );
        when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
        await _pump(tester, bloc);

        await tester.tap(find.byType(SupportConversationTile));
        await tester.pumpAndSettle();

        expect(find.text('ecran-support'), findsOneWidget);
        expect(find.text('fil-ticket-1'), findsNothing);
      },
    );
  }

  group('sourdine depuis le volet glissant (FLUTTER-CM)', () {
    Future<void> swipeRight(WidgetTester tester) async {
      await tester.drag(find.text('Aïcha Bah'), const Offset(300, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('« Sourdine » envoie la bascule au BLoC', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await swipeRight(tester);
      expect(find.text('Sourdine'), findsOneWidget);
      await tester.tap(find.text('Sourdine'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          any(
            that: predicate<ConversationListEvent>(
              (e) =>
                  e is ConversationNotificationsMuteToggled &&
                  e.conversationId == 'conv-1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('fil en sourdine : « Réactiver » et cloche barrée', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ConversationListLoaded([_conv.copyWith(notificationsMuted: true)]),
      );
      await _pump(tester, bloc);

      expect(find.byKey(const Key('conversation-tile-muted')), findsOneWidget);
      await swipeRight(tester);
      expect(find.text('Réactiver'), findsOneWidget);
    });

    testWidgets('confirmation puis échec : snackbars issues du BLoC', (
      tester,
    ) async {
      final controller = StreamController<ConversationListState>.broadcast();
      addTearDown(controller.close);
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      controller.add(
        ConversationListLoaded([
          _conv.copyWith(notificationsMuted: true),
        ], muteFeedback: const ConversationMuteFeedback(muted: true)),
      );
      await tester.pump();
      expect(
        find.text('Notifications coupées pour cette conversation'),
        findsOneWidget,
      );

      controller.add(
        ConversationListLoaded([
          _conv,
        ], muteFeedback: const ConversationMuteFeedback(muted: false)),
      );
      await tester.pump();
      expect(find.text('Notifications réactivées'), findsOneWidget);

      controller.add(
        ConversationListLoaded(
          [_conv],
          muteFeedback: const ConversationMuteFeedback(
            muted: true,
            error: NetworkException('boom'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SnackBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ligne « Archivées (n) » (FLUTTER-FR)', () {
    testWidgets('en tête de liste avec le nombre, ouvre les archives', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ConversationListLoaded(
          [_conv],
          archivedConversations: [_convDaysAgo, _convWeeksAgo],
        ),
      );
      await _pump(tester, bloc);

      final row = find.byKey(const Key('messages-archived-row'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Archivées')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Archivées (2)'), findsOneWidget);
      // Au-dessus de la ligne Support épinglée, comme dans WhatsApp.
      expect(
        tester.getTopLeft(row).dy,
        lessThan(tester.getTopLeft(find.byType(SupportConversationTile)).dy),
      );
      // L'ancienne icône d'en-tête a disparu au profit de la ligne.
      expect(find.byTooltip('Voir les conversations archivées'), findsNothing);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('ecran-archives'), findsOneWidget);
    });

    testWidgets('visible aussi quand la liste courante est vide', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ConversationListLoaded(const [], archivedConversations: [_convDaysAgo]),
      );
      await _pump(tester, bloc);
      expect(find.byKey(const Key('messages-archived-row')), findsOneWidget);
    });

    testWidgets('masquée sans archive', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);
      expect(find.byKey(const Key('messages-archived-row')), findsNothing);
    });

    testWidgets('masquée pendant une recherche', (tester) async {
      when(() => bloc.state).thenReturn(
        ConversationListLoaded(
          [_conv],
          archivedConversations: [_convDaysAgo],
          searchQuery: 'Aï',
        ),
      );
      await _pump(tester, bloc);
      expect(find.byKey(const Key('messages-archived-row')), findsNothing);
    });

    testWidgets('volet : « Archiver » et « Supprimer » entiers, icônes de 28', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.drag(find.text('Aïcha Bah'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      for (final key in [
        'conversation-swipe-archive',
        'conversation-swipe-delete',
      ]) {
        final action = find.byKey(Key(key));
        expect(action, findsOneWidget);
        final text = tester.widget<Text>(
          find.descendant(of: action, matching: find.byType(Text)),
        );
        expect(text.maxLines, 1);
        final icon = tester.widget<Icon>(
          find.descendant(of: action, matching: find.byType(Icon)),
        );
        expect(icon.size, 28);
      }
      expect(find.text('Archiver'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets(
      'FLUTTER-GN : « Annuler » après archivage, tuile sortie de la liste, '
      'désarchive sans exception',
      (tester) async {
        final states = StreamController<ConversationListState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: ConversationListLoaded([_conv]),
        );
        await _pump(tester, bloc);

        await tester.drag(find.text('Aïcha Bah'), const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('conversation-swipe-archive')));
        await tester.pump();

        // Le serveur confirme : la conversation quitte la liste, la tuile
        // (et le contexte de l'action) est démontée.
        states.add(
          ConversationListLoaded(const [], archivedConversations: [_conv]),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aïcha Bah'), findsNothing);

        await tester.tap(find.text('Annuler'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        verify(
          () => bloc.add(
            any(
              that: isA<ConversationArchiveRequested>().having(
                (e) => e.conversationId,
                'conversationId',
                'conv-1',
              ),
            ),
          ),
        ).called(1);
        verify(
          () => bloc.add(
            any(
              that: isA<ConversationUnarchiveRequested>().having(
                (e) => e.conversationId,
                'conversationId',
                'conv-1',
              ),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('sélection multiple (FLUTTER-M4)', () {
    final delivered = ConversationModel(
      id: 'conv-6',
      bidId: 'bid-6',
      firestoreConversationId: 'conv_bid-6',
      otherParticipant: const ParticipantModel(id: 'uid-6', name: 'Mariam'),
      lastMessageAt: DateTime.now(),
      bidStatus: 'DELIVERY_CONFIRMED',
    );
    final cancelled = ConversationModel(
      id: 'conv-7',
      bidId: 'bid-7',
      firestoreConversationId: 'conv_bid-7',
      otherParticipant: const ParticipantModel(id: 'uid-7', name: 'Ibrahim'),
      lastMessageAt: DateTime.now(),
      parcelStatus: 'CANCELLED',
    );

    Future<void> enterSelection(WidgetTester tester, String name) async {
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'appui long : cases, compteur, en-tête remplacé, fermeture par la croix',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(ConversationListLoaded([_conv, _convDaysAgo]));
        await _pump(tester, bloc);

        await enterSelection(tester, 'Aïcha Bah');

        expect(find.text('1 sélectionnée'), findsOneWidget);
        expect(find.text('Messages'), findsNothing);
        expect(find.byKey(const Key('conversation-select-conv-1')), findsOne);
        expect(find.byKey(const Key('conversation-select-conv-3')), findsOne);

        // En mode sélection, le tap coche au lieu d'ouvrir le chat.
        await tester.tap(find.text('Fatoumata'));
        await tester.pumpAndSettle();
        expect(find.text('2 sélectionnées'), findsOneWidget);
        expect(find.text('Chat'), findsNothing);

        await tester.tap(find.text('Fatoumata'));
        await tester.pumpAndSettle();
        expect(find.text('1 sélectionnée'), findsOneWidget);

        await tester.tap(find.byKey(const Key('conversation-selection-close')));
        await tester.pumpAndSettle();
        expect(find.text('Messages'), findsOneWidget);
        expect(
          find.byKey(const Key('conversation-select-conv-1')),
          findsNothing,
        );
      },
    );

    testWidgets('décocher la dernière conversation referme le mode', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await enterSelection(tester, 'Aïcha Bah');
      await tester.tap(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('conversation-selection-bar')), findsNothing);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('« Archiver » envoie tout le lot et ferme le mode', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ConversationListLoaded([_conv, _convDaysAgo]));
      await _pump(tester, bloc);

      await enterSelection(tester, 'Aïcha Bah');
      await tester.tap(find.text('Fatoumata'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-batch-archive')));
      await tester.pumpAndSettle();

      final event =
          verify(
                () => bloc.add(
                  captureAny(that: isA<ConversationsBatchArchiveRequested>()),
                ),
              ).captured.single
              as ConversationsBatchArchiveRequested;
      expect(event.conversationIds.toSet(), {'conv-1', 'conv-3'});
      expect(find.byKey(const Key('conversation-selection-bar')), findsNothing);
    });

    testWidgets(
      '« Supprimer » : dialogue avec le nombre, rien sans confirmation',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(ConversationListLoaded([_conv, _convDaysAgo]));
        await _pump(tester, bloc);

        await enterSelection(tester, 'Aïcha Bah');
        await tester.tap(find.text('Fatoumata'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('conversation-batch-delete')));
        await tester.pumpAndSettle();
        expect(find.text('Supprimer 2 conversations ?'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('conversation-batch-delete-cancel')),
        );
        await tester.pumpAndSettle();
        verifyNever(
          () => bloc.add(any(that: isA<ConversationsBatchDeleteRequested>())),
        );
        expect(find.text('2 sélectionnées'), findsOneWidget);

        await tester.tap(find.byKey(const Key('conversation-batch-delete')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('conversation-batch-delete-confirm')),
        );
        await tester.pumpAndSettle();

        final event =
            verify(
                  () => bloc.add(
                    captureAny(that: isA<ConversationsBatchDeleteRequested>()),
                  ),
                ).captured.single
                as ConversationsBatchDeleteRequested;
        expect(event.conversationIds.toSet(), {'conv-1', 'conv-3'});
        expect(
          find.byKey(const Key('conversation-selection-bar')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '« Sélectionner les terminées » coche les colis livrés ou annulés',
      (tester) async {
        // Livrés ou annulés et lus : rangés dans « Terminés »
        // (YADONY-FLUTTER-PROD-W).
        when(() => bloc.state).thenReturn(
          ConversationListLoaded([
            _conv,
            delivered,
            cancelled,
          ], filter: ConversationFilter.done),
        );
        await _pump(tester, bloc);

        await enterSelection(tester, 'Mariam');
        await tester.tap(find.byKey(const Key('conversation-select-finished')));
        await tester.pumpAndSettle();

        expect(find.text('2 sélectionnées'), findsOneWidget);
      },
    );

    testWidgets('« Sélectionner les terminées » sans terminée : message', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await enterSelection(tester, 'Aïcha Bah');
      await tester.tap(find.byKey(const Key('conversation-select-finished')));
      await tester.pump();

      expect(
        find.text('Aucune conversation terminée à sélectionner'),
        findsOneWidget,
      );
      expect(find.text('1 sélectionnée'), findsOneWidget);
    });

    testWidgets(
      'retour d\'archivage groupé : snackbar, « Annuler » désarchive le lot',
      (tester) async {
        final states = StreamController<ConversationListState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: ConversationListLoaded([_convDaysAgo]),
        );
        await _pump(tester, bloc);

        states.add(
          ConversationListLoaded(
            [_convDaysAgo],
            archivedConversations: [_conv, _convNow],
            batchFeedback: const ConversationBatchFeedback(
              action: ConversationBatchAction.archive,
              succeededIds: ['conv-1', 'conv-5'],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('2 conversations archivées'), findsOneWidget);

        await tester.tap(find.text('Annuler'));
        await tester.pump();

        final event =
            verify(
                  () => bloc.add(
                    captureAny(
                      that: isA<ConversationsBatchUnarchiveRequested>(),
                    ),
                  ),
                ).captured.single
                as ConversationsBatchUnarchiveRequested;
        expect(event.conversationIds, ['conv-1', 'conv-5']);
        expect(event.isUndo, isTrue);
      },
    );

    testWidgets('échec partiel d\'une suppression : message avec le nombre', (
      tester,
    ) async {
      final states = StreamController<ConversationListState>.broadcast();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: ConversationListLoaded([_conv]),
      );
      await _pump(tester, bloc);

      states.add(
        ConversationListLoaded(
          [_conv],
          batchFeedback: const ConversationBatchFeedback(
            action: ConversationBatchAction.delete,
            succeededIds: ['conv-3'],
            failedCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('1 conversation supprimée'), findsOneWidget);
      expect(
        find.textContaining('1 conversation n\'a pas pu être traitée'),
        findsOneWidget,
      );
    });

    testWidgets('erreur globale d\'une action groupée : snackbar d\'erreur', (
      tester,
    ) async {
      final states = StreamController<ConversationListState>.broadcast();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: ConversationListLoaded([_conv]),
      );
      await _pump(tester, bloc);

      states.add(
        ConversationListLoaded(
          [_conv],
          batchFeedback: const ConversationBatchFeedback(
            action: ConversationBatchAction.archive,
            failedCount: 1,
            error: NetworkException('boom'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'un désarchivage confirmé ou un « Annuler » réussi n\'affichent rien ici',
      (tester) async {
        final states = StreamController<ConversationListState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: ConversationListLoaded([_conv]),
        );
        await _pump(tester, bloc);

        for (final undo in [false, true]) {
          states.add(
            ConversationListLoaded(
              [_conv],
              batchFeedback: ConversationBatchFeedback(
                action: ConversationBatchAction.unarchive,
                succeededIds: const ['conv-1'],
                isUndo: undo,
              ),
            ),
          );
          await tester.pump();
        }

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('anglais : compteur et raccourci traduits', (tester) async {
      useEnglish();
      when(
        () => bloc.state,
      ).thenReturn(ConversationListLoaded([_conv, _convDaysAgo]));
      await _pump(tester, bloc);

      await enterSelection(tester, 'Aïcha Bah');
      await tester.tap(find.text('Fatoumata'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Select finished'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
    });
  });
}
