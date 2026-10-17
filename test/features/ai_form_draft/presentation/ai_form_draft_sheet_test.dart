import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_sheet.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/ai_form_draft_test_doubles.dart';
import '../../../helpers/l10n_test_helpers.dart';

class _MockBloc extends MockBloc<AiFormDraftEvent, AiFormDraftState>
    implements AiFormDraftBloc {}

class _MockCityRepository extends Mock implements CityRepository {}

class _MockPriceGridRepository extends Mock implements PriceGridRepository {}

class _PassThroughResolver implements AiDraftResolver {
  @override
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft) async =>
      AiResolvedDraft(draft: draft);
}

const _asking = AiFormDraftState(
  kind: AiFormKind.trip,
  status: AiFormDraftStatus.asking,
  turns: 1,
  messages: [
    AiChatMessage.user('Je voyage de Paris à Abidjan le 15'),
    AiChatMessage.assistant('Le 15, c’est bien le samedi 15 novembre ?'),
  ],
  draft: {'departureCity': 'Paris', 'arrivalCity': 'Abidjan'},
  understood: ['route'],
  missing: ['departureDate'],
  question: 'Le 15, c’est bien le samedi 15 novembre ?',
  quickReplies: ['Oui, 15 nov.', '15 décembre'],
);

const _resolved = AiResolvedDraft(
  draft: {'departureCity': 'Paris', 'arrivalCity': 'Abidjan'},
  warnings: [AiDraftWarning.noPriceGrid],
);

void main() {
  late _MockBloc bloc;
  final fr = lookupAppLocalizations(AppL10n.fr);
  AiFormDraftSession? receivedSession;
  Future<AiResolvedDraft?>? result;

  setUpAll(() async {
    registerFallbackValue(const AiFormDraftOpened());
    await initializeDateFormatting('fr');
  });

  setUp(() {
    bloc = _MockBloc();
    receivedSession = null;
    result = null;
    when(() => bloc.isClosed).thenReturn(false);
    getIt.registerFactoryParam<AiFormDraftBloc, AiFormDraftSession, void>((
      session,
      _,
    ) {
      receivedSession = session;
      return bloc;
    });
    getIt.registerSingleton<SpeechService>(FakeSpeechService());
  });

  tearDown(() => getIt.reset());

  void withState(AiFormDraftState state, {Stream<AiFormDraftState>? then}) =>
      whenListen(
        bloc,
        then ?? const Stream<AiFormDraftState>.empty(),
        initialState: state,
      );

  Future<void> open(
    WidgetTester tester, {
    AiFormKind kind = AiFormKind.trip,
    Future<AiResolvedDraft?> Function(BuildContext)? opener,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => result =
                    opener?.call(context) ??
                    AiFormDraftSheet.show(
                      context,
                      session: AiFormDraftSession(
                        kind: kind,
                        resolver: _PassThroughResolver(),
                        defaultCurrency: 'EUR',
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Indicateur de progression sans fin : pumpAndSettle ne rendrait
      // jamais la main.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
  }

  List<AiFormDraftEvent> added() =>
      verify(() => bloc.add(captureAny())).captured.cast<AiFormDraftEvent>();

  testWidgets('trajet, question : titre, accueil, puces, réponses, composer', (
    tester,
  ) async {
    withState(_asking);
    await open(tester);
    expect(find.text(fr.aiFormDraftSheetTitleTrip), findsOneWidget);
    expect(find.text(fr.aiFormDraftWelcomeTrip), findsOneWidget);
    expect(find.text(fr.aiFormDraftUnderstoodTitle), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(
      find.text('Le 15, c’est bien le samedi 15 novembre ?'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-mic-start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-quick-reply-0')));
    expect(added(), const [
      AiFormDraftOpened(),
      AiFormDraftQuickReplyTapped('Oui, 15 nov.'),
    ]);
    expect(receivedSession?.kind, AiFormKind.trip);
  });

  testWidgets('demande d’envoi, accueil : textes du kind', (tester) async {
    withState(const AiFormDraftState(kind: AiFormKind.packageRequest));
    await open(tester, kind: AiFormKind.packageRequest);
    expect(find.text(fr.aiFormDraftSheetTitlePackage), findsOneWidget);
    expect(find.text(fr.aiFormDraftWelcomePackage), findsOneWidget);
    expect(find.text(fr.aiFormDraftUnderstoodTitle), findsNothing);
  });

  testWidgets('écoute : bulle de transcription en direct', (tester) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.listening,
        partialText: 'Je voyage de Paris',
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftLiveTranscript), findsOneWidget);
    expect(find.text('Je voyage de Paris'), findsOneWidget);
    expect(find.byKey(const Key('ai-mic-stop')), findsOneWidget);
  });

  testWidgets('envoi en cours : indicateur', (tester) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.sending,
        messages: [AiChatMessage.user('bonjour')],
      ),
    );
    await open(tester, settle: false);
    expect(find.byKey(const Key('ai-sending')), findsOneWidget);
  });

  testWidgets('correction demandée : « Que voulez-vous corriger ? »', (
    tester,
  ) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.asking,
        correcting: true,
        messages: [AiChatMessage.user('a')],
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftCorrectPrompt), findsOneWidget);
  });

  testWidgets('question absente : question de repli', (tester) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.asking,
        messages: [AiChatMessage.user('a')],
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftQuestionFallback), findsOneWidget);
  });

  for (final kind in AiFormKind.values) {
    testWidgets('${kind.name}, tout compris : résumé, Corriger et Remplir', (
      tester,
    ) async {
      withState(
        AiFormDraftState(
          kind: kind,
          status: AiFormDraftStatus.ready,
          turns: 2,
          resolved: _resolved,
        ),
      );
      await open(tester, kind: kind);
      expect(find.text(fr.aiFormDraftReadyTitle), findsOneWidget);
      expect(find.text(fr.aiFormDraftWarningNoGrid), findsOneWidget);
      expect(find.byKey(const Key('ai-mic-start')), findsNothing);
      await tester.tap(find.byKey(const Key('ai-correct')));
      await tester.tap(find.byKey(const Key('ai-apply')));
      expect(added(), const [
        AiFormDraftOpened(),
        AiFormDraftCorrectRequested(),
        AiFormDraftApplyRequested(),
      ]);
    });
  }

  testWidgets('limite de tours : pas de « Corriger »', (tester) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.ready,
        turns: 8,
        turnLimitReached: true,
        resolved: _resolved,
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftTurnLimit), findsOneWidget);
    expect(find.byKey(const Key('ai-correct')), findsNothing);
    expect(find.byKey(const Key('ai-apply')), findsOneWidget);
  });

  for (final kind in AiFormKind.values) {
    testWidgets('${kind.name}, IA indisponible : message et remplir partiel', (
      tester,
    ) async {
      withState(
        AiFormDraftState(
          kind: kind,
          status: AiFormDraftStatus.degraded,
          draft: const {'departureCity': 'Paris'},
        ),
      );
      await open(tester, kind: kind);
      expect(find.text(fr.aiFormDraftDegradedMessage), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-apply-partial')));
      expect(added().last, const AiFormDraftApplyRequested());
    });
  }

  testWidgets('quota atteint, rien de compris : remplir partiel inactif', (
    tester,
  ) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.quotaExceeded,
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftQuotaMessage), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-apply-partial')));
    verifyNever(() => bloc.add(const AiFormDraftApplyRequested()));
  });

  testWidgets('réseau : message et Réessayer', (tester) async {
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.error,
        messages: [AiChatMessage.user('a')],
      ),
    );
    await open(tester);
    expect(find.text(fr.aiFormDraftNetworkError), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-retry')));
    expect(added().last, const AiFormDraftRetryRequested());
  });

  testWidgets('applied : la feuille se ferme avec le brouillon résolu', (
    tester,
  ) async {
    final states = StreamController<AiFormDraftState>();
    addTearDown(states.close);
    withState(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.ready,
        resolved: _resolved,
      ),
      then: states.stream,
    );
    await open(tester);
    states.add(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.applied,
        resolved: _resolved,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(fr.aiFormDraftReadyTitle), findsNothing);
    expect(await result, _resolved);
  });

  testWidgets('lanceur : construit la session du kind et rend le résultat', (
    tester,
  ) async {
    getIt.registerSingleton<CityRepository>(_MockCityRepository());
    getIt.registerSingleton<PriceGridRepository>(_MockPriceGridRepository());
    final states = StreamController<AiFormDraftState>();
    addTearDown(states.close);
    withState(_asking, then: states.stream);
    await open(
      tester,
      opener: (context) => const AiFormDraftLauncher().open(
        context,
        kind: AiFormKind.trip,
        defaultCurrency: 'XOF',
        isCardReady: () => true,
      ),
    );
    expect(receivedSession?.kind, AiFormKind.trip);
    expect(receivedSession?.defaultCurrency, 'XOF');
    states.add(
      const AiFormDraftState(
        kind: AiFormKind.trip,
        status: AiFormDraftStatus.applied,
        resolved: _resolved,
      ),
    );
    await tester.pumpAndSettle();
    expect(await result, _resolved);

    await open(
      tester,
      opener: (context) => const AiFormDraftLauncher().open(
        context,
        kind: AiFormKind.packageRequest,
        defaultCurrency: null,
      ),
    );
    expect(receivedSession?.kind, AiFormKind.packageRequest);
  });
}
