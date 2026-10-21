import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/bloc/assistant_voice_cubit.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_composer.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_message_bubble.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/ai_consent_test_helpers.dart';
import '../../../helpers/ai_form_draft_test_doubles.dart';

class MockAssistantBloc extends MockBloc<AssistantEvent, AssistantState>
    implements AssistantBloc {}

const _answer = AssistantMessage(
  id: 2,
  author: AssistantAuthor.assistant,
  text: 'Allez dans Moi.',
  actions: [
    AssistantAction(route: '/profile/edit/phone', label: 'Changer mon numéro'),
    AssistantAction(route: '/inconnue', label: 'Perdu'),
  ],
);
const _homeAnswer = AssistantMessage(
  id: 4,
  author: AssistantAuthor.assistant,
  text: 'Retournez à l’accueil.',
  actions: [AssistantAction(route: '/home', label: 'Accueil')],
);
const _alertsAnswer = AssistantMessage(
  id: 6,
  author: AssistantAuthor.assistant,
  text: 'Vos alertes prix.',
  actions: [AssistantAction(route: '/flights/alerts', label: 'Mes alertes')],
);
const _question = AssistantMessage(
  id: 1,
  author: AssistantAuthor.user,
  text: 'Où ?',
);

void main() {
  late MockAssistantBloc bloc;
  late GoRouter router;
  late FakeSpeechService speech;

  setUpAll(() {
    registerFallbackValue(const AssistantResetRequested());
  });

  setUp(() {
    useAiConsent();
    bloc = MockAssistantBloc();
    speech = FakeSpeechService();
  });

  Future<void> pumpRaw(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    ThemeData? theme,
    String initialLocation = '/assistant',
  }) async {
    // La vue de test par défaut (800 × 600) est agrandie pour garder visibles
    // les éléments que vérifient les tests. Un test qui choisit sa taille
    // (téléphone) la garde.
    if (tester.view.physicalSize == const Size(2400, 1800)) {
      tester.view.physicalSize = const Size(2400, 3000);
      addTearDown(tester.view.resetPhysicalSize);
    }
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/assistant',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<AssistantBloc>.value(value: bloc),
              BlocProvider<AssistantVoiceCubit>(
                create: (_) => AssistantVoiceCubit(speech),
              ),
            ],
            child: AssistantScreen(
              source: state.uri.queryParameters['source'] ?? 'bubble',
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const Scaffold(body: Text('home')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/profile/edit/phone',
          builder: (_, _) => const Scaffold(body: Text('phone')),
        ),
        // Hors shell, mais redirigée vers un onglet (flag éteint), comme dans
        // l'app.
        GoRoute(
          path: '/flights/alerts',
          redirect: (_, _) async => '/home',
          builder: (_, _) => const Scaffold(body: Text('alerts')),
        ),
        GoRoute(
          path: '/support/tickets/:id',
          builder: (_, state) =>
              Scaffold(body: Text('ticket ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    );
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester,
    AssistantState state, {
    Locale locale = const Locale('fr'),
    ThemeData? theme,
    String initialLocation = '/assistant',
  }) async {
    whenListen(bloc, const Stream<AssistantState>.empty(), initialState: state);
    await pumpRaw(
      tester,
      locale: locale,
      theme: theme,
      initialLocation: initialLocation,
    );
  }

  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('assistant-send')));

  /// Rien de saisi : seul le micro est là, pas de flèche d'envoi.
  void expectMicOnly() {
    expect(find.byKey(const Key('assistant-mic')), findsOneWidget);
    expect(find.byKey(const Key('assistant-send')), findsNothing);
  }

  testWidgets('accueil : mention IA et suggestions', (tester) async {
    await pump(tester, const AssistantState());
    expect(find.text('IA'), findsOneWidget);
    expect(find.textContaining('je peux me tromper'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-suggestion-1')));
    verify(
      () => bloc.add(
        const AssistantQuestionSubmitted(
          'Comment envoyer un colis ?',
          locale: 'fr',
          fromSuggestion: true,
        ),
      ),
    ).called(1);
  });

  testWidgets('les quatre suggestions sont proposées, pas après une question', (
    tester,
  ) async {
    await pump(tester, const AssistantState());
    for (var n = 1; n <= 4; n++) {
      expect(find.byKey(Key('assistant-suggestion-$n')), findsOneWidget);
    }
    await pump(tester, const AssistantState(messages: [_question]));
    expect(find.byKey(const Key('assistant-suggestion-1')), findsNothing);
  });

  testWidgets('ouverture : AssistantOpened avec la source de la route', (
    tester,
  ) async {
    await pump(
      tester,
      const AssistantState(),
      initialLocation: '/assistant?source=messages_header',
    );
    verify(() => bloc.add(const AssistantOpened('messages_header'))).called(1);
  });

  testWidgets('ouverture : source inconnue ramenée à bubble', (tester) async {
    await pump(
      tester,
      const AssistantState(),
      initialLocation: '/assistant?source=<script>',
    );
    verify(() => bloc.add(const AssistantOpened('bubble'))).called(1);
  });

  testWidgets('envoi : micro seul si vide, la flèche apparaît à la saisie', (
    tester,
  ) async {
    await pump(tester, const AssistantState());
    expectMicOnly();
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Où ?');
    await tester.pump();
    expect(find.byKey(const Key('assistant-mic')), findsNothing);
    expect(sendButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pump();
    verify(
      () => bloc.add(const AssistantQuestionSubmitted('Où ?', locale: 'fr')),
    ).called(1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-input')))
          .controller!
          .text,
      isEmpty,
    );
    // Champ vidé par l'envoi : le micro revient à la place de la flèche.
    expectMicOnly();
  });

  testWidgets('envoi : des espaces seuls ne suffisent pas', (tester) async {
    await pump(tester, const AssistantState());
    await tester.enterText(find.byKey(const Key('assistant-input')), '   ');
    await tester.pump();
    expectMicOnly();
  });

  testWidgets('envoi : la touche Envoyer du clavier envoie aussi', (
    tester,
  ) async {
    await pump(tester, const AssistantState());
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '  Bonjour  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    verify(
      () => bloc.add(const AssistantQuestionSubmitted('Bonjour', locale: 'fr')),
    ).called(1);
  });

  testWidgets('envoi bloqué pendant une question en cours', (tester) async {
    await pump(
      tester,
      const AssistantState(messages: [_question], isSending: true),
    );
    expect(find.byKey(const Key('assistant-typing')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Autre');
    await tester.pump();
    // Du texte est saisi, mais l'envoi reste grisé tant que la réponse arrive.
    expect(sendButton(tester).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<AssistantQuestionSubmitted>())));
  });

  testWidgets('envoi : la locale anglaise part avec la question', (
    tester,
  ) async {
    await pump(tester, const AssistantState(), locale: const Locale('en'));
    expect(find.text('Yadony assistant'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Where?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    verify(
      () => bloc.add(const AssistantQuestionSubmitted('Where?', locale: 'en')),
    ).called(1);
  });

  testWidgets('longueur : compteur à partir de 450, plafond à 500', (
    tester,
  ) async {
    await pump(tester, const AssistantState());
    await tester.enterText(find.byKey(const Key('assistant-input')), 'a' * 100);
    await tester.pump();
    expect(find.text('100/500'), findsNothing);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'a' * 460);
    await tester.pump();
    expect(find.text('460/500'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'a' * 600);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('assistant-input')),
    );
    expect(field.controller!.text.length, 500);
  });

  testWidgets('longueur : le plafond compte les unités UTF-16 du back', (
    tester,
  ) async {
    await pump(tester, const AssistantState());
    // 300 emoji = 600 unités UTF-16 : le back refuserait plus de 500.
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '😀' * 300,
    );
    await tester.pump();
    final text = tester
        .widget<TextField>(find.byKey(const Key('assistant-input')))
        .controller!
        .text;
    expect(text.length, lessThanOrEqualTo(500));
    expect(text.runes.length, text.length ~/ 2, reason: 'aucun emoji coupé');
  });

  testWidgets(
    'action connue ouvre l’écran, action inconnue masquée et signalée',
    (tester) async {
      await pump(tester, const AssistantState(messages: [_question, _answer]));
      expect(find.textContaining('Perdu'), findsNothing);
      expect(find.text('Y aller : Changer mon numéro'), findsOneWidget);
      verify(
        () =>
            bloc.add(const AssistantActionTapped('/inconnue', matched: false)),
      ).called(1);
      await tester.tap(
        find.byKey(const Key('assistant-action-/profile/edit/phone')),
      );
      await tester.pumpAndSettle();
      expect(find.text('phone'), findsOneWidget);
      verify(
        () => bloc.add(
          const AssistantActionTapped('/profile/edit/phone', matched: true),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'action inconnue : un seul signalement malgré les reconstructions',
    (tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: const AssistantState(messages: [_question, _answer]),
      );
      await pumpRaw(tester);
      controller.add(
        AssistantState(
          messages: [
            _question,
            _answer.copyWith(feedback: 'up'),
          ],
        ),
      );
      await tester.pump();
      controller.add(
        AssistantState(
          messages: [
            _question,
            _answer.copyWith(feedback: 'down'),
          ],
        ),
      );
      await tester.pump();
      verify(
        () =>
            bloc.add(const AssistantActionTapped('/inconnue', matched: false)),
      ).called(1);
    },
  );

  testWidgets(
    'action avec segment dynamique et requête : affichée et ouverte',
    (tester) async {
      await pump(
        tester,
        const AssistantState(
          messages: [
            _question,
            AssistantMessage(
              id: 2,
              author: AssistantAuthor.assistant,
              text: 'Voici.',
              actions: [
                AssistantAction(
                  route: '/support/tickets/t9?from=bot',
                  label: 'Mon ticket',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(
        find.byKey(const Key('assistant-action-/support/tickets/t9?from=bot')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ticket t9'), findsOneWidget);
      verifyNever(
        () => bloc.add(
          any(
            that: predicate<AssistantEvent>(
              (e) => e is AssistantActionTapped && !e.matched,
            ),
          ),
        ),
      );
    },
  );

  testWidgets('pouces et parler à un humain', (tester) async {
    await pump(tester, const AssistantState(messages: [_question, _answer]));
    await tester.tap(find.byKey(const Key('assistant-thumb-down-2')));
    verify(
      () => bloc.add(const AssistantFeedbackGiven(2, up: false)),
    ).called(1);
    await tester.tap(find.byKey(const Key('assistant-thumb-up-2')));
    verify(() => bloc.add(const AssistantFeedbackGiven(2, up: true))).called(1);
    await tester.tap(find.byKey(const Key('assistant-human-2')));
    verify(() => bloc.add(const AssistantEscalationRequested())).called(1);
  });

  testWidgets('le pouce choisi est rempli', (tester) async {
    await pump(
      tester,
      AssistantState(
        messages: [
          _question,
          _answer.copyWith(feedback: 'up'),
        ],
      ),
    );
    final up = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('assistant-thumb-up-2')),
        matching: find.byType(IconButton),
      ),
    );
    final down = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('assistant-thumb-down-2')),
        matching: find.byType(IconButton),
      ),
    );
    expect((up.icon as Icon).icon, Icons.thumb_up_alt_rounded);
    expect((down.icon as Icon).icon, Icons.thumb_down_alt_outlined);
    expect(up.tooltip, 'Réponse utile');
    expect(down.tooltip, 'Réponse pas utile');
  });

  testWidgets('cibles tactiles d’au moins 44 px', (tester) async {
    await pump(tester, const AssistantState(messages: [_question, _answer]));
    for (final key in const [
      'assistant-thumb-up-2',
      'assistant-thumb-down-2',
      'assistant-human-2',
      'assistant-mic',
      'assistant-menu',
      'assistant-action-/profile/edit/phone',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(44), reason: key);
      expect(size.width, greaterThanOrEqualTo(44), reason: key);
    }
  });

  testWidgets('answered=false affiche la carte Écrire à l’équipe', (
    tester,
  ) async {
    await pump(
      tester,
      const AssistantState(
        messages: [
          _question,
          AssistantMessage(
            id: 2,
            author: AssistantAuthor.assistant,
            text: 'Je ne peux pas vérifier.',
            answered: false,
          ),
        ],
      ),
    );
    expect(find.byKey(const Key('assistant-escalation-card')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('assistant-escalate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-escalate')));
    verify(() => bloc.add(const AssistantEscalationRequested())).called(1);
  });

  testWidgets('réponse normale : pas de carte', (tester) async {
    await pump(tester, const AssistantState(messages: [_question, _answer]));
    expect(find.byKey(const Key('assistant-escalation-card')), findsNothing);
  });

  testWidgets('escalade en cours : bouton désactivé avec indicateur', (
    tester,
  ) async {
    await pump(
      tester,
      const AssistantState(
        messages: [
          _question,
          AssistantMessage(
            id: 2,
            author: AssistantAuthor.assistant,
            text: 'Je ne sais pas.',
            answered: false,
          ),
        ],
        escalationStatus: AssistantEscalationStatus.sending,
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('assistant-escalate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-escalate')));
    verifyNever(() => bloc.add(const AssistantEscalationRequested()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('erreur et réessayer', (tester) async {
    await pump(
      tester,
      const AssistantState(
        messages: [
          _question,
          AssistantMessage(
            id: 2,
            author: AssistantAuthor.assistant,
            text: '',
            isError: true,
          ),
        ],
        lastFailedQuestion: 'Où ?',
      ),
    );
    expect(find.textContaining('Je n\'ai pas pu répondre'), findsOneWidget);
    expect(find.byKey(const Key('assistant-thumb-up-2')), findsNothing);
    await tester.tap(find.byKey(const Key('assistant-retry')));
    verify(
      () => bloc.add(const AssistantRetryRequested(locale: 'fr')),
    ).called(1);
  });

  testWidgets('quota', (tester) async {
    await pump(
      tester,
      const AssistantState(messages: [_question], quotaExceeded: true),
    );
    expect(find.textContaining('beaucoup de questions'), findsOneWidget);
    expect(find.byKey(const Key('assistant-escalation-card')), findsOneWidget);
    // « Nouvelle conversation » reste le seul moyen de lever le quota.
    expect(find.byKey(const Key('assistant-menu')), findsOneWidget);
    expect(find.byKey(const Key('assistant-input')), findsOneWidget);
  });

  testWidgets('indisponible : pas de champ de saisie, carte vers l’équipe', (
    tester,
  ) async {
    await pump(tester, const AssistantState(disabled: true));
    expect(find.byKey(const Key('assistant-input')), findsNothing);
    expect(find.byKey(const Key('assistant-send')), findsNothing);
    expect(find.byKey(const Key('assistant-suggestion-1')), findsNothing);
    expect(find.textContaining('pas disponible'), findsOneWidget);
    expect(find.byKey(const Key('assistant-escalation-card')), findsOneWidget);
  });

  testWidgets('ticket créé : ouvre la conversation support', (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        const AssistantState(
          messages: [_question],
          escalationStatus: AssistantEscalationStatus.success,
          escalatedTicketId: 't1',
        ),
      ]),
      initialState: const AssistantState(messages: [_question]),
    );
    await pumpRaw(tester);
    await tester.pumpAndSettle();
    expect(find.text('ticket t1'), findsOneWidget);
    verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
  });

  testWidgets('ticket créé pendant que l’écran était fermé : ouvert au '
      'retour, une seule fois', (tester) async {
    await pump(
      tester,
      const AssistantState(
        messages: [_question],
        escalationStatus: AssistantEscalationStatus.success,
        escalatedTicketId: 't1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ticket t1'), findsOneWidget);
    verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(find.text('ticket t1'), findsNothing);
  });

  testWidgets('échec d’escalade survenu écran fermé : acquitté au retour', (
    tester,
  ) async {
    await pump(
      tester,
      const AssistantState(
        messages: [_question],
        escalationStatus: AssistantEscalationStatus.failure,
      ),
    );
    await tester.pumpAndSettle();
    verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
  });

  group('deux écrans de l’assistant empilés', () {
    const unknownAnswer = AssistantMessage(
      id: 8,
      author: AssistantAuthor.assistant,
      text: 'Ailleurs.',
      actions: [AssistantAction(route: '/autre-inconnue', label: 'Ailleurs')],
    );

    /// Empile deux écrans de l'assistant ; rend de quoi émettre un état.
    Future<void Function(AssistantState)> stacked(WidgetTester tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: const AssistantState(messages: [_question]),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      unawaited(router.push('/profile/edit/phone'));
      await tester.pumpAndSettle();
      unawaited(router.push('/assistant'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AssistantScreen, skipOffstage: false),
        findsNWidgets(2),
      );
      clearInteractions(bloc);
      return controller.add;
    }

    testWidgets('escalade réussie : le ticket s’ouvre une seule fois', (
      tester,
    ) async {
      final emit = await stacked(tester);
      emit(
        const AssistantState(
          messages: [_question],
          escalationStatus: AssistantEscalationStatus.success,
          escalatedTicketId: 't1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ticket t1'), findsOneWidget);
      verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ticket t1'), findsNothing);
      expect(find.byType(AssistantScreen), findsOneWidget);
    });

    testWidgets('action inconnue : signalée une seule fois', (tester) async {
      final emit = await stacked(tester);
      emit(const AssistantState(messages: [_question, unknownAnswer]));
      await tester.pumpAndSettle();
      verify(
        () => bloc.add(
          const AssistantActionTapped('/autre-inconnue', matched: false),
        ),
      ).called(1);
    });

    testWidgets('écran unique recouvert par une autre page : le ticket '
        's’ouvre quand même', (tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: const AssistantState(messages: [_question]),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      unawaited(router.push('/profile/edit/phone'));
      await tester.pumpAndSettle();
      controller.add(
        const AssistantState(
          messages: [_question],
          escalationStatus: AssistantEscalationStatus.success,
          escalatedTicketId: 't1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ticket t1'), findsOneWidget);
      verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
    });
  });

  testWidgets('échec de l’escalade : message d’erreur', (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        const AssistantState(
          messages: [_question],
          escalationStatus: AssistantEscalationStatus.failure,
        ),
      ]),
      initialState: const AssistantState(messages: [_question]),
    );
    await pumpRaw(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('n\'est pas parti'), findsOneWidget);
    verify(() => bloc.add(const AssistantEscalationHandled())).called(1);
  });

  testWidgets('nouvelle conversation', (tester) async {
    await pump(tester, const AssistantState(messages: [_question, _answer]));
    await tester.tap(find.byKey(const Key('assistant-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-reset')));
    verify(() => bloc.add(const AssistantResetRequested())).called(1);
  });

  testWidgets('thème sombre : s’affiche sans erreur', (tester) async {
    await pump(
      tester,
      const AssistantState(messages: [_question, _answer], isSending: true),
      theme: AppTheme.dark(),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('assistant-typing')), findsOneWidget);
  });

  testWidgets('nouveau message : défile vers le bas', (tester) async {
    final controller = StreamController<AssistantState>();
    addTearDown(controller.close);
    final many = [
      for (var i = 0; i < 12; i++)
        AssistantMessage(
          id: i * 2,
          author: AssistantAuthor.user,
          text: 'Question numéro $i',
        ),
    ];
    whenListen(
      bloc,
      controller.stream,
      initialState: AssistantState(messages: many),
    );
    await pumpRaw(tester);
    await tester.pumpAndSettle();
    const last = AssistantMessage(
      id: 99,
      author: AssistantAuthor.assistant,
      text: 'Dernière réponse',
    );
    controller.add(AssistantState(messages: [...many, last]));
    await tester.pumpAndSettle();
    expect(find.text('Dernière réponse'), findsOneWidget);
    final bottom = tester.getBottomLeft(find.text('Dernière réponse')).dy;
    final composer = tester
        .getTopLeft(find.byKey(const Key('assistant-input')))
        .dy;
    expect(bottom, lessThanOrEqualTo(composer));
  });

  testWidgets('petit écran et texte agrandi : aucun débordement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      const AssistantState(
        messages: [_question, _answer],
        quotaExceeded: true,
        isSending: true,
      ),
    );
    await tester.enterText(find.byKey(const Key('assistant-input')), 'a' * 470);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'racine d’onglet : go, jamais push (le shell ne se duplique pas)',
    (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, _homeAnswer]),
      );
      await tester.tap(find.byKey(const Key('assistant-action-/home')));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(router.canPop(), isFalse);
      verify(
        () => bloc.add(const AssistantActionTapped('/home', matched: true)),
      ).called(1);
    },
  );

  testWidgets(
    'route hors shell redirigée vers un onglet : go, jamais push (le shell '
    'ne se duplique pas)',
    (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, _alertsAnswer]),
      );
      await tester.tap(
        find.byKey(const Key('assistant-action-/flights/alerts')),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(router.canPop(), isFalse);
    },
  );

  testWidgets('route hors shell : push, le retour ramène à l’assistant', (
    tester,
  ) async {
    await pump(tester, const AssistantState(messages: [_question, _answer]));
    await tester.tap(
      find.byKey(const Key('assistant-action-/profile/edit/phone')),
    );
    await tester.pumpAndSettle();
    expect(find.text('phone'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(find.text('phone'), findsNothing);
  });

  group('Utf16LengthLimiter', () {
    const limiter = Utf16LengthLimiter(kAssistantQuestionMax);
    TextEditingValue format(String text, [int? cursor]) =>
        limiter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor ?? text.length),
          ),
        );

    test('coupe avant une paire de substitution tronquée', () {
      // 'a' + 300 emoji : l'unité 499 serait un substitut haut sans sa moitié.
      final out = format('a${'😀' * 300}');
      expect(out.text.length, 499);
      final last = out.text.codeUnitAt(out.text.length - 1);
      expect(
        last >= 0xD800 && last <= 0xDBFF,
        isFalse,
        reason: 'substitut seul',
      );
      expect(out.text.runes.length, 1 + 249);
    });

    test('coupe pile à 500 quand la frontière est propre', () {
      final out = format('😀' * 300);
      expect(out.text.length, 500);
      expect(out.text.runes.length, 250);
    });

    test('texte court : renvoyé tel quel', () {
      expect(format('bonjour').text, 'bonjour');
    });

    test('collage au milieu : le curseur reste après le texte collé', () {
      final pasted = '${'x' * 200}${'p' * 100}${'x' * 250}';
      final out = format(pasted, 300);
      expect(out.text.length, 500);
      expect(out.text, '${'x' * 200}${'p' * 100}${'x' * 200}');
      expect(out.selection, const TextSelection.collapsed(offset: 300));
    });

    test('curseur au-delà de la coupe : ramené à la fin', () {
      final out = format('a' * 600, 600);
      expect(out.selection, const TextSelection.collapsed(offset: 500));
    });
  });

  testWidgets(
    '50 messages de hauteurs variées : la réponse reçue est visible',
    (tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      final many = [
        for (var i = 0; i < 50; i++)
          AssistantMessage(
            id: i * 2,
            author: i.isEven ? AssistantAuthor.user : AssistantAuthor.assistant,
            text: 'Message $i ${'mot ' * ((i * 7) % 45)}',
          ),
      ];
      whenListen(
        bloc,
        controller.stream,
        initialState: AssistantState(messages: many),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      // Remonté tout en haut : le bas du contenu n'est plus construit, son
      // étendue n'est qu'estimée quand la réponse arrive.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final answer = AssistantMessage(
        id: 200,
        author: AssistantAuthor.assistant,
        text: 'Réponse finale ${'très longue ' * 700}',
      );
      controller.add(AssistantState(messages: [...many, answer]));
      await tester.pumpAndSettle();
      // La réponse se lit depuis son premier mot : son haut est calé en haut
      // de la zone de conversation, pas son bas collé à la saisie.
      final list = tester.getRect(find.byType(Scrollable).first);
      final top = tester.getTopLeft(find.textContaining('Réponse finale')).dy;
      expect(top, greaterThanOrEqualTo(list.top));
      expect(top, lessThan(list.top + 60));
    },
  );

  testWidgets(
    'geste pendant le défilement vers la réponse : pas ramené au bas',
    (tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      final many = [
        for (var i = 0; i < 50; i++)
          AssistantMessage(
            id: i * 2,
            author: i.isEven ? AssistantAuthor.user : AssistantAuthor.assistant,
            text: 'Message $i ${'mot ' * ((i * 7) % 45)}',
          ),
      ];
      whenListen(
        bloc,
        controller.stream,
        initialState: AssistantState(messages: many),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      final answer = AssistantMessage(
        id: 200,
        author: AssistantAuthor.assistant,
        text: 'Réponse finale ${'très longue ' * 40}',
      );
      controller.add(AssistantState(messages: [...many, answer]));
      // Au milieu de l'animation vers le bas, l'utilisateur remonte la liste.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, lessThan(position.maxScrollExtent - 200));
    },
  );

  testWidgets(
    'entrée jouée une fois : pas rejouée au retour dans la zone visible',
    (tester) async {
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      final many = [
        for (var i = 0; i < 40; i++)
          AssistantMessage(
            id: i * 2,
            author: AssistantAuthor.user,
            text: 'Message $i ${'mot ' * 12}',
          ),
      ];
      whenListen(
        bloc,
        controller.stream,
        initialState: AssistantState(messages: many),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      const fresh = AssistantMessage(
        id: 300,
        author: AssistantAuthor.assistant,
        text: 'Réponse fraîche',
      );
      controller.add(AssistantState(messages: [...many, fresh]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Fondu en cours : le nouveau message est bien animé.
      expect(
        find.ancestor(
          of: find.text('Réponse fraîche'),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.text('Réponse fraîche'),
        findsNothing,
        reason: 'sorti de la liste',
      );
      // L'étendue d'une liste paresseuse n'est qu'estimée : elle se corrige
      // une fois la fin construite, d'où un second saut.
      for (var i = 0; i < 3; i++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
      }
      expect(find.text('Réponse fraîche'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Réponse fraîche'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'l’entrée ne se rejoue pas',
      );
    },
  );

  testWidgets('pouces annoncés comme boutons, le choisi « sélectionné »', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AssistantState(
        messages: [
          _question,
          _answer.copyWith(feedback: 'up'),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('assistant-thumb-up-2'))),
      matchesSemantics(
        label: 'Réponse utile',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('assistant-thumb-down-2'))),
      matchesSemantics(
        label: 'Réponse pas utile',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'seule une réponse arrivée pendant la session est une zone vivante',
    (tester) async {
      final handle = tester.ensureSemantics();
      final controller = StreamController<AssistantState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: const AssistantState(messages: [_question, _answer]),
      );
      await pumpRaw(tester);
      bool isLive(String text) => tester
          .getSemantics(find.text(text))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion;
      expect(
        isLive('Allez dans Moi.'),
        isFalse,
        reason: 'historique à l’ouverture',
      );
      controller.add(
        const AssistantState(
          messages: [
            _question,
            _answer,
            AssistantMessage(
              id: 9,
              author: AssistantAuthor.assistant,
              text: 'Nouvelle réponse',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(isLive('Nouvelle réponse'), isTrue);
      expect(isLive('Allez dans Moi.'), isFalse);
      handle.dispose();
    },
  );

  testWidgets('AssistantOpened une seule fois malgré les reconstructions', (
    tester,
  ) async {
    final controller = StreamController<AssistantState>();
    addTearDown(controller.close);
    whenListen(bloc, controller.stream, initialState: const AssistantState());
    await pumpRaw(tester);
    controller.add(const AssistantState(messages: [_question]));
    await tester.pump();
    controller.add(const AssistantState(messages: [_question, _answer]));
    await tester.pump();
    controller.add(
      const AssistantState(messages: [_question, _answer], isSending: true),
    );
    await tester.pump();
    verify(() => bloc.add(const AssistantOpened('bubble'))).called(1);
  });

  testWidgets('thème sombre : bulles aux couleurs du thème', (tester) async {
    final dark = AppTheme.dark();
    await pump(
      tester,
      const AssistantState(messages: [_question, _answer]),
      theme: dark,
    );
    Color? bubbleColor(String text) {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
            .first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(bubbleColor('Où ?'), dark.colorScheme.primary);
    expect(bubbleColor('Allez dans Moi.'), dark.colorScheme.surface);
    expect(
      tester.widget<Text>(find.text('Où ?')).style!.color,
      dark.colorScheme.onPrimary,
    );
  });
  group('clavier (FLUTTER-QT)', () {
    final long = [
      for (var i = 0; i < 30; i++)
        AssistantMessage(
          id: i * 2,
          author: i.isEven ? AssistantAuthor.user : AssistantAuthor.assistant,
          text: 'Message $i ${'mot ' * ((i * 5) % 30)}',
        ),
    ];
    const lastText = 'Dernier message';
    final messages = [
      ...long,
      const AssistantMessage(
        id: 100,
        author: AssistantAuthor.assistant,
        text: lastText,
      ),
    ];

    ScrollPosition position(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    double composerTop(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('assistant-input'))).dy;

    double lastBottom(WidgetTester tester) =>
        tester.getBottomLeft(find.text(lastText)).dy;

    /// Hauteur du clavier en pixels logiques, appliquée comme iOS le fait :
    /// une valeur nouvelle à chaque image de l'animation.
    Future<void> setKeyboard(WidgetTester tester, double logical) async {
      tester.view.viewInsets = FakeViewPadding(
        bottom: logical * tester.view.devicePixelRatio,
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    Future<void> animateKeyboard(
      WidgetTester tester, {
      required double from,
      required double to,
      void Function()? onFrame,
    }) async {
      const steps = 8;
      for (var i = 1; i <= steps; i++) {
        await setKeyboard(tester, from + (to - from) * i / steps);
        onFrame?.call();
      }
    }

    Future<void> pumpLong(WidgetTester tester) async {
      addTearDown(tester.view.reset);
      whenListen(
        bloc,
        const Stream<AssistantState>.empty(),
        initialState: AssistantState(messages: messages),
      );
      await pumpRaw(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-input')));
      await tester.pump();
    }

    testWidgets(
      'ouverture au bas de la liste : le dernier message reste visible à '
      'chaque image',
      (tester) async {
        await pumpLong(tester);
        final p = position(tester);
        expect(p.pixels, closeTo(p.maxScrollExtent, 1));
        await animateKeyboard(
          tester,
          from: 0,
          to: 300,
          onFrame: () {
            expect(p.pixels, closeTo(p.maxScrollExtent, 1));
            expect(lastBottom(tester), lessThanOrEqualTo(composerTop(tester)));
          },
        );
        await tester.pumpAndSettle();
        expect(p.pixels, closeTo(p.maxScrollExtent, 1));
        expect(find.text(lastText), findsOneWidget);
        expect(lastBottom(tester), lessThanOrEqualTo(composerTop(tester)));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets('utilisateur remonté pour lire : pas ramené au bas', (
      tester,
    ) async {
      await pumpLong(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      final p = position(tester);
      final before = p.pixels;
      expect(before, lessThan(p.maxScrollExtent - 200));
      await animateKeyboard(tester, from: 0, to: 300);
      await tester.pumpAndSettle();
      expect(p.pixels, closeTo(before, 0.5));
    });

    testWidgets(
      'fermeture au bas : pas de saut, le dernier message reste collé au '
      'composeur',
      (tester) async {
        await pumpLong(tester);
        await animateKeyboard(tester, from: 0, to: 300);
        await tester.pumpAndSettle();
        final p = position(tester);
        final gap = composerTop(tester) - lastBottom(tester);
        await animateKeyboard(
          tester,
          from: 300,
          to: 0,
          onFrame: () {
            // Jamais au-delà du bas (pas de rebond à rattraper) et l'écart
            // au composeur ne bouge pas.
            expect(p.pixels, lessThanOrEqualTo(p.maxScrollExtent + 0.5));
            expect(p.pixels, closeTo(p.maxScrollExtent, 1));
            expect(composerTop(tester) - lastBottom(tester), closeTo(gap, 1));
          },
        );
        await tester.pumpAndSettle();
        expect(composerTop(tester) - lastBottom(tester), closeTo(gap, 1));
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets('fermeture après être remonté : la position ne bouge pas', (
      tester,
    ) async {
      await pumpLong(tester);
      await animateKeyboard(tester, from: 0, to: 300);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      final p = position(tester);
      final before = p.pixels;
      await animateKeyboard(tester, from: 300, to: 0);
      await tester.pumpAndSettle();
      expect(p.pixels, closeTo(before, 0.5));
    });

    testWidgets('accueil sans message : le clavier s’ouvre sans erreur', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await pump(tester, const AssistantState());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-input')));
      await animateKeyboard(tester, from: 0, to: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('assistant-input')), findsOneWidget);
    });
  });

  group('colis proposés', () {
    const parcel = AssistantParcelChoice(
      parcelId: 'b1',
      status: 'IN_TRANSIT',
      role: 'SENDER',
      active: true,
      trackingNumber: 'DON-7K3M9QXA',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
    );
    const noNumber = AssistantParcelChoice(
      parcelId: 'b2',
      status: 'ACCEPTED',
      role: 'TRAVELER',
      active: true,
      departureCity: 'Lyon',
      arrivalCity: 'Bamako',
    );
    const choose = AssistantMessage(
      id: 2,
      author: AssistantAuthor.assistant,
      text: 'Choisissez le colis concerné.',
      parcels: [parcel, noNumber],
    );

    setUpAll(() {
      registerFallbackValue(
        const AssistantParcelChosen(
          parcel,
          label: '',
          position: 0,
          locale: 'fr',
        ),
      );
    });

    testWidgets('chaque colis montre son numéro ou son trajet, son étape et '
        'son rôle', (tester) async {
      await pump(tester, const AssistantState(messages: [_question, choose]));
      expect(find.text('DON-7K3M9QXA'), findsOneWidget);
      expect(
        find.text('Paris → Dakar · En transit · Votre envoi'),
        findsOneWidget,
      );
      expect(find.text('Lyon → Bamako'), findsOneWidget);
      expect(find.text('À remettre · Vous le transportez'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('assistant-parcel-b1'))).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('toucher un colis le transmet au BLoC', (tester) async {
      await pump(tester, const AssistantState(messages: [_question, choose]));
      await tester.tap(find.byKey(const Key('assistant-parcel-b2')));
      await tester.pump();
      verify(
        () => bloc.add(
          const AssistantParcelChosen(
            noNumber,
            label: 'Lyon → Bamako',
            position: 1,
            locale: 'fr',
          ),
        ),
      ).called(1);
      await tester.tap(find.byKey(const Key('assistant-parcel-b1')));
      await tester.pump();
      verify(
        () => bloc.add(
          const AssistantParcelChosen(
            parcel,
            label: 'DON-7K3M9QXA · Paris → Dakar',
            position: 0,
            locale: 'fr',
          ),
        ),
      ).called(1);
    });

    testWidgets('masqués sur une réponse plus ancienne et pendant un envoi', (
      tester,
    ) async {
      await pump(
        tester,
        const AssistantState(
          messages: [
            _question,
            choose,
            AssistantMessage(
              id: 3,
              author: AssistantAuthor.user,
              text: 'autre chose',
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('assistant-parcel-b1')), findsNothing);
      await pump(
        tester,
        const AssistantState(messages: [_question, choose], isSending: true),
      );
      expect(find.byKey(const Key('assistant-parcel-b1')), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, choose]),
        locale: const Locale('en'),
      );
      expect(
        find.text('Paris → Dakar · In transit · Your shipment'),
        findsOneWidget,
      );
      expect(find.text('Drop-off due · You carry it'), findsOneWidget);
    });

    testWidgets('« Où est mon colis ? » fait partie des suggestions', (
      tester,
    ) async {
      await pump(tester, const AssistantState());
      await tester.scrollUntilVisible(
        find.byKey(const Key('assistant-suggestion-5')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('assistant-suggestion-5')), findsOneWidget);
      expect(find.text('Où est mon colis ?'), findsOneWidget);
    });

    test('libellés de toutes les étapes, rien pour une étape inconnue', () {
      final l = lookupAppLocalizations(const Locale('fr'));
      for (final status in [
        'AWAITING_PAYMENT',
        'PENDING',
        'PAYMENT_ESCROWED',
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
        'COMPLETED',
        'CANCELLED',
        'REJECTED',
        'PARCEL_REFUSED',
        'NO_SHOW',
        'EXPIRED',
      ]) {
        expect(
          assistantParcelStatusLabel(l, status),
          isNotNull,
          reason: status,
        );
      }
      expect(assistantParcelStatusLabel(l, 'NEGOTIATING'), isNull);
    });

    testWidgets('colis sans numéro ni trajet : titre générique', (
      tester,
    ) async {
      const bare = AssistantParcelChoice(
        parcelId: 'b3',
        status: 'UNKNOWN',
        role: 'OTHER',
        active: false,
      );
      await pump(
        tester,
        const AssistantState(
          messages: [
            _question,
            AssistantMessage(
              id: 2,
              author: AssistantAuthor.assistant,
              text: 'Choisissez.',
              parcels: [bare],
            ),
          ],
        ),
      );
      expect(find.text('Colis'), findsOneWidget);
    });
  });

  group('approche de la limite', () {
    const reply = AssistantMessage(
      id: 2,
      author: AssistantAuthor.assistant,
      text: 'Allez dans Moi.',
    );

    testWidgets('aucun décompte loin de la limite', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, reply], remainingToday: 17),
      );
      expect(find.byKey(const Key('assistant-quota-warning')), findsNothing);
      expect(find.textContaining('17'), findsNothing);
    });

    testWidgets('prévenu dès qu’il reste 2 questions', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, reply], remainingToday: 2),
      );
      expect(
        find.text(
          'Il vous reste 2 questions aujourd’hui. Ensuite, l’équipe peut '
                  'prendre le relais.'
              .replaceAll('’', "'"),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dernière question utilisée, en anglais', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, reply], remainingToday: 0),
        locale: const Locale('en'),
      );
      expect(
        find.text(
          'That was your last question for today. Try again tomorrow, or '
          'write to the team.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pas d’avertissement pendant un envoi ni une fois bloqué', (
      tester,
    ) async {
      await pump(
        tester,
        const AssistantState(
          messages: [_question, reply],
          remainingToday: 1,
          isSending: true,
        ),
      );
      expect(find.byKey(const Key('assistant-quota-warning')), findsNothing);
      await pump(
        tester,
        const AssistantState(
          messages: [_question, reply],
          remainingToday: 0,
          quotaExceeded: true,
        ),
      );
      expect(find.byKey(const Key('assistant-quota-warning')), findsNothing);
    });
  });

  group('explication de l’écran', () {
    const intro = AssistantMessage(
      id: 2,
      author: AssistantAuthor.assistant,
      text: 'Vous êtes sur Mes colis.',
      suggestions: ['Comment annuler un envoi ?', 'Où est mon colis ?'],
      screen: '/envois',
    );

    testWidgets('ses questions s’affichent et s’envoient d’un toucher', (
      tester,
    ) async {
      await pump(tester, const AssistantState(messages: [intro]));
      expect(find.text('Vous êtes sur Mes colis.'), findsOneWidget);
      expect(
        find.byKey(const Key('assistant-screen-question-2')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('assistant-screen-question-1')));
      await tester.pump();
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Comment annuler un envoi ?',
            locale: 'fr',
            fromSuggestion: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('masquées pendant un envoi et sous une réponse plus ancienne', (
      tester,
    ) async {
      await pump(
        tester,
        const AssistantState(messages: [intro], isSending: true),
      );
      expect(
        find.byKey(const Key('assistant-screen-question-1')),
        findsNothing,
      );
      await pump(tester, const AssistantState(messages: [intro, _question]));
      expect(
        find.byKey(const Key('assistant-screen-question-1')),
        findsNothing,
      );
    });
  });

  group('accord IA (Apple 5.1.2(i))', () {
    testWidgets('refus : aucune ouverture envoyée au bloc', (tester) async {
      useAiConsent(granted: false);
      await pump(tester, const AssistantState());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-consent-accept')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-consent-decline')));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<AssistantOpened>())));
    });

    testWidgets('accord : l’assistant s’ouvre normalement', (tester) async {
      useAiConsent(granted: false);
      await pump(tester, const AssistantState());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ai-consent-accept')));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const AssistantOpened('bubble'))).called(1);
    });
  });

  // FLUTTER-RE : micro dans la barre de saisie, à droite du champ.
  group('micro', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('dans la barre de saisie : à droite du champ, 48 pt, aucune '
        'bande au-dessus', (tester) async {
      await phone(tester);
      await pump(tester, const AssistantState(messages: [_question, _answer]));
      final mic = find.byKey(const Key('assistant-mic'));
      expect(mic, findsOneWidget);
      final micRect = tester.getRect(mic);
      final input = tester.getRect(find.byKey(const Key('assistant-input')));
      expect(micRect.width, greaterThanOrEqualTo(48));
      expect(micRect.height, greaterThanOrEqualTo(48));
      // Même rangée que le champ, à sa droite.
      expect(micRect.left, greaterThanOrEqualTo(input.right));
      expect(micRect.center.dy, closeTo(input.center.dy, 24));
      // Plus de légende ni de gros disque.
      expect(find.text('Touchez pour parler'), findsNothing);
      expect(find.byKey(const Key('assistant-mic-disc')), findsNothing);
      expect(find.byKey(const Key('assistant-send')), findsNothing);
    });

    testWidgets('toucher : la dictée démarre en français ; le texte reconnu '
        's’affiche puis part comme une question', (tester) async {
      await phone(tester);
      await pump(tester, const AssistantState(messages: [_question, _answer]));
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      expect(speech.startCount, 1);
      expect(speech.lastLocaleId, 'fr_FR');
      await tester.pump();
      expect(find.text('Je vous écoute… Touchez pour envoyer'), findsOneWidget);
      speech.emit('Où est mon colis');
      await tester.pump();
      expect(find.text('Où est mon colis'), findsOneWidget);
      speech.emit('Où est mon colis ?', isFinal: true);
      await tester.pump();
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Où est mon colis ?',
            locale: 'fr',
            fromVoice: true,
          ),
        ),
      ).called(1);
      final field = tester.widget<TextField>(
        find.byKey(const Key('assistant-input')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('pendant l’écoute, un toucher arrête et envoie', (
      tester,
    ) async {
      await phone(tester);
      await pump(tester, const AssistantState());
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      await tester.pump();
      speech.emit('Combien ça coûte');
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      expect(speech.stopCount, 1);
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Combien ça coûte',
            locale: 'fr',
            fromVoice: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('envoyer pendant l’écoute (touche Envoyer du clavier) : la '
        'dictée s’annule, le champ reste vide après le résultat final, une '
        'seule question part (YADONY-FLUTTER-PROD-X)', (tester) async {
      await phone(tester);
      await pump(tester, const AssistantState(messages: [_question, _answer]));
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      await tester.pump();
      speech.emit('Comment payer');
      await tester.pump();
      expect(find.text('Comment payer'), findsOneWidget);
      await tester.showKeyboard(find.byKey(const Key('assistant-input')));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(speech.cancelCount, 1);
      // Le moteur de reconnaissance livre encore son résultat final.
      speech
        ..emit('Comment payer ?', isFinal: true)
        ..finish();
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('assistant-input')),
      );
      expect(field.controller!.text, isEmpty);
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted('Comment payer', locale: 'fr'),
        ),
      ).called(1);
      verifyNever(() => bloc.add(any(that: isA<AssistantQuestionSubmitted>())));
    });

    testWidgets('puce touchée pendant l’écoute : dictée annulée, champ vidé', (
      tester,
    ) async {
      await phone(tester);
      await pump(tester, const AssistantState());
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      await tester.pump();
      speech.emit('Bonjour');
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('assistant-suggestion-1')),
      );
      await tester.tap(find.byKey(const Key('assistant-suggestion-1')));
      await tester.pump();
      speech.emit('Bonjour Yadony', isFinal: true);
      await tester.pump();
      expect(speech.cancelCount, 1);
      final field = tester.widget<TextField>(
        find.byKey(const Key('assistant-input')),
      );
      expect(field.controller!.text, isEmpty);
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Comment envoyer un colis ?',
            locale: 'fr',
            fromSuggestion: true,
          ),
        ),
      ).called(1);
      verifyNever(() => bloc.add(any(that: isA<AssistantQuestionSubmitted>())));
    });

    testWidgets(
      'même question dictée après un envoi : elle repart (garde-fou remis à zéro)',
      (tester) async {
        await phone(tester);
        await pump(
          tester,
          const AssistantState(messages: [_question, _answer]),
        );
        await tester.enterText(
          find.byKey(const Key('assistant-input')),
          'Où est mon colis ?',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-send')));
        await tester.pump();
        verify(
          () => bloc.add(
            const AssistantQuestionSubmitted(
              'Où est mon colis ?',
              locale: 'fr',
            ),
          ),
        ).called(1);
        // Nouvelle dictée : le garde-fou est remis à zéro, la même question
        // dictée volontairement repart.
        await tester.tap(find.byKey(const Key('assistant-mic')));
        await tester.pump();
        await tester.pump();
        speech.emit('Où est mon colis ?', isFinal: true);
        await tester.pump();
        verify(
          () => bloc.add(
            const AssistantQuestionSubmitted(
              'Où est mon colis ?',
              locale: 'fr',
              fromVoice: true,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('puce touchée : le champ saisi est vidé', (tester) async {
      await pump(tester, const AssistantState());
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        'brouillon',
      );
      await tester.tap(find.byKey(const Key('assistant-suggestion-1')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('assistant-input')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('anglais : dictée en en_US', (tester) async {
      await phone(tester);
      await pump(tester, const AssistantState(), locale: const Locale('en'));
      expect(find.byKey(const Key('assistant-mic')), findsOneWidget);
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      expect(speech.lastLocaleId, 'en_US');
    });

    testWidgets('réponse en route : micro grisé, aucun démarrage', (
      tester,
    ) async {
      await phone(tester);
      await pump(
        tester,
        const AssistantState(messages: [_question], isSending: true),
      );
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      expect(speech.startCount, 0);
    });

    testWidgets('micro refusé : message à la place du bouton', (tester) async {
      await phone(tester);
      speech.available = false;
      await pump(tester, const AssistantState());
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('assistant-mic')), findsNothing);
      expect(
        find.text('Micro indisponible : écrivez votre question.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'clavier ouvert : le micro reste dans la barre, à côté du champ',
      (tester) async {
        await phone(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
        await pump(
          tester,
          const AssistantState(messages: [_question, _answer]),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('assistant-mic')), findsOneWidget);
        expect(find.byKey(const Key('assistant-input')), findsOneWidget);
      },
    );

    testWidgets('animations réduites : le micro s’affiche et écoute', (
      tester,
    ) async {
      await phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, const AssistantState());
      await tester.tap(find.byKey(const Key('assistant-mic')));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });
  });

  // FLUTTER-RD : 2 questions de suite + 1 découverte sous la dernière réponse.
  group('questions proposées', () {
    const suggested = AssistantMessage(
      id: 2,
      author: AssistantAuthor.assistant,
      text: 'Payez par carte ou en espèces.',
      nextQuestions: [
        AssistantSuggestion(
          text: 'Comment être remboursé ?',
          kind: AssistantSuggestionKind.followUp,
        ),
        AssistantSuggestion(
          text: 'Puis-je payer en mobile money ?',
          kind: AssistantSuggestionKind.followUp,
        ),
        AssistantSuggestion(
          text: 'Que sont les alertes de trajet ?',
          kind: AssistantSuggestionKind.discovery,
        ),
      ],
    );

    testWidgets('puces sous la dernière réponse, découverte distincte', (
      tester,
    ) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, suggested]),
      );
      expect(find.text('Vous pourriez aussi demander'), findsOneWidget);
      expect(find.byKey(const Key('assistant-follow-up-1')), findsOneWidget);
      expect(find.byKey(const Key('assistant-follow-up-2')), findsOneWidget);
      expect(find.byKey(const Key('assistant-discovery')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('assistant-discovery')),
          matching: find.byKey(const Key('assistant-discovery-icon')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('assistant-follow-up-1')),
          matching: find.byIcon(Icons.explore_rounded),
        ),
        findsNothing,
      );
      final answerBottom = tester.getRect(find.text(suggested.text)).bottom;
      expect(
        tester.getRect(find.byKey(const Key('assistant-follow-up-1'))).top,
        greaterThan(answerBottom),
      );
      expect(
        tester.getSize(find.byKey(const Key('assistant-discovery'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        find.bySemanticsLabel(
          'À découvrir dans Yadony : Que sont les alertes de trajet ?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('toucher une puce envoie sa question', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, suggested]),
      );
      await tester.tap(find.byKey(const Key('assistant-follow-up-2')));
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Puis-je payer en mobile money ?',
            locale: 'fr',
            fromSuggestion: true,
            suggestionKind: AssistantSuggestionKind.followUp,
          ),
        ),
      ).called(1);
      await tester.ensureVisible(find.byKey(const Key('assistant-discovery')));
      await tester.tap(find.byKey(const Key('assistant-discovery')));
      verify(
        () => bloc.add(
          const AssistantQuestionSubmitted(
            'Que sont les alertes de trajet ?',
            locale: 'fr',
            fromSuggestion: true,
            suggestionKind: AssistantSuggestionKind.discovery,
          ),
        ),
      ).called(1);
    });

    testWidgets('masquées sur une ancienne réponse et pendant le chargement', (
      tester,
    ) async {
      await pump(
        tester,
        const AssistantState(
          messages: [
            _question,
            suggested,
            AssistantMessage(id: 3, author: AssistantAuthor.user, text: 'Ok'),
            AssistantMessage(
              id: 4,
              author: AssistantAuthor.assistant,
              text: 'Autre réponse.',
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('assistant-follow-up-1')), findsNothing);
      expect(find.byKey(const Key('assistant-discovery')), findsNothing);
      expect(find.text('Vous pourriez aussi demander'), findsNothing);

      await pump(
        tester,
        const AssistantState(messages: [_question, suggested], isSending: true),
      );
      expect(find.byKey(const Key('assistant-follow-up-1')), findsNothing);
      expect(find.byKey(const Key('assistant-discovery')), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      await pump(
        tester,
        const AssistantState(messages: [_question, suggested]),
        locale: const Locale('en'),
      );
      expect(find.text('You could also ask'), findsOneWidget);
    });
  });
}
