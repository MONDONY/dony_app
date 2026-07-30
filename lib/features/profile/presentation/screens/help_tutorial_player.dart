import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const _youtubePrivacyEnhancedOrigin = 'https://www.youtube-nocookie.com';

enum HelpTutorialPlayerEvent { ready, playing, ended, error }

@immutable
final class HelpTutorialPlayerConfiguration {
  const HelpTutorialPlayerConfiguration({
    required this.videoId,
    this.autoPlay = false,
    this.showControls = true,
    this.showFullscreenButton = true,
    this.enableCaption = true,
    this.strictRelatedVideos = true,
    this.privacyEnhanced = true,
    this.aspectRatio = 16 / 9,
  });

  final String videoId;
  final bool autoPlay;
  final bool showControls;
  final bool showFullscreenButton;
  final bool enableCaption;
  final bool strictRelatedVideos;
  final bool privacyEnhanced;
  final double aspectRatio;
}

abstract interface class HelpTutorialPlayerSession {
  Stream<HelpTutorialPlayerEvent> get events;

  Widget buildScaffold({required Widget Function(Widget player) pageBuilder});

  Future<void> close();
}

typedef HelpTutorialPlayerSessionFactory =
    HelpTutorialPlayerSession Function(
      HelpTutorialPlayerConfiguration configuration,
    );

abstract interface class HelpTutorialYoutubeController {
  Stream<YoutubePlayerValue> get values;

  bool get isFullScreen;

  Future<void> cueVideoById({required String videoId});

  Widget buildScaffold({
    required double aspectRatio,
    required Widget Function(Widget player) pageBuilder,
  });

  void exitFullScreen();

  Future<void> close();
}

typedef HelpTutorialYoutubeControllerFactory =
    HelpTutorialYoutubeController Function({
      required String key,
      required YoutubePlayerParams params,
      required ValueChanged<YoutubeWebResourceError> onWebResourceError,
    });

abstract interface class HelpTutorialSystemUi {
  Future<void> restore();
}

abstract interface class HelpTutorialSystemChrome {
  Future<void> setPreferredOrientations(List<DeviceOrientation> orientations);

  Future<void> setEnabledSystemUIMode(SystemUiMode mode);

  void setSystemUIOverlayStyle(SystemUiOverlayStyle style);
}

final class FlutterHelpTutorialSystemUi implements HelpTutorialSystemUi {
  FlutterHelpTutorialSystemUi({
    this.systemChrome = const _FlutterHelpTutorialSystemChrome(),
    TargetPlatform? platform,
  }) : platform = platform ?? defaultTargetPlatform;

  final HelpTutorialSystemChrome systemChrome;
  final TargetPlatform platform;

  @override
  Future<void> restore() async {
    await systemChrome.setPreferredOrientations(DeviceOrientation.values);
    await systemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (platform == TargetPlatform.android) {
      systemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
  }
}

HelpTutorialPlayerSession createYoutubeTutorialPlayerSession(
  HelpTutorialPlayerConfiguration configuration, {
  HelpTutorialYoutubeControllerFactory controllerFactory =
      createHelpTutorialYoutubeController,
  HelpTutorialSystemUi? systemUi,
}) {
  final resourceErrors = StreamController<void>(sync: true);
  late final HelpTutorialYoutubeController controller;
  try {
    controller = controllerFactory(
      key: configuration.videoId,
      params: YoutubePlayerParams(
        showControls: configuration.showControls,
        showFullscreenButton: configuration.showFullscreenButton,
        enableCaption: configuration.enableCaption,
        strictRelatedVideos: configuration.strictRelatedVideos,
        captionLanguage: 'fr',
        interfaceLanguage: 'fr',
        origin: configuration.privacyEnhanced
            ? _youtubePrivacyEnhancedOrigin
            : 'https://www.youtube.com',
      ),
      onWebResourceError: (_) {
        if (!resourceErrors.isClosed) {
          resourceErrors.add(null);
        }
      },
    );
  } catch (_) {
    unawaited(resourceErrors.close());
    rethrow;
  }

  return _YoutubeTutorialPlayerSession(
    configuration: configuration,
    controller: controller,
    resourceErrors: resourceErrors,
    systemUi: systemUi ?? FlutterHelpTutorialSystemUi(),
  );
}

HelpTutorialYoutubeController createHelpTutorialYoutubeController({
  required String key,
  required YoutubePlayerParams params,
  required ValueChanged<YoutubeWebResourceError> onWebResourceError,
}) {
  return _PackageYoutubeController(
    key: key,
    params: params,
    onWebResourceError: onWebResourceError,
  );
}

final class _YoutubeTutorialPlayerSession implements HelpTutorialPlayerSession {
  _YoutubeTutorialPlayerSession({
    required this.configuration,
    required HelpTutorialYoutubeController controller,
    required StreamController<void> resourceErrors,
    required HelpTutorialSystemUi systemUi,
  }) : _controller = controller,
       _resourceErrors = resourceErrors,
       _systemUi = systemUi {
    _valueSubscription = _controller.values.listen(
      _onValue,
      onError: (_, _) => _emit(HelpTutorialPlayerEvent.error),
      onDone: () {
        if (!_closed) {
          _emit(HelpTutorialPlayerEvent.error);
        }
      },
    );
    _resourceErrorSubscription = _resourceErrors.stream.listen(
      (_) => _emit(HelpTutorialPlayerEvent.error),
    );
    unawaited(_initialize());
  }

  final HelpTutorialPlayerConfiguration configuration;
  final HelpTutorialYoutubeController _controller;
  final StreamController<void> _resourceErrors;
  final HelpTutorialSystemUi _systemUi;
  final _events = StreamController<HelpTutorialPlayerEvent>.broadcast(
    sync: true,
  );

  late final StreamSubscription<YoutubePlayerValue> _valueSubscription;
  late final StreamSubscription<void> _resourceErrorSubscription;
  bool _isFullScreen = false;
  bool _closed = false;

  @override
  Stream<HelpTutorialPlayerEvent> get events => _events.stream;

  Future<void> _initialize() async {
    try {
      if (configuration.autoPlay) {
        throw StateError(
          'Les tutoriels d’aide ne peuvent pas démarrer automatiquement.',
        );
      }
      await _controller.cueVideoById(videoId: configuration.videoId);
      _emit(HelpTutorialPlayerEvent.ready);
    } catch (_) {
      _emit(HelpTutorialPlayerEvent.error);
    }
  }

  void _onValue(YoutubePlayerValue value) {
    _isFullScreen = value.fullScreenOption.enabled;
    if (value.hasError) {
      _emit(HelpTutorialPlayerEvent.error);
      return;
    }
    switch (value.playerState) {
      case PlayerState.playing:
        _emit(HelpTutorialPlayerEvent.playing);
      case PlayerState.ended:
        _emit(HelpTutorialPlayerEvent.ended);
      case PlayerState.unknown:
      case PlayerState.unStarted:
      case PlayerState.paused:
      case PlayerState.buffering:
      case PlayerState.cued:
        break;
    }
  }

  void _emit(HelpTutorialPlayerEvent event) {
    if (!_closed && !_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Widget buildScaffold({required Widget Function(Widget player) pageBuilder}) {
    return _controller.buildScaffold(
      aspectRatio: configuration.aspectRatio,
      pageBuilder: pageBuilder,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;

    if (_isFullScreen || _controller.isFullScreen) {
      try {
        _controller.exitFullScreen();
      } catch (_) {
        // La restauration explicite ci-dessous reste obligatoire.
      }
    }
    await _ignoreCleanupError(_systemUi.restore());
    await _ignoreCleanupError(_valueSubscription.cancel());
    await _ignoreCleanupError(_resourceErrorSubscription.cancel());
    await _ignoreCleanupError(_resourceErrors.close());
    await _ignoreCleanupError(_events.close());
    await _ignoreCleanupError(_controller.close());
  }
}

final class _PackageYoutubeController implements HelpTutorialYoutubeController {
  _PackageYoutubeController({
    required String key,
    required YoutubePlayerParams params,
    required ValueChanged<YoutubeWebResourceError> onWebResourceError,
  }) : _controller = YoutubePlayerController(
         key: key,
         params: params,
         onWebResourceError: onWebResourceError,
       );

  final YoutubePlayerController _controller;

  @override
  Stream<YoutubePlayerValue> get values => _controller.stream;

  @override
  bool get isFullScreen => _controller.value.fullScreenOption.enabled;

  @override
  Future<void> cueVideoById({required String videoId}) {
    return _controller.cueVideoById(videoId: videoId);
  }

  @override
  Widget buildScaffold({
    required double aspectRatio,
    required Widget Function(Widget player) pageBuilder,
  }) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: aspectRatio,
      backgroundColor: Colors.black,
      builder: (context, player) => pageBuilder(player),
    );
  }

  @override
  void exitFullScreen() => _controller.exitFullScreen();

  @override
  Future<void> close() => _controller.close();
}

final class _FlutterHelpTutorialSystemChrome
    implements HelpTutorialSystemChrome {
  const _FlutterHelpTutorialSystemChrome();

  @override
  Future<void> setPreferredOrientations(List<DeviceOrientation> orientations) {
    return SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  Future<void> setEnabledSystemUIMode(SystemUiMode mode) {
    return SystemChrome.setEnabledSystemUIMode(mode);
  }

  @override
  void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    SystemChrome.setSystemUIOverlayStyle(style);
  }
}

Future<void> _ignoreCleanupError(Future<void> cleanup) async {
  try {
    await cleanup;
  } catch (_) {
    // La fermeture du WebView ne doit pas provoquer une erreur d’interface.
  }
}
