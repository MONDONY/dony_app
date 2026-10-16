import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/data/assistant_repository.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockAssistantRepository extends Mock implements AssistantRepository {}

class MockSupportRepository extends Mock implements SupportRepository {}

const _answer = AssistantAnswer(
  answer: 'Allez dans Moi.',
  answered: true,
  actions: [
    AssistantAction(route: '/profile/edit/phone', label: 'Changer mon numéro'),
  ],
  provider: 'groq',
  remainingToday: 17,
);

const _ticket = SupportTicket(
  id: 't1',
  category: 'OTHER',
  subject: 'Q',
  status: SupportTicketStatuses.newTicket,
);

void main() {
  late MockAssistantRepository repository;
  late MockSupportRepository support;
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUpAll(() => registerFallbackValue(<AssistantHistoryTurn>[]));

  setUp(() async {
    repository = MockAssistantRepository();
    support = MockSupportRepository();
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  AssistantBloc build() => AssistantBloc(repository, support, analytics);

  When<Future<AssistantAnswer>> askAny() => when(
    () => repository.ask(
      question: any(named: 'question'),
      locale: any(named: 'locale'),
      history: any(named: 'history'),
    ),
  );

  void answers(AssistantAnswer a) => askAny().thenAnswer((_) async => a);

  void ticketCreated() => when(
    () => support.createTicket(
      category: any(named: 'category'),
      subject: any(named: 'subject'),
      message: any(named: 'message'),
    ),
  ).thenAnswer((_) async => _ticket);

  blocTest<AssistantBloc, AssistantState>(
    'question puis réponse',
    build: () {
      answers(_answer);
      return build();
    },
    act: (b) => b.add(const AssistantQuestionSubmitted('Où ?', locale: 'fr')),
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.isSending, 'isSending', true)
          .having((s) => s.messages.single.text, 'q', 'Où ?'),
      isA<AssistantState>()
          .having((s) => s.isSending, 'isSending', false)
          .having(
            (s) => s.messages.last.actions.single.route,
            'route',
            '/profile/edit/phone',
          ),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.assistantQuestionAsked, {
          'locale': 'fr',
          'suggestion': false,
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.assistantAnswerReceived, {
          'answered': true,
          'provider': 'groq',
          'actions_count': 1,
        }),
      ).called(1);
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'une question tapée depuis une suggestion le signale',
    build: () {
      answers(_answer);
      return build();
    },
    act: (b) => b.add(
      const AssistantQuestionSubmitted(
        'Où ?',
        locale: 'en',
        fromSuggestion: true,
      ),
    ),
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.assistantQuestionAsked, {
        'locale': 'en',
        'suggestion': true,
      }),
    ).called(1),
  );

  blocTest<AssistantBloc, AssistantState>(
    'envoie l’historique précédent, pas la question courante',
    build: () {
      answers(_answer);
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q1', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantQuestionSubmitted('Q2', locale: 'fr'));
    },
    verify: (_) {
      final calls = verify(
        () => repository.ask(
          question: 'Q2',
          locale: 'fr',
          history: captureAny(named: 'history'),
        ),
      ).captured;
      expect(calls.single, const [
        AssistantHistoryTurn(role: 'user', text: 'Q1'),
        AssistantHistoryTurn(role: 'assistant', text: 'Allez dans Moi.'),
      ]);
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'l’historique envoyé est borné à 12 tours',
    build: () {
      answers(_answer);
      return build();
    },
    seed: () => AssistantState(
      messages: [
        for (var i = 0; i < 20; i++)
          AssistantMessage(
            id: i,
            author: i.isEven ? AssistantAuthor.user : AssistantAuthor.assistant,
            text: 't$i',
          ),
      ],
    ),
    act: (b) =>
        b.add(const AssistantQuestionSubmitted('Nouvelle', locale: 'fr')),
    verify: (_) {
      final history =
          verify(
                () => repository.ask(
                  question: 'Nouvelle',
                  locale: 'fr',
                  history: captureAny(named: 'history'),
                ),
              ).captured.single
              as List<AssistantHistoryTurn>;
      expect(history.length, 12);
      expect(history.first.text, 't8');
      expect(history.last.text, 't19');
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'une seule question en vol',
    build: () {
      askAny().thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _answer;
      });
      return build();
    },
    act: (b) {
      b.add(const AssistantQuestionSubmitted('A', locale: 'fr'));
      b.add(const AssistantQuestionSubmitted('B', locale: 'fr'));
    },
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(
        () => repository.ask(
          question: any(named: 'question'),
          locale: any(named: 'locale'),
          history: any(named: 'history'),
        ),
      ).called(1);
      expect(
        b.state.messages.where((m) => m.author == AssistantAuthor.user),
        hasLength(1),
      );
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'texte vide ignoré',
    build: build,
    act: (b) => b.add(const AssistantQuestionSubmitted('   ', locale: 'fr')),
    expect: () => <AssistantState>[],
  );

  blocTest<AssistantBloc, AssistantState>(
    'assistant désactivé : la question est ignorée',
    build: build,
    seed: () => const AssistantState(disabled: true),
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    expect: () => <AssistantState>[],
    verify: (_) => verifyNever(
      () => repository.ask(
        question: any(named: 'question'),
        locale: any(named: 'locale'),
        history: any(named: 'history'),
      ),
    ),
  );

  blocTest<AssistantBloc, AssistantState>(
    'erreur réseau puis nouvel essai',
    build: () {
      var first = true;
      askAny().thenAnswer((_) async {
        if (first) {
          first = false;
          throw const AssistantNetworkException();
        }
        return _answer;
      });
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantRetryRequested(locale: 'fr'));
    },
    skip: 2,
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.isSending, 'isSending', true)
          .having((s) => s.messages.length, 'erreur retirée', 1),
      isA<AssistantState>()
          .having((s) => s.messages.last.text, 'réponse', 'Allez dans Moi.')
          .having((s) => s.messages.length, 'Q + R', 2)
          .having((s) => s.lastFailedQuestion, 'effacé', isNull),
    ],
    verify: (_) {
      // Le nouvel essai renvoie la même question sans la dupliquer dans l'historique.
      final calls = verify(
        () => repository.ask(
          question: 'Q',
          locale: 'fr',
          history: captureAny(named: 'history'),
        ),
      ).captured;
      expect(calls.last, isEmpty);
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'une erreur réseau ajoute un message d’erreur et garde la question',
    build: () {
      askAny().thenThrow(const AssistantNetworkException());
      return build();
    },
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    skip: 1,
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.isSending, 'isSending', false)
          .having((s) => s.lastFailedQuestion, 'question', 'Q')
          .having((s) => s.messages.last.isError, 'erreur', true),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'une exception inattendue ne bloque pas l’envoi',
    build: () {
      askAny().thenThrow(StateError('inattendu'));
      return build();
    },
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    skip: 1,
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.isSending, 'isSending', false)
          .having((s) => s.lastFailedQuestion, 'question', 'Q')
          .having((s) => s.messages.last.isError, 'erreur', true),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'nouvel essai sans échec précédent : rien',
    build: build,
    act: (b) => b.add(const AssistantRetryRequested(locale: 'fr')),
    expect: () => <AssistantState>[],
  );

  blocTest<AssistantBloc, AssistantState>(
    'quota',
    build: () {
      askAny().thenThrow(const AssistantQuotaExceededException());
      return build();
    },
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    skip: 1,
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.quotaExceeded, 'quota', true)
          .having((s) => s.isSending, 'isSending', false),
    ],
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.assistantQuotaReached, null),
    ).called(1),
  );

  blocTest<AssistantBloc, AssistantState>(
    'désactivé',
    build: () {
      askAny().thenThrow(const AssistantDisabledException());
      return build();
    },
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    skip: 1,
    expect: () => [
      isA<AssistantState>()
          .having((s) => s.disabled, 'disabled', true)
          .having((s) => s.isSending, 'isSending', false),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'nouvelle conversation vide tout',
    build: () {
      answers(_answer);
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantResetRequested());
    },
    skip: 2,
    expect: () => [const AssistantState()],
  );

  blocTest<AssistantBloc, AssistantState>(
    'nouvelle conversation pendant l’envoi : la réponse tardive est écartée',
    build: () {
      askAny().thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _answer;
      });
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q', locale: 'fr'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const AssistantResetRequested());
    },
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [const AssistantState()],
  );

  blocTest<AssistantBloc, AssistantState>(
    'pouce sur une réponse',
    build: () {
      answers(_answer);
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(AssistantFeedbackGiven(b.state.messages.last.id, up: false));
    },
    skip: 2,
    expect: () => [
      isA<AssistantState>().having(
        (s) => s.messages.last.feedback,
        'feedback',
        'down',
      ),
    ],
    verify: (_) => verify(
      () =>
          backend.capture(AnalyticsEvents.assistantFeedback, {'value': 'down'}),
    ).called(1),
  );

  blocTest<AssistantBloc, AssistantState>(
    'pouce vers le haut sur une réponse',
    build: build,
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(id: 3, author: AssistantAuthor.assistant, text: 'R'),
      ],
    ),
    act: (b) => b.add(const AssistantFeedbackGiven(3, up: true)),
    expect: () => [
      isA<AssistantState>().having(
        (s) => s.messages.single.feedback,
        'f',
        'up',
      ),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'pouce sur un message inconnu : ignoré',
    build: build,
    act: (b) => b.add(const AssistantFeedbackGiven(42, up: true)),
    expect: () => <AssistantState>[],
    verify: (_) => verifyNever(
      () => backend.capture(AnalyticsEvents.assistantFeedback, any()),
    ),
  );

  blocTest<AssistantBloc, AssistantState>(
    'passage à un humain',
    build: () {
      answers(_answer);
      ticketCreated();
      return build();
    },
    act: (b) async {
      b.add(const AssistantQuestionSubmitted('Q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantEscalationRequested());
    },
    skip: 2,
    expect: () => [
      isA<AssistantState>().having(
        (s) => s.escalationStatus,
        'sending',
        AssistantEscalationStatus.sending,
      ),
      isA<AssistantState>()
          .having(
            (s) => s.escalationStatus,
            'success',
            AssistantEscalationStatus.success,
          )
          .having((s) => s.escalatedTicketId, 'ticket', 't1'),
    ],
    verify: (_) {
      final captured = verify(
        () => support.createTicket(
          category: 'OTHER',
          subject: 'Q',
          message: captureAny(named: 'message'),
        ),
      ).captured;
      expect(captured.single as String, startsWith('Q\n\n'));
      verify(
        () => backend.capture(AnalyticsEvents.assistantEscalated, null),
      ).called(1);
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'passage à un humain sans question : sujet par défaut',
    build: () {
      ticketCreated();
      return build();
    },
    act: (b) => b.add(const AssistantEscalationRequested()),
    verify: (_) {
      final args = verify(
        () => support.createTicket(
          category: 'OTHER',
          subject: captureAny(named: 'subject'),
          message: captureAny(named: 'message'),
        ),
      ).captured;
      expect(args[0], isNotEmpty);
      expect((args[0] as String).length, lessThanOrEqualTo(200));
      expect(args[1], isNull);
    },
  );

  blocTest<AssistantBloc, AssistantState>(
    'passage à un humain déjà en cours : ignoré',
    build: build,
    seed: () => const AssistantState(
      escalationStatus: AssistantEscalationStatus.sending,
    ),
    act: (b) => b.add(const AssistantEscalationRequested()),
    expect: () => <AssistantState>[],
    verify: (_) => verifyNever(
      () => support.createTicket(
        category: any(named: 'category'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
      ),
    ),
  );

  blocTest<AssistantBloc, AssistantState>(
    'échec du passage à un humain',
    build: () {
      when(
        () => support.createTicket(
          category: any(named: 'category'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
        ),
      ).thenThrow(Exception('boom'));
      return build();
    },
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(id: 1, author: AssistantAuthor.user, text: 'Q'),
      ],
    ),
    act: (b) => b.add(const AssistantEscalationRequested()),
    expect: () => [
      isA<AssistantState>().having(
        (s) => s.escalationStatus,
        's',
        AssistantEscalationStatus.sending,
      ),
      isA<AssistantState>()
          .having(
            (s) => s.escalationStatus,
            'f',
            AssistantEscalationStatus.failure,
          )
          .having((s) => s.messages.length, 'conservé', 1),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'escalade traitée : retour à idle et ticket oublié',
    build: build,
    seed: () => const AssistantState(
      escalationStatus: AssistantEscalationStatus.success,
      escalatedTicketId: 't1',
    ),
    act: (b) => b.add(const AssistantEscalationHandled()),
    expect: () => [const AssistantState()],
  );

  blocTest<AssistantBloc, AssistantState>(
    'ouverture et action',
    build: build,
    act: (b) {
      b.add(const AssistantOpened('bubble'));
      b.add(const AssistantActionTapped('/x', matched: false));
      b.add(const AssistantActionTapped('/y', matched: true));
    },
    expect: () => <AssistantState>[],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.assistantOpened, {
          'source': 'bubble',
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.assistantActionUnmatched, {
          'route': '/x',
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.assistantActionTapped, {
          'route': '/y',
        }),
      ).called(1);
    },
  );

  group('modèles', () {
    test('AssistantState.isEmpty et copyWith effaçables', () {
      const s = AssistantState(escalatedTicketId: 't', lastFailedQuestion: 'q');
      expect(s.isEmpty, isTrue);
      expect(
        s.copyWith(clearEscalatedTicketId: true).escalatedTicketId,
        isNull,
      );
      expect(
        s.copyWith(clearLastFailedQuestion: true).lastFailedQuestion,
        isNull,
      );
      expect(s.copyWith().escalatedTicketId, 't');
      expect(
        s.copyWith(quotaExceeded: true, disabled: true).quotaExceeded,
        isTrue,
      );
    });

    test('AssistantMessage.copyWith conserve les autres champs', () {
      const m = AssistantMessage(
        id: 1,
        author: AssistantAuthor.assistant,
        text: 'R',
        answered: false,
      );
      final c = m.copyWith(feedback: 'up');
      expect(c.feedback, 'up');
      expect(c.answered, isFalse);
      expect(c.text, 'R');
      expect(m.copyWith(), m);
    });

    test('les événements sont comparables', () {
      expect(const AssistantOpened('bubble'), const AssistantOpened('bubble'));
      expect(
        const AssistantQuestionSubmitted('a', locale: 'fr'),
        const AssistantQuestionSubmitted('a', locale: 'fr'),
      );
      expect(
        const AssistantRetryRequested(locale: 'fr'),
        const AssistantRetryRequested(locale: 'fr'),
      );
      expect(const AssistantResetRequested(), const AssistantResetRequested());
      expect(
        const AssistantFeedbackGiven(1, up: true),
        const AssistantFeedbackGiven(1, up: true),
      );
      expect(
        const AssistantActionTapped('/x', matched: true),
        const AssistantActionTapped('/x', matched: true),
      );
      expect(
        const AssistantEscalationRequested(),
        const AssistantEscalationRequested(),
      );
      expect(
        const AssistantEscalationHandled(),
        const AssistantEscalationHandled(),
      );
    });
  });
}
