import 'dart:async';

import 'package:dony/features/profile/presentation/screens/help_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const _configuration = HelpTutorialPlayerConfiguration(videoId: 'dQw4w9WgXcQ');

void main() {
  group('adaptateur YouTube 5.2.2', () {
    test(
      'attend la readiness réelle et configure cue, contrôles et nocookie',
      () async {
        final controller = _FakeYoutubeController();
        late YoutubePlayerParams capturedParams;
        late String capturedKey;
        final session = createYoutubeTutorialPlayerSession(
          _configuration,
          controllerFactory:
              ({required key, required params, required onWebResourceError}) {
                capturedKey = key;
                capturedParams = params;
                return controller;
              },
          systemUi: _RecordingSystemUi(<String>[]),
        );
        addTearDown(session.close);
        final events = <HelpTutorialPlayerEvent>[];
        final subscription = session.events.listen(events.add);
        addTearDown(subscription.cancel);

        await pumpEventQueue();

        expect(events, isEmpty);
        expect(capturedKey, 'dQw4w9WgXcQ');
        expect(capturedParams.showControls, isTrue);
        expect(capturedParams.showFullscreenButton, isTrue);
        expect(capturedParams.enableCaption, isTrue);
        expect(capturedParams.strictRelatedVideos, isTrue);
        expect(capturedParams.origin, 'https://www.youtube-nocookie.com');
        expect(controller.cuedVideoIds, ['dQw4w9WgXcQ']);

        controller.completeCue();
        await pumpEventQueue();

        expect(events, [HelpTutorialPlayerEvent.ready]);
      },
    );

    test(
      'fusionne une erreur de ressource WebView dans le flux métier',
      () async {
        final controller = _FakeYoutubeController();
        late ValueChanged<YoutubeWebResourceError> resourceErrorCallback;
        final session = createYoutubeTutorialPlayerSession(
          _configuration,
          controllerFactory:
              ({required key, required params, required onWebResourceError}) {
                resourceErrorCallback = onWebResourceError;
                return controller;
              },
          systemUi: _RecordingSystemUi(<String>[]),
        );
        addTearDown(session.close);
        final events = <HelpTutorialPlayerEvent>[];
        final subscription = session.events.listen(events.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();
        events.clear();

        resourceErrorCallback(
          const YoutubeWebResourceError(
            errorCode: -2,
            description: 'host lookup failed',
            isForMainFrame: true,
          ),
        );
        await pumpEventQueue();

        expect(events, [HelpTutorialPlayerEvent.error]);
      },
    );

    test('fusionne les erreurs API et les erreurs du stream', () async {
      final controller = _FakeYoutubeController()..completeCue();
      final session = createYoutubeTutorialPlayerSession(
        _configuration,
        controllerFactory:
            ({required key, required params, required onWebResourceError}) =>
                controller,
        systemUi: _RecordingSystemUi(<String>[]),
      );
      addTearDown(session.close);
      final events = <HelpTutorialPlayerEvent>[];
      final subscription = session.events.listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      events.clear();

      controller
        ..emit(YoutubePlayerValue(error: YoutubeError.videoNotFound))
        ..emitError(StateError('stream failure'));
      await pumpEventQueue();

      expect(events, [
        HelpTutorialPlayerEvent.error,
        HelpTutorialPlayerEvent.error,
      ]);
    });

    test('propage une factory qui échoue au host appelant', () {
      expect(
        () => createYoutubeTutorialPlayerSession(
          _configuration,
          controllerFactory:
              ({required key, required params, required onWebResourceError}) =>
                  throw StateError('controller unavailable'),
          systemUi: _RecordingSystemUi(<String>[]),
        ),
        throwsStateError,
      );
    });

    test('sort du plein écran et restaure SystemChrome avant close', () async {
      final order = <String>[];
      final controller = _FakeYoutubeController(order: order)..completeCue();
      final session = createYoutubeTutorialPlayerSession(
        _configuration,
        controllerFactory:
            ({required key, required params, required onWebResourceError}) =>
                controller,
        systemUi: _RecordingSystemUi(order),
      );
      await pumpEventQueue();
      controller.emit(
        YoutubePlayerValue(
          fullScreenOption: const FullScreenOption(enabled: true),
        ),
      );

      await session.close();

      expect(order, ['exit_fullscreen', 'restore_system_ui', 'close']);
    });
  });

  group('restauration SystemChrome', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      test(
        'restaure orientations et edge-to-edge sur ${platform.name}',
        () async {
          final chrome = _RecordingSystemChrome();
          final restorer = FlutterHelpTutorialSystemUi(
            systemChrome: chrome,
            platform: platform,
          );

          await restorer.restore();

          expect(chrome.orientations, DeviceOrientation.values);
          expect(chrome.uiModes, [SystemUiMode.edgeToEdge]);
          expect(
            chrome.overlayStyles.length,
            platform == TargetPlatform.android ? 1 : 0,
          );
          if (platform == TargetPlatform.android) {
            final style = chrome.overlayStyles.single;
            expect(style.systemNavigationBarColor, Colors.transparent);
            expect(style.systemNavigationBarDividerColor, Colors.transparent);
            expect(style.systemNavigationBarContrastEnforced, isFalse);
          }
        },
      );
    }
  });
}

final class _FakeYoutubeController implements HelpTutorialYoutubeController {
  _FakeYoutubeController({List<String>? order}) : order = order ?? <String>[];

  final _values = StreamController<YoutubePlayerValue>.broadcast(sync: true);
  final _cueCompleter = Completer<void>();
  final List<String> order;
  final cuedVideoIds = <String>[];

  @override
  bool isFullScreen = false;

  void completeCue() {
    if (!_cueCompleter.isCompleted) {
      _cueCompleter.complete();
    }
  }

  void emit(YoutubePlayerValue value) => _values.add(value);

  void emitError(Object error) => _values.addError(error);

  @override
  Stream<YoutubePlayerValue> get values => _values.stream;

  @override
  Future<void> cueVideoById({required String videoId}) {
    cuedVideoIds.add(videoId);
    return _cueCompleter.future;
  }

  @override
  Widget buildScaffold({
    required double aspectRatio,
    required Widget Function(Widget player) pageBuilder,
  }) {
    return pageBuilder(const ColoredBox(color: Colors.black));
  }

  @override
  void exitFullScreen() {
    order.add('exit_fullscreen');
    isFullScreen = false;
  }

  @override
  Future<void> close() async {
    order.add('close');
    await _values.close();
  }
}

final class _RecordingSystemUi implements HelpTutorialSystemUi {
  _RecordingSystemUi(this.order);

  final List<String> order;

  @override
  Future<void> restore() async {
    order.add('restore_system_ui');
  }
}

final class _RecordingSystemChrome implements HelpTutorialSystemChrome {
  List<DeviceOrientation> orientations = const [];
  final uiModes = <SystemUiMode>[];
  final overlayStyles = <SystemUiOverlayStyle>[];

  @override
  Future<void> setEnabledSystemUIMode(SystemUiMode mode) async {
    uiModes.add(mode);
  }

  @override
  Future<void> setPreferredOrientations(
    List<DeviceOrientation> orientations,
  ) async {
    this.orientations = List.of(orientations);
  }

  @override
  void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    overlayStyles.add(style);
  }
}
