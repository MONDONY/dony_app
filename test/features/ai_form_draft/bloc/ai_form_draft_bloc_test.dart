import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements AiFormDraftRepository {}

/// Résolveur qui rend le brouillon tel quel, avec [warnings].
class _FakeResolver implements AiDraftResolver {
  _FakeResolver([this.warnings = const []]);

  final List<AiDraftWarning> warnings;
  final calls = <Map<String, Object?>>[];

  @override
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft) async {
    calls.add(draft);
    return AiResolvedDraft(draft: draft, warnings: warnings);
  }
}

final _now = DateTime(2026, 10, 17, 9);

AiFormDraftReply _reply({
  Map<String, Object?> draft = const {'departureCity': 'Paris'},
  List<String> understood = const ['route'],
  List<String> missing = const ['departureDate', 'transportMode'],
  String? question = 'Le 15, c’est bien le samedi 15 novembre ?',
  List<String> quickReplies = const ['Oui', '15 décembre'],
  bool done = false,
  bool degraded = false,
}) => AiFormDraftReply(
  draft: draft,
  understood: understood,
  missing: missing,
  question: question,
  quickReplies: quickReplies,
  done: done,
  degraded: degraded,
  remainingToday: 20,
);

TypeMatcher<AiFormDraftState> _status(AiFormDraftStatus status) =>
    isA<AiFormDraftState>().having((s) => s.status, 'status', status);

void main() {
  late _MockRepository repository;
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;
  late _FakeResolver resolver;

  setUpAll(() => registerFallbackValue(AiFormKind.trip));

  setUp(() async {
    repository = _MockRepository();
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    resolver = _FakeResolver();
  });

  AiFormDraftBloc build({AiFormKind kind = AiFormKind.trip}) => AiFormDraftBloc(
    repository,
    analytics,
    session: AiFormDraftSession(
      kind: kind,
      resolver: resolver,
      defaultCurrency: 'EUR',
    ),
    clock: () => _now,
    locale: () => 'fr',
  );

  When<Future<AiFormDraftReply>> sendAny() => when(
    () => repository.send(
      kind: any(named: 'kind'),
      messages: any(named: 'messages'),
      draft: any(named: 'draft'),
      locale: any(named: 'locale'),
      now: any(named: 'now'),
      defaultCurrency: any(named: 'defaultCurrency'),
    ),
  );

  List<dynamic> sentMessages() => verify(
    () => repository.send(
      kind: any(named: 'kind'),
      messages: captureAny(named: 'messages'),
      draft: any(named: 'draft'),
      locale: any(named: 'locale'),
      now: any(named: 'now'),
      defaultCurrency: any(named: 'defaultCurrency'),
    ),
  ).captured;

  for (final kind in AiFormKind.values) {
    group('${kind.name} :', () {
      blocTest<AiFormDraftBloc, AiFormDraftState>(
        'ouverture : événement opened avec le kind',
        build: () => build(kind: kind),
        act: (b) => b.add(const AiFormDraftOpened()),
        expect: () => <AiFormDraftState>[],
        verify: (_) => verify(
          () => backend.capture(AnalyticsEvents.aiFormDraftOpened, {
            'kind': kind.analyticsName,
          }),
        ).called(1),
      );

      blocTest<AiFormDraftBloc, AiFormDraftState>(
        'tour normal : question et réponses rapides',
        build: () {
          sendAny().thenAnswer((_) async => _reply());
          return build(kind: kind);
        },
        act: (b) => b.add(
          const AiFormDraftTextSubmitted('  Je voyage de Paris à Abidjan  '),
        ),
        expect: () => [
          _status(
            AiFormDraftStatus.sending,
          ).having((s) => s.turns, 'turns', 1).having(
            (s) => s.messages,
            'messages',
            const [AiChatMessage.user('Je voyage de Paris à Abidjan')],
          ),
          _status(AiFormDraftStatus.asking)
              .having((s) => s.draft, 'draft', {'departureCity': 'Paris'})
              .having((s) => s.understood, 'understood', ['route'])
              .having((s) => s.missing, 'missing', [
                'departureDate',
                'transportMode',
              ])
              .having(
                (s) => s.question,
                'question',
                'Le 15, c’est bien le samedi 15 novembre ?',
              )
              .having((s) => s.quickReplies, 'quickReplies', [
                'Oui',
                '15 décembre',
              ])
              .having(
                (s) => s.messages.last,
                'dernier message',
                const AiChatMessage.assistant(
                  'Le 15, c’est bien le samedi 15 novembre ?',
                ),
              ),
        ],
        verify: (_) {
          verify(
            () => repository.send(
              kind: kind,
              messages: const [
                AiChatMessage.user('Je voyage de Paris à Abidjan'),
              ],
              draft: const {},
              locale: 'fr',
              now: _now,
              defaultCurrency: 'EUR',
            ),
          ).called(1);
          verify(
            () => backend.capture(AnalyticsEvents.aiFormDraftTurn, {
              'kind': kind.analyticsName,
              'turns': 1,
              'missing_count': 2,
            }),
          ).called(1);
        },
      );

      blocTest<AiFormDraftBloc, AiFormDraftState>(
        'tout est compris : résumé avec le brouillon résolu',
        build: () {
          resolver = _FakeResolver(const [AiDraftWarning.noPriceGrid]);
          sendAny().thenAnswer(
            (_) async => _reply(missing: const [], question: null, done: true),
          );
          return build(kind: kind);
        },
        act: (b) => b.add(const AiFormDraftTextSubmitted('tout')),
        expect: () => [
          _status(AiFormDraftStatus.sending),
          _status(AiFormDraftStatus.ready)
              .having((s) => s.resolved?.warnings, 'warnings', [
                AiDraftWarning.noPriceGrid,
              ])
              .having((s) => s.turnLimitReached, 'turnLimitReached', isFalse)
              .having((s) => s.question, 'question', isNull),
        ],
        verify: (_) => verify(
          () => backend.capture(AnalyticsEvents.aiFormDraftReady, {
            'kind': kind.analyticsName,
            'turns': 1,
            'turn_limit': false,
          }),
        ).called(1),
      );
    });
  }

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'deuxième tour : historique complet et brouillon précédent envoyés',
    build: () {
      sendAny().thenAnswer((_) async => _reply());
      return build();
    },
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.asking,
      turns: 1,
      messages: [
        AiChatMessage.user('Je voyage de Paris'),
        AiChatMessage.assistant('Vers où ?'),
      ],
      draft: {'departureCity': 'Paris'},
    ),
    act: (b) => b.add(const AiFormDraftQuickReplyTapped('Abidjan')),
    verify: (_) {
      // Une seule vérification : mocktail marque l'appel comme vérifié, une
      // seconde `verify` ne le retrouverait plus.
      final captured = verify(
        () => repository.send(
          kind: AiFormKind.trip,
          messages: captureAny(named: 'messages'),
          draft: captureAny(named: 'draft'),
          locale: 'fr',
          now: _now,
          defaultCurrency: 'EUR',
        ),
      ).captured;
      expect(captured[0], const [
        AiChatMessage.user('Je voyage de Paris'),
        AiChatMessage.assistant('Vers où ?'),
        AiChatMessage.user('Abidjan'),
      ]);
      expect(captured[1], const {'departureCity': 'Paris'});
    },
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'aucun fournisseur : degraded',
    build: () {
      sendAny().thenAnswer((_) async => _reply(question: null, degraded: true));
      return build();
    },
    act: (b) => b.add(const AiFormDraftTextSubmitted('bonjour')),
    expect: () => [
      _status(AiFormDraftStatus.sending),
      _status(
        AiFormDraftStatus.degraded,
      ).having((s) => s.hasDraft, 'hasDraft', isTrue),
    ],
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.aiFormDraftDegraded, {
        'kind': 'trip',
      }),
    ).called(1),
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'assistant éteint en cours de route : degraded',
    build: () {
      sendAny().thenThrow(const AiFormDraftDisabledException());
      return build();
    },
    act: (b) => b.add(const AiFormDraftTextSubmitted('bonjour')),
    expect: () => [
      _status(AiFormDraftStatus.sending),
      _status(AiFormDraftStatus.degraded),
    ],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'quota atteint : quotaExceeded avec le délai',
    build: () {
      sendAny().thenThrow(
        const AiFormDraftQuotaExceededException(retryAfter: Duration(hours: 5)),
      );
      return build(kind: AiFormKind.packageRequest);
    },
    act: (b) => b.add(const AiFormDraftTextSubmitted('bonjour')),
    expect: () => [
      _status(AiFormDraftStatus.sending),
      _status(
        AiFormDraftStatus.quotaExceeded,
      ).having((s) => s.retryAfter, 'retryAfter', const Duration(hours: 5)),
    ],
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.aiFormDraftQuotaExceeded, {
        'kind': 'package_request',
      }),
    ).called(1),
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'réseau : erreur, puis « Réessayer » renvoie le même tour',
    build: () {
      var calls = 0;
      sendAny().thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const AiFormDraftNetworkException();
        return _reply();
      });
      return build();
    },
    act: (b) async {
      b.add(const AiFormDraftTextSubmitted('bonjour'));
      await Future<void>.delayed(Duration.zero);
      b.add(const AiFormDraftRetryRequested());
    },
    expect: () => [
      _status(AiFormDraftStatus.sending),
      _status(AiFormDraftStatus.error),
      _status(AiFormDraftStatus.sending),
      _status(AiFormDraftStatus.asking).having((s) => s.turns, 'turns', 1),
    ],
    verify: (_) {
      final sent = sentMessages();
      expect(sent, hasLength(2));
      expect(sent[0], sent[1]);
    },
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'huitième tour sans conclusion : résumé avec la limite',
    build: () {
      sendAny().thenAnswer((_) async => _reply());
      return build();
    },
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.asking,
      turns: 7,
      messages: [AiChatMessage.user('…'), AiChatMessage.assistant('?')],
    ),
    act: (b) => b.add(const AiFormDraftTextSubmitted('encore')),
    expect: () => [
      _status(AiFormDraftStatus.sending).having((s) => s.turns, 'turns', 8),
      _status(AiFormDraftStatus.ready)
          .having((s) => s.turnLimitReached, 'turnLimitReached', isTrue)
          .having((s) => s.resolved, 'resolved', isNotNull),
    ],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    '422 trop de tours : résumé avec la limite',
    build: () {
      sendAny().thenThrow(const AiFormDraftTooManyTurnsException());
      return build();
    },
    act: (b) => b.add(const AiFormDraftTextSubmitted('encore')),
    expect: () => [
      _status(AiFormDraftStatus.sending),
      _status(
        AiFormDraftStatus.ready,
      ).having((s) => s.turnLimitReached, 'turnLimitReached', isTrue),
    ],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'un texte de plus de 1 000 caractères est tronqué avant l’envoi',
    build: () {
      sendAny().thenAnswer((_) async => _reply());
      return build();
    },
    act: (b) => b.add(AiFormDraftTextSubmitted('a' * 1500)),
    verify: (_) {
      final messages = sentMessages().single as List<AiChatMessage>;
      expect(messages.single.text.length, AiFormDraftBloc.maxMessageLength);
    },
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'texte vide ou envoi déjà en cours : ignoré',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.sending,
    ),
    act: (b) {
      b.add(const AiFormDraftTextSubmitted('bonjour'));
      b.add(const AiFormDraftTextSubmitted('   '));
    },
    expect: () => <AiFormDraftState>[],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'dictée : écoute, texte partiel, arrêt qui envoie',
    build: () {
      sendAny().thenAnswer((_) async => _reply());
      return build();
    },
    act: (b) async {
      b.add(const AiFormDraftMicPressed());
      b.add(const AiFormDraftSpeechPartial('Je voyage'));
      b.add(const AiFormDraftSpeechPartial('Je voyage de Paris'));
      b.add(const AiFormDraftMicStopped());
    },
    expect: () => [
      _status(
        AiFormDraftStatus.listening,
      ).having((s) => s.partialText, 'partialText', ''),
      _status(
        AiFormDraftStatus.listening,
      ).having((s) => s.partialText, 'partialText', 'Je voyage'),
      _status(
        AiFormDraftStatus.listening,
      ).having((s) => s.partialText, 'partialText', 'Je voyage de Paris'),
      _status(
        AiFormDraftStatus.sending,
      ).having((s) => s.partialText, 'partialText', '').having(
        (s) => s.messages,
        'messages',
        const [AiChatMessage.user('Je voyage de Paris')],
      ),
      _status(AiFormDraftStatus.asking),
    ],
    verify: (_) => verify(
      () => backend.capture(AnalyticsEvents.aiFormDraftVoiceUsed, {
        'kind': 'trip',
      }),
    ).called(1),
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'arrêt sans rien entendu : retour au repos, rien envoyé',
    build: build,
    act: (b) {
      b.add(const AiFormDraftMicPressed());
      b.add(const AiFormDraftMicStopped());
      b.add(const AiFormDraftMicStopped());
      b.add(const AiFormDraftSpeechPartial('trop tard'));
    },
    expect: () => [
      _status(AiFormDraftStatus.listening),
      _status(AiFormDraftStatus.idle),
    ],
    verify: (_) => verifyNever(
      () => repository.send(
        kind: any(named: 'kind'),
        messages: any(named: 'messages'),
        draft: any(named: 'draft'),
        locale: any(named: 'locale'),
        now: any(named: 'now'),
        defaultCurrency: any(named: 'defaultCurrency'),
      ),
    ),
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'micro indisponible : drapeau posé, retour au repos',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.listening,
    ),
    act: (b) => b.add(const AiFormDraftMicUnavailable()),
    expect: () => [
      _status(
        AiFormDraftStatus.idle,
      ).having((s) => s.micUnavailable, 'micUnavailable', isTrue),
    ],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'corriger depuis le résumé : retour au dialogue',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.ready,
      turns: 2,
      messages: [AiChatMessage.user('a'), AiChatMessage.assistant('b')],
      resolved: AiResolvedDraft(draft: {'departureCity': 'Paris'}),
    ),
    act: (b) => b.add(const AiFormDraftCorrectRequested()),
    expect: () => [
      _status(AiFormDraftStatus.asking)
          .having((s) => s.correcting, 'correcting', isTrue)
          .having((s) => s.resolved, 'resolved', isNull),
    ],
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'remplir depuis le résumé : applied avec le brouillon résolu',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.ready,
      draft: {'departureCity': 'Paris'},
      resolved: AiResolvedDraft(
        draft: {'departureCity': 'Paris', 'arrivalCity': 'Abidjan'},
      ),
    ),
    act: (b) => b.add(const AiFormDraftApplyRequested()),
    expect: () => [
      _status(AiFormDraftStatus.applied).having(
        (s) => s.resolved?.filledFields,
        'filledFields',
        {'departureCity', 'arrivalCity'},
      ),
    ],
    verify: (_) {
      expect(resolver.calls, isEmpty);
      verify(
        () => backend.capture(AnalyticsEvents.aiFormDraftApplied, {
          'kind': 'trip',
          'fields_count': 2,
        }),
      ).called(1);
    },
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'remplir avec ce qui est compris (degraded) : le brouillon est résolu',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.degraded,
      draft: {'departureCity': 'Paris'},
    ),
    act: (b) => b.add(const AiFormDraftApplyRequested()),
    expect: () => [_status(AiFormDraftStatus.applied)],
    verify: (_) => expect(resolver.calls, [
      {'departureCity': 'Paris'},
    ]),
  );

  blocTest<AiFormDraftBloc, AiFormDraftState>(
    'remplir sans rien de compris, ou pendant un échange : ignoré',
    build: build,
    seed: () => const AiFormDraftState(
      kind: AiFormKind.trip,
      status: AiFormDraftStatus.degraded,
    ),
    act: (b) => b.add(const AiFormDraftApplyRequested()),
    expect: () => <AiFormDraftState>[],
  );
}
