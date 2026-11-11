import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../matching/presentation/widgets/trip_owner/trip_card_harness.dart'
    show loadAppFonts;
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockBloc extends Mock implements VideoModalBloc {}

void main() {
  late _MockBloc bloc;
  late FakePlayerSession session;
  VideoModalPlayerResult? result;
  var popped = false;

  setUpAll(() async {
    // Vraies polices : la police de repli des tests fausse la mesure.
    await loadAppFonts();
    registerFallbackValue(const VideoModalAppOpenConsumedRequested());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.isClosed).thenReturn(false);
    session = FakePlayerSession();
    result = null;
    popped = false;
  });

  Future<void> pump(
    WidgetTester tester, {
    VideoModalTrigger trigger = VideoModalTrigger.searchTab,
    Locale locale = AppL10n.fr,
    HelpTutorialPlayerSessionFactory? factory,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await context.push<VideoModalPlayerResult>('/p');
                popped = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/p',
          builder: (_, _) => VideoModalPlayerScreen(
            args: VideoModalPlayerArgs(campaign: campaign(), trigger: trigger),
            modalBloc: bloc,
            sessionFactory: factory ?? (_) => session,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: testTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await settleTransitions(tester);
  }

  testWidgets('chargement puis lecture ; fermer = closed', (tester) async {
    usePhone360(tester);
    await pump(tester);
    expect(find.byKey(const Key('video-modal-player-loading')), findsOneWidget);
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    session.emit(HelpTutorialPlayerEvent.ready);
    await tester.pump();
    expect(find.byKey(const Key('video-modal-player-loading')), findsNothing);
    await tester.tap(find.byKey(const Key('video-modal-player-close')));
    await settleTransitions(tester);
    expect(popped, isTrue);
    expect(result, VideoModalPlayerResult.closed);
    expect(session.closed, isTrue);
  });

  testWidgets('le lecteur est demandé en lecture automatique', (tester) async {
    usePhone360(tester);
    final configurations = <HelpTutorialPlayerConfiguration>[];
    await pump(
      tester,
      factory: (configuration) {
        configurations.add(configuration);
        return session;
      },
    );
    expect(configurations, hasLength(1));
    expect(configurations.single.autoPlay, isTrue);
    expect(configurations.single.videoId, campaign().youtubeVideoId);
  });

  testWidgets('fin de vidéo : COMPLETED une fois, deux actions empilées', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(tester);
    session
      ..emit(HelpTutorialPlayerEvent.playing)
      ..emit(HelpTutorialPlayerEvent.ended)
      ..emit(HelpTutorialPlayerEvent.ended);
    await tester.pump();
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured, hasLength(1));
    final answer = captured.single as VideoModalAnswerRequested;
    expect(answer.event, VideoModalEventType.completed);
    expect(answer.trigger, VideoModalTrigger.searchTab);
    expect(find.text('Rechercher un trajet'), findsOneWidget);
    expect(find.text('Publier mon trajet'), findsOneWidget);
    final search = tester.getRect(
      find.byKey(const Key('video-modal-end-search')),
    );
    final publish = tester.getRect(
      find.byKey(const Key('video-modal-end-publish')),
    );
    expect(search.bottom, lessThanOrEqualTo(publish.top));
    expectButtonLabelsFit(tester);
    await tester.tap(find.byKey(const Key('video-modal-end-publish')));
    await settleTransitions(tester);
    expect(result, VideoModalPlayerResult.publishTrip);
  });

  testWidgets('fin de vidéo, anglais : libellés sur une ligne à 360 dp', (
    tester,
  ) async {
    usePhone360(tester);
    enableEnglish();
    await pump(tester, locale: AppL10n.en);
    session.emit(HelpTutorialPlayerEvent.ended);
    await tester.pump();
    expect(find.text('Find a trip'), findsOneWidget);
    expect(find.text('Publish my trip'), findsOneWidget);
    expectButtonLabelsFit(tester);
    await tester.tap(find.byKey(const Key('video-modal-end-search')));
    await settleTransitions(tester);
    expect(result, VideoModalPlayerResult.search);
  });

  testWidgets('fermer après la fin = completed', (tester) async {
    usePhone360(tester);
    await pump(tester);
    session.emit(HelpTutorialPlayerEvent.ended);
    await tester.pump();
    await tester.tap(find.byKey(const Key('video-modal-player-close')));
    await settleTransitions(tester);
    expect(result, VideoModalPlayerResult.completed);
  });

  testWidgets('devant un formulaire : la fin referme le lecteur', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(tester, trigger: VideoModalTrigger.sendParcel);
    session.emit(HelpTutorialPlayerEvent.ended);
    await settleTransitions(tester);
    expect(result, VideoModalPlayerResult.completed);
    expect(find.text('Rechercher un trajet'), findsNothing);
  });

  testWidgets('erreur du lecteur : message, pas de plantage', (tester) async {
    usePhone360(tester);
    await pump(tester);
    session.emit(HelpTutorialPlayerEvent.error);
    await tester.pump();
    expect(find.byKey(const Key('video-modal-player-error')), findsOneWidget);
    expect(
      find.text('La vidéo ne peut pas être lue pour le moment.'),
      findsOneWidget,
    );
  });

  testWidgets('erreur sur le flux du lecteur : message', (tester) async {
    usePhone360(tester);
    await pump(tester);
    session.controller.addError(StateError('x'));
    await tester.pump();
    expect(find.byKey(const Key('video-modal-player-error')), findsOneWidget);
  });

  testWidgets('session impossible à créer : message', (tester) async {
    usePhone360(tester);
    await pump(tester, factory: (_) => throw StateError('webview'));
    expect(find.byKey(const Key('video-modal-player-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-modal-player-close')));
    await settleTransitions(tester);
    expect(result, VideoModalPlayerResult.closed);
  });
}
