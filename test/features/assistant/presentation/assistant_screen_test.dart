import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_composer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

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
const _question = AssistantMessage(
  id: 1,
  author: AssistantAuthor.user,
  text: 'Où ?',
);

void main() {
  late MockAssistantBloc bloc;
  late GoRouter router;

  setUpAll(() {
    registerFallbackValue(const AssistantResetRequested());
  });

  setUp(() {
    bloc = MockAssistantBloc();
  });

  Future<void> pumpRaw(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    ThemeData? theme,
    String initialLocation = '/assistant',
  }) async {
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/assistant',
          builder: (context, state) => BlocProvider<AssistantBloc>.value(
            value: bloc,
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

  testWidgets('envoi : bouton désactivé si vide, puis envoie', (tester) async {
    await pump(tester, const AssistantState());
    expect(sendButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Où ?');
    await tester.pump();
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
    expect(sendButton(tester).onPressed, isNull);
  });

  testWidgets('envoi : des espaces seuls ne suffisent pas', (tester) async {
    await pump(tester, const AssistantState());
    await tester.enterText(find.byKey(const Key('assistant-input')), '   ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);
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
      'assistant-send',
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
        text: 'Réponse finale ${'très longue ' * 40}',
      );
      controller.add(AssistantState(messages: [...many, answer]));
      await tester.pumpAndSettle();
      final composerTop = tester
          .getTopLeft(find.byKey(const Key('assistant-input')))
          .dy;
      final bottom = tester
          .getBottomLeft(find.textContaining('Réponse finale'))
          .dy;
      expect(bottom, lessThanOrEqualTo(composerTop));
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
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
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
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
}
