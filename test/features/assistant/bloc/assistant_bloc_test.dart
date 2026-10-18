import 'dart:async';

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
          'voice': false,
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.assistantAnswerReceived, {
          'answered': true,
          'provider': 'groq',
          'actions_count': 1,
          'suggestions_count': 0,
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
        'voice': false,
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
    // La limite est par jour : le nombre restant survit à la conversation.
    expect: () => [const AssistantState(remainingToday: 17)],
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
    'retoucher le même pouce : ni nouvel état ni nouvel événement',
    build: build,
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(
          id: 3,
          author: AssistantAuthor.assistant,
          text: 'R',
          feedback: 'up',
        ),
      ],
    ),
    act: (b) => b.add(const AssistantFeedbackGiven(3, up: true)),
    expect: () => <AssistantState>[],
    verify: (_) => verifyNever(
      () => backend.capture(AnalyticsEvents.assistantFeedback, any()),
    ),
  );

  blocTest<AssistantBloc, AssistantState>(
    'changer d’avis (haut puis bas) : nouvel événement',
    build: build,
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(
          id: 3,
          author: AssistantAuthor.assistant,
          text: 'R',
          feedback: 'up',
        ),
      ],
    ),
    act: (b) => b.add(const AssistantFeedbackGiven(3, up: false)),
    verify: (b) {
      expect(b.state.messages.single.feedback, 'down');
      verify(
        () => backend.capture(AnalyticsEvents.assistantFeedback, {
          'value': 'down',
        }),
      ).called(1);
    },
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

  blocTest<AssistantBloc, AssistantState>(
    'une réponse réussie remet le quota à false',
    build: () {
      answers(_answer);
      return build();
    },
    seed: () => const AssistantState(quotaExceeded: true),
    act: (b) => b.add(const AssistantQuestionSubmitted('Q', locale: 'fr')),
    skip: 1,
    expect: () => [
      isA<AssistantState>().having((s) => s.quotaExceeded, 'quota', false),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'reset pendant l’escalade : le ticket créé reste signalé',
    build: () {
      when(
        () => support.createTicket(
          category: any(named: 'category'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _ticket;
      });
      return build();
    },
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(id: 1, author: AssistantAuthor.user, text: 'Q'),
      ],
    ),
    act: (b) async {
      b.add(const AssistantEscalationRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const AssistantResetRequested());
    },
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [
      const AssistantState(),
      isA<AssistantState>()
          .having(
            (s) => s.escalationStatus,
            'success',
            AssistantEscalationStatus.success,
          )
          .having((s) => s.escalatedTicketId, 'ticket', 't1')
          .having((s) => s.messages, 'vide', isEmpty),
    ],
  );

  blocTest<AssistantBloc, AssistantState>(
    'reset pendant l’escalade : un échec tardif est ignoré',
    build: () {
      when(
        () => support.createTicket(
          category: any(named: 'category'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        throw Exception('boom');
      });
      return build();
    },
    seed: () => const AssistantState(
      messages: [
        AssistantMessage(id: 1, author: AssistantAuthor.user, text: 'Q'),
      ],
    ),
    act: (b) async {
      b.add(const AssistantEscalationRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const AssistantResetRequested());
    },
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [const AssistantState()],
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

  group('sonde de disponibilité', () {
    test('par défaut la bulle n’est pas disponible', () {
      expect(build().state.available, isFalse);
    });

    blocTest<AssistantBloc, AssistantState>(
      'la sonde qui répond vrai rend l’assistant disponible',
      build: () {
        when(() => repository.status()).thenAnswer((_) async => true);
        return build();
      },
      act: (b) => b.add(const AssistantStatusRequested()),
      expect: () => [
        isA<AssistantState>().having((s) => s.available, 'available', true),
      ],
    );

    blocTest<AssistantBloc, AssistantState>(
      'la sonde qui répond faux (403, 404, éteint) laisse indisponible',
      build: () {
        when(() => repository.status()).thenAnswer((_) async => false);
        return build();
      },
      act: (b) => b.add(const AssistantStatusRequested()),
      verify: (b) => expect(b.state.available, isFalse),
    );

    blocTest<AssistantBloc, AssistantState>(
      'une sonde qui lève est traitée comme indisponible',
      build: () {
        when(() => repository.status()).thenThrow(StateError('boum'));
        return build();
      },
      act: (b) => b.add(const AssistantStatusRequested()),
      verify: (b) => expect(b.state.available, isFalse),
    );

    blocTest<AssistantBloc, AssistantState>(
      'un 404 sur une question repasse indisponible',
      build: () {
        askAny().thenThrow(const AssistantDisabledException());
        return build();
      },
      seed: () => const AssistantState(available: true),
      act: (b) => b.add(const AssistantQuestionSubmitted('Où ?', locale: 'fr')),
      verify: (b) {
        expect(b.state.disabled, isTrue);
        expect(b.state.available, isFalse);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'nouvelle conversation : « éteint » est gardé, la conversation vidée',
      build: build,
      seed: () => const AssistantState(
        disabled: true,
        messages: [
          AssistantMessage(id: 1, author: AssistantAuthor.user, text: 'Q'),
        ],
      ),
      act: (b) => b.add(const AssistantResetRequested()),
      verify: (b) {
        expect(b.state.disabled, isTrue);
        expect(b.state.available, isFalse);
        expect(b.state.messages, isEmpty);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'nouvelle conversation : la disponibilité est gardée',
      build: build,
      seed: () => const AssistantState(available: true),
      act: (b) => b.add(const AssistantResetRequested()),
      verify: (b) => expect(b.state.available, isTrue),
    );

    test('une sonde est ignorée tant qu’une autre est en vol', () async {
      final gate = Completer<bool>();
      when(() => repository.status()).thenAnswer((_) => gate.future);
      final b = build();
      b.add(const AssistantStatusRequested());
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      gate.complete(true);
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      expect(b.state.available, isTrue);
      await b.close();
    });

    blocTest<AssistantBloc, AssistantState>(
      'une sonde forcée repart de « indisponible » (autre compte, ancien '
      'résultat)',
      build: () {
        when(() => repository.status()).thenAnswer((_) async => true);
        return build();
      },
      seed: () => const AssistantState(available: true),
      act: (b) => b.add(const AssistantStatusRequested()),
      expect: () => [
        isA<AssistantState>().having((s) => s.available, 'available', false),
        isA<AssistantState>().having((s) => s.available, 'available', true),
      ],
    );

    test('retour au premier plan : au plus une sonde toutes les 10 minutes, '
        'une sonde forcée passe toujours', () async {
      var now = DateTime(2026, 10, 16, 12);
      when(() => repository.status()).thenAnswer((_) async => true);
      final b = AssistantBloc(repository, support, analytics, clock: () => now);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 9));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      now = now.add(const Duration(minutes: 2));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      await b.close();
    });

    test('résultat inconnu (réseau instable) : la valeur précédente est '
        'gardée et le délai de 10 minutes n’est pas armé', () async {
      var now = DateTime(2026, 10, 16, 12);
      final results = <bool?>[true, null, null, false];
      when(
        () => repository.status(),
      ).thenAnswer((_) async => results.removeAt(0));
      final b = AssistantBloc(repository, support, analytics, clock: () => now);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isTrue);
      // Sonde non forcée 11 minutes plus tard : réseau KO, rien ne change.
      now = now.add(const Duration(minutes: 11));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isTrue);
      // Une minute après seulement : elle repart (le délai n'a pas été armé).
      now = now.add(const Duration(minutes: 1));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isTrue);
      verify(() => repository.status()).called(3);
      // Réponse « non » : cette fois le délai est armé.
      now = now.add(const Duration(minutes: 11));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isFalse);
      now = now.add(const Duration(minutes: 1));
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      await b.close();
    });

    blocTest<AssistantBloc, AssistantState>(
      'résultat inconnu sur une sonde forcée : indisponible (pas de résultat '
      'd’un autre compte)',
      build: () {
        when(() => repository.status()).thenAnswer((_) async => null);
        return build();
      },
      seed: () => const AssistantState(available: true),
      act: (b) => b.add(const AssistantStatusRequested()),
      verify: (b) => expect(b.state.available, isFalse),
    );

    test('une sonde forcée qui arrive pendant une sonde non forcée est '
        'rejouée à la fin de celle-ci', () async {
      final first = Completer<bool?>();
      final calls = <bool>[];
      when(() => repository.status()).thenAnswer((_) {
        calls.add(true);
        return calls.length == 1 ? first.future : Future<bool?>.value(true);
      });
      final b = build();
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(1), reason: 'une seule requête en vol');
      first.complete(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      expect(b.state.available, isTrue);
      await b.close();
    });

    test('une sonde non forcée pendant une sonde en vol est ignorée', () async {
      final first = Completer<bool?>();
      when(() => repository.status()).thenAnswer((_) => first.future);
      final b = build();
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      first.complete(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      await b.close();
    });

    blocTest<AssistantBloc, AssistantState>(
      'une sonde qui répond vrai efface un ancien « éteint »',
      build: () {
        when(() => repository.status()).thenAnswer((_) async => true);
        return build();
      },
      seed: () => const AssistantState(disabled: true),
      act: (b) => b.add(const AssistantStatusRequested()),
      verify: (b) {
        expect(b.state.disabled, isFalse);
        expect(b.state.available, isTrue);
      },
    );
  });

  group('fin de session (changement de compte)', () {
    late Completer<AssistantAnswer> answerGate;
    late Completer<SupportTicket> ticketGate;

    blocTest<AssistantBloc, AssistantState>(
      'réponse en vol puis fin de session : la réponse tardive est ignorée, '
      'état vierge',
      build: () {
        answerGate = Completer<AssistantAnswer>();
        askAny().thenAnswer((_) => answerGate.future);
        return build();
      },
      seed: () => const AssistantState(
        available: true,
        quotaExceeded: true,
        lastFailedQuestion: 'ancienne',
        messages: [
          AssistantMessage(id: 90, author: AssistantAuthor.user, text: 'A'),
        ],
      ),
      act: (b) async {
        b.add(const AssistantQuestionSubmitted('Question de A', locale: 'fr'));
        await Future<void>.delayed(Duration.zero);
        b.add(const AssistantSessionEnded());
        await Future<void>.delayed(Duration.zero);
        answerGate.complete(_answer);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state, const AssistantState());
        verifyNever(
          () => backend.capture(AnalyticsEvents.assistantAnswerReceived, any()),
        );
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'escalade en vol puis fin de session : pas de succès, aucun ticket '
      'signalé au compte suivant',
      build: () {
        ticketGate = Completer<SupportTicket>();
        when(
          () => support.createTicket(
            category: any(named: 'category'),
            subject: any(named: 'subject'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) => ticketGate.future);
        return build();
      },
      seed: () => const AssistantState(
        available: true,
        messages: [
          AssistantMessage(id: 1, author: AssistantAuthor.user, text: 'Q'),
        ],
      ),
      act: (b) async {
        b.add(const AssistantEscalationRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const AssistantSessionEnded());
        await Future<void>.delayed(Duration.zero);
        ticketGate.complete(_ticket);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) => expect(b.state, const AssistantState()),
    );

    test('sonde en vol puis fin de session : son résultat ne passe pas au '
        'compte suivant', () async {
      final gate = Completer<bool?>();
      when(() => repository.status()).thenAnswer((_) => gate.future);
      final b = build();
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantSessionEnded());
      await Future<void>.delayed(Duration.zero);
      gate.complete(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isFalse);
      await b.close();
    });

    test('fin de session : le compte suivant sonde de nouveau, même moins de '
        '10 minutes après', () async {
      final now = DateTime(2026, 10, 16, 12);
      when(() => repository.status()).thenAnswer((_) async => true);
      final b = AssistantBloc(repository, support, analytics, clock: () => now);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      b.add(const AssistantSessionEnded());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.available, isFalse);
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.status()).called(1);
      expect(b.state.available, isTrue);
      await b.close();
    });

    test('fin de session : une sonde forcée en attente n’est pas rejouée '
        'pour le compte suivant', () async {
      final first = Completer<bool?>();
      final calls = <bool>[];
      when(() => repository.status()).thenAnswer((_) {
        calls.add(true);
        return calls.length == 1 ? first.future : Future<bool?>.value(true);
      });
      final b = build();
      b.add(const AssistantStatusRequested(force: false));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantStatusRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantSessionEnded());
      await Future<void>.delayed(Duration.zero);
      first.complete(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(1));
      expect(b.state.available, isFalse);
      await b.close();
    });

    test('l’événement est comparable', () {
      expect(const AssistantSessionEnded(), const AssistantSessionEnded());
    });
  });

  group('colis de l’utilisateur', () {
    const parcel = AssistantParcelChoice(
      parcelId: 'b1',
      status: 'IN_TRANSIT',
      role: 'SENDER',
      active: true,
      trackingNumber: 'DON-7K3M9QXA',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
    );
    const ended = AssistantParcelChoice(
      parcelId: 'b2',
      status: 'COMPLETED',
      role: 'TRAVELER',
      active: false,
    );
    const choose = AssistantAnswer(
      answer: 'Choisissez le colis concerné.',
      answered: true,
      actions: [],
      provider: 'claude',
      remainingToday: 18,
      parcels: [parcel, ended],
    );
    const aboutParcel = AssistantAnswer(
      answer: 'Il est en route.',
      answered: true,
      actions: [AssistantAction(route: '/bids/b1', label: 'Voir le colis')],
      provider: 'claude',
      remainingToday: 17,
      parcelId: 'b1',
    );

    When<Future<AssistantAnswer>> askWith(String? parcelId) => when(
      () => repository.ask(
        question: any(named: 'question'),
        locale: any(named: 'locale'),
        history: any(named: 'history'),
        parcelId: parcelId,
      ),
    );

    Future<AssistantBloc> askedForChoice() async {
      askWith(null).thenAnswer((_) async => choose);
      final b = build();
      b.add(
        const AssistantQuestionSubmitted('Où est mon colis ?', locale: 'fr'),
      );
      await Future<void>.delayed(Duration.zero);
      return b;
    }

    test(
      'les colis proposés restent sur la réponse, sans colis suivi',
      () async {
        final b = await askedForChoice();
        expect(b.state.messages.last.parcels, [parcel, ended]);
        expect(b.state.parcelId, isNull);
        verify(
          () => backend.capture(AnalyticsEvents.assistantParcelChoicesShown, {
            'count': 2,
            'active_count': 1,
          }),
        ).called(1);
        await b.close();
      },
    );

    test('choisir un colis repose la question pour lui et le garde', () async {
      final b = await askedForChoice();
      askWith('b1').thenAnswer((_) async => aboutParcel);
      b.add(
        const AssistantParcelChosen(
          parcel,
          label: 'DON-7K3M9QXA · Paris → Dakar',
          position: 0,
          locale: 'fr',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final captured = verify(
        () => repository.ask(
          question: 'Où est mon colis ?',
          locale: 'fr',
          history: captureAny(named: 'history'),
          parcelId: 'b1',
        ),
      ).captured;
      final history = captured.single as List<AssistantHistoryTurn>;
      expect(history.map((t) => t.text), [
        'Où est mon colis ?',
        'Choisissez le colis concerné.',
      ]);
      expect(b.state.messages.map((m) => m.text).toList().sublist(2), [
        'DON-7K3M9QXA · Paris → Dakar',
        'Il est en route.',
      ]);
      expect(b.state.parcelId, 'b1');
      verify(
        () => backend.capture(AnalyticsEvents.assistantParcelChosen, {
          'role': 'SENDER',
          'active': true,
          'position': 0,
        }),
      ).called(1);

      // La question suivante parle du même colis.
      b.add(const AssistantQuestionSubmitted('Et le code ?', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => repository.ask(
          question: 'Et le code ?',
          locale: 'fr',
          history: any(named: 'history'),
          parcelId: 'b1',
        ),
      ).called(1);
      await b.close();
    });

    test('une réponse sans colis met fin au suivi', () async {
      final b = await askedForChoice();
      askWith('b1').thenAnswer((_) async => aboutParcel);
      b.add(
        const AssistantParcelChosen(
          parcel,
          label: 'DON-7K3M9QXA',
          position: 0,
          locale: 'fr',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      askWith('b1').thenAnswer((_) async => _answer);
      b.add(const AssistantQuestionSubmitted('DON-ZZZZ9999', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.parcelId, isNull);
      await b.close();
    });

    test('après un échec, « Réessayer » renvoie le colis choisi', () async {
      final b = await askedForChoice();
      askWith('b1').thenThrow(const AssistantNetworkException());
      b.add(
        const AssistantParcelChosen(
          parcel,
          label: 'DON-7K3M9QXA',
          position: 0,
          locale: 'fr',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages.last.isError, isTrue);
      expect(b.state.parcelId, 'b1');
      askWith('b1').thenAnswer((_) async => aboutParcel);
      b.add(const AssistantRetryRequested(locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages.last.text, 'Il est en route.');
      await b.close();
    });

    test('« Nouvelle conversation » oublie le colis', () async {
      final b = await askedForChoice();
      askWith('b1').thenAnswer((_) async => aboutParcel);
      b.add(
        const AssistantParcelChosen(
          parcel,
          label: 'DON-7K3M9QXA',
          position: 0,
          locale: 'fr',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantResetRequested());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.parcelId, isNull);
      expect(b.state.messages, isEmpty);
      await b.close();
    });

    test('un colis qui n’est proposé par aucune réponse est ignoré', () async {
      final b = build();
      b.add(
        const AssistantParcelChosen(
          parcel,
          label: 'DON-7K3M9QXA',
          position: 0,
          locale: 'fr',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages, isEmpty);
      verifyNever(
        () => repository.ask(
          question: any(named: 'question'),
          locale: any(named: 'locale'),
          history: any(named: 'history'),
          parcelId: any(named: 'parcelId'),
        ),
      );
      await b.close();
    });

    test('l’événement de choix est comparable', () {
      expect(
        const AssistantParcelChosen(
          parcel,
          label: 'x',
          position: 1,
          locale: 'fr',
        ),
        const AssistantParcelChosen(
          parcel,
          label: 'x',
          position: 1,
          locale: 'fr',
        ),
      );
    });
  });

  group('approche de la limite', () {
    AssistantAnswer withRemaining(int n) => AssistantAnswer(
      answer: 'ok',
      answered: true,
      actions: const [],
      provider: 'claude',
      remainingToday: n,
    );

    test('garde le nombre restant, sans prévenir loin de la limite', () async {
      answers(withRemaining(17));
      final b = build();
      b.add(const AssistantQuestionSubmitted('q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.remainingToday, 17);
      verifyNever(
        () =>
            backend.capture(AnalyticsEvents.assistantQuotaWarningShown, any()),
      );
      await b.close();
    });

    test('prévient dès qu’il reste 2 questions, et le garde après une '
        'nouvelle conversation', () async {
      answers(withRemaining(2));
      final b = build();
      b.add(const AssistantQuestionSubmitted('q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      verify(
        () => backend.capture(AnalyticsEvents.assistantQuotaWarningShown, {
          'remaining': 2,
        }),
      ).called(1);
      b.add(const AssistantResetRequested());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages, isEmpty);
      expect(b.state.remainingToday, 2);
      await b.close();
    });

    test('quota atteint : plus aucune question', () async {
      askAny().thenThrow(const AssistantQuotaExceededException());
      final b = build();
      b.add(const AssistantQuestionSubmitted('q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.remainingToday, 0);
      expect(b.state.quotaExceeded, isTrue);
      await b.close();
    });

    test('fin de session : oublié pour le compte suivant', () async {
      answers(withRemaining(1));
      final b = build();
      b.add(const AssistantQuestionSubmitted('q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantSessionEnded());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.remainingToday, isNull);
      await b.close();
    });
  });

  group('explication de l’écran d’origine', () {
    const intro = AssistantScreenIntro(
      explanation: 'Vous êtes sur Mes colis.',
      questions: ['Comment annuler un envoi ?'],
      actions: [AssistantAction(route: '/tracking', label: 'Ouvrir le suivi')],
    );

    test(
      'ajoute l’explication et ses questions, sans question au back',
      () async {
        when(
          () => repository.screen('/envois', 'fr'),
        ).thenAnswer((_) async => intro);
        final b = build();
        b.add(const AssistantScreenOpened('/envois', locale: 'fr'));
        await Future<void>.delayed(Duration.zero);
        final m = b.state.messages.single;
        expect(m.author, AssistantAuthor.assistant);
        expect(m.text, 'Vous êtes sur Mes colis.');
        expect(m.suggestions, ['Comment annuler un envoi ?']);
        expect(m.actions.single.route, '/tracking');
        expect(m.screen, '/envois');
        verify(
          () => backend.capture(AnalyticsEvents.assistantScreenExplained, {
            'screen': '/envois',
          }),
        ).called(1);
        verifyNever(
          () => repository.ask(
            question: any(named: 'question'),
            locale: any(named: 'locale'),
            history: any(named: 'history'),
            parcelId: any(named: 'parcelId'),
          ),
        );

        // Rouvert depuis le même écran : pas de doublon.
        b.add(const AssistantScreenOpened('/envois', locale: 'fr'));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.messages, hasLength(1));
        verify(() => repository.screen('/envois', 'fr')).called(1);
        await b.close();
      },
    );

    test('écran sans fiche : rien de plus, mais mesuré', () async {
      when(() => repository.screen(any(), any())).thenAnswer((_) async => null);
      final b = build();
      b.add(const AssistantScreenOpened('/inconnu', locale: 'en'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages, isEmpty);
      verify(
        () => backend.capture(AnalyticsEvents.assistantScreenUnexplained, {
          'screen': '/inconnu',
        }),
      ).called(1);
      await b.close();
    });

    test('fiche d’un colis : ce colis devient le sujet', () async {
      when(() => repository.screen(any(), any())).thenAnswer((_) async => null);
      final b = build();
      b.add(
        const AssistantScreenOpened(
          '/bids/:bidId',
          locale: 'fr',
          parcelId: 'b42',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(b.state.parcelId, 'b42');
      await b.close();
    });

    test('assistant éteint : rien n’est demandé', () async {
      askAny().thenThrow(const AssistantDisabledException());
      final b = build();
      b.add(const AssistantQuestionSubmitted('q', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantScreenOpened('/envois', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => repository.screen(any(), any()));
      await b.close();
    });

    test('réponse arrivée après une fin de session : écartée', () async {
      final pending = Completer<AssistantScreenIntro?>();
      when(
        () => repository.screen(any(), any()),
      ).thenAnswer((_) => pending.future);
      final b = build();
      b.add(const AssistantScreenOpened('/envois', locale: 'fr'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AssistantSessionEnded());
      await Future<void>.delayed(Duration.zero);
      pending.complete(intro);
      await Future<void>.delayed(Duration.zero);
      expect(b.state.messages, isEmpty);
      await b.close();
    });

    test('l’événement est comparable', () {
      expect(
        const AssistantScreenOpened('/a', locale: 'fr', parcelId: 'x'),
        const AssistantScreenOpened('/a', locale: 'fr', parcelId: 'x'),
      );
    });
  });

  // FLUTTER-RD : questions de suite et découverte sous la dernière réponse.
  group('suggestions de la réponse', () {
    const withSuggestions = AssistantAnswer(
      answer: 'Payez par carte ou en espèces.',
      answered: true,
      actions: [],
      provider: 'claude',
      remainingToday: 15,
      suggestions: [
        AssistantSuggestion(
          text: 'Comment être remboursé ?',
          kind: AssistantSuggestionKind.followUp,
        ),
        AssistantSuggestion(
          text: 'Que sont les alertes de trajet ?',
          kind: AssistantSuggestionKind.discovery,
        ),
      ],
    );

    blocTest<AssistantBloc, AssistantState>(
      'stockées sur le dernier message, comptées dans l’analytics',
      build: () {
        answers(withSuggestions);
        return build();
      },
      act: (b) => b.add(
        const AssistantQuestionSubmitted('Comment payer ?', locale: 'fr'),
      ),
      skip: 1,
      expect: () => [
        isA<AssistantState>().having(
          (s) => s.messages.last.nextQuestions,
          'nextQuestions',
          withSuggestions.suggestions,
        ),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.assistantAnswerReceived, {
          'answered': true,
          'provider': 'claude',
          'actions_count': 0,
          'suggestions_count': 2,
        }),
      ).called(1),
    );

    blocTest<AssistantBloc, AssistantState>(
      'la question de l’utilisateur ne porte jamais de suggestion',
      build: () {
        answers(withSuggestions);
        return build();
      },
      act: (b) => b.add(
        const AssistantQuestionSubmitted('Comment payer ?', locale: 'fr'),
      ),
      verify: (b) {
        expect(b.state.messages.first.author, AssistantAuthor.user);
        expect(b.state.messages.first.nextQuestions, isEmpty);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'puce touchée : nouvelle question envoyée, type de puce mesuré',
      build: () {
        answers(withSuggestions);
        return build();
      },
      act: (b) async {
        b.add(
          const AssistantQuestionSubmitted('Comment payer ?', locale: 'fr'),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(
          const AssistantQuestionSubmitted(
            'Que sont les alertes de trajet ?',
            locale: 'fr',
            fromSuggestion: true,
            suggestionKind: AssistantSuggestionKind.discovery,
          ),
        );
      },
      verify: (b) {
        final texts = b.state.messages.map((m) => m.text).toList();
        expect(texts, [
          'Comment payer ?',
          'Payez par carte ou en espèces.',
          'Que sont les alertes de trajet ?',
          'Payez par carte ou en espèces.',
        ]);
        verify(
          () => repository.ask(
            question: 'Que sont les alertes de trajet ?',
            locale: 'fr',
            history: any(named: 'history'),
          ),
        ).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.assistantQuestionAsked, {
            'locale': 'fr',
            'suggestion': true,
            'suggestion_kind': 'discovery',
            'voice': false,
          }),
        ).called(1);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'question de suite et question dictée : mesurées',
      build: () {
        answers(_answer);
        return build();
      },
      act: (b) async {
        b.add(
          const AssistantQuestionSubmitted(
            'Et ensuite ?',
            locale: 'fr',
            suggestionKind: AssistantSuggestionKind.followUp,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(
          const AssistantQuestionSubmitted(
            'Question dictée',
            locale: 'fr',
            fromVoice: true,
          ),
        );
      },
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.assistantQuestionAsked, {
            'locale': 'fr',
            'suggestion': true,
            'suggestion_kind': 'follow_up',
            'voice': false,
          }),
        ).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.assistantQuestionAsked, {
            'locale': 'fr',
            'suggestion': false,
            'voice': true,
          }),
        ).called(1);
      },
    );
  });
}
