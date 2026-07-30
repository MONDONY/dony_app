import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const _webViewDetachStepTimeout = Duration(milliseconds: 500);

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
    this.readinessTimeout = const Duration(seconds: 15),
  });

  final String videoId;
  final bool autoPlay;
  final bool showControls;
  final bool showFullscreenButton;
  final bool enableCaption;
  final bool strictRelatedVideos;
  final bool privacyEnhanced;
  final double aspectRatio;
  final Duration readinessTimeout;
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

  Future<void> abandon();

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
  final resourceErrors = StreamController<YoutubeWebResourceError>(sync: true);
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
        privacyEnhancedMode: configuration.privacyEnhanced,
      ),
      onWebResourceError: (error) {
        if (!resourceErrors.isClosed) {
          resourceErrors.add(error);
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
    required StreamController<YoutubeWebResourceError> resourceErrors,
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
      _onWebResourceError,
    );
    _readinessTimer = Timer(
      configuration.readinessTimeout,
      _onReadinessTimeout,
    );
    unawaited(_initialize());
  }

  final HelpTutorialPlayerConfiguration configuration;
  final HelpTutorialYoutubeController _controller;
  final StreamController<YoutubeWebResourceError> _resourceErrors;
  final HelpTutorialSystemUi _systemUi;
  final _events = StreamController<HelpTutorialPlayerEvent>.broadcast(
    sync: true,
  );
  final _initializationCancelled = Completer<void>();

  late final StreamSubscription<YoutubePlayerValue> _valueSubscription;
  late final StreamSubscription<YoutubeWebResourceError>
  _resourceErrorSubscription;
  late final Timer _readinessTimer;
  bool _isFullScreen = false;
  bool _isReady = false;
  bool _initializationFailed = false;
  bool _webViewFailed = false;
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
      final didBecomeReady = await Future.any<bool>([
        _controller
            .cueVideoById(videoId: configuration.videoId)
            .then((_) => true),
        _initializationCancelled.future.then((_) => false),
      ]);
      if (!didBecomeReady || _closed || _initializationFailed) {
        return;
      }
      _isReady = true;
      _readinessTimer.cancel();
      _emit(HelpTutorialPlayerEvent.ready);
    } catch (_) {
      _failInitialization();
    }
  }

  void _onWebResourceError(YoutubeWebResourceError error) {
    if (error.isForMainFrame == true ||
        (!_isReady && _isCriticalYoutubeResource(error.url))) {
      _webViewFailed = true;
      if (_isReady) {
        _emit(HelpTutorialPlayerEvent.error);
      } else {
        _failInitialization();
      }
    }
  }

  void _onReadinessTimeout() => _failInitialization();

  void _failInitialization() {
    if (_closed || _isReady || _initializationFailed) {
      return;
    }
    _initializationFailed = true;
    _readinessTimer.cancel();
    _cancelInitialization();
    _emit(HelpTutorialPlayerEvent.error);
  }

  void _cancelInitialization() {
    if (!_initializationCancelled.isCompleted) {
      _initializationCancelled.complete();
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
    _readinessTimer.cancel();
    _cancelInitialization();

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
    await _ignoreCleanupError(
      _isReady && !_webViewFailed ? _controller.close() : _controller.abandon(),
    );
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

  YoutubePlayerController? _controller;

  YoutubePlayerController get _activeController =>
      _controller ?? (throw StateError('Le lecteur YouTube a déjà été fermé.'));

  @override
  Stream<YoutubePlayerValue> get values => _activeController.stream;

  @override
  bool get isFullScreen => _controller?.value.fullScreenOption.enabled ?? false;

  @override
  Future<void> cueVideoById({required String videoId}) {
    return _activeController.cueVideoById(videoId: videoId);
  }

  @override
  Widget buildScaffold({
    required double aspectRatio,
    required Widget Function(Widget player) pageBuilder,
  }) {
    return YoutubePlayerControllerProvider(
      controller: _activeController,
      child: pageBuilder(
        YoutubePlayer(
          controller: _activeController,
          aspectRatio: aspectRatio,
          backgroundColor: Colors.black,
        ),
      ),
    );
  }

  @override
  void exitFullScreen() => _activeController.exitFullScreen();

  // youtube_player_iframe 6.0.2's close() no longer waits for Ready — it
  // checks isInitCompleted instead, so it's already safe to call pre-Ready.
  // abandon() and close() are therefore identical; both interface methods
  // are kept because _YoutubeTutorialPlayerSession chooses between them
  // based on _isReady/_webViewFailed.
  @override
  Future<void> abandon() => close();

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.close();
    }
  }
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

bool _isCriticalYoutubeResource(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) {
    return true;
  }
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) {
    return true;
  }

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final isYoutubeHost = host == 'youtube.com' || host.endsWith('.youtube.com');
  final isPrivacyHost =
      host == 'youtube-nocookie.com' || host.endsWith('.youtube-nocookie.com');
  final isYoutubeAssetHost = host == 'ytimg.com' || host.endsWith('.ytimg.com');

  if (isPrivacyHost) {
    return path.startsWith('/embed/');
  }
  if (isYoutubeHost) {
    return path == '/iframe_api' ||
        path.startsWith('/embed/') ||
        path.startsWith('/s/player/');
  }
  if (isYoutubeAssetHost) {
    return path.contains('/player/') || path.contains('www-widgetapi');
  }
  return false;
}

Future<void> _ignoreCleanupError(Future<void> cleanup) async {
  try {
    await cleanup;
  } catch (_) {
    // La fermeture du WebView ne doit pas provoquer une erreur d’interface.
  }
}

/// Détache les callbacks et le document WebView avec une borne par étape.
///
/// Les trois opérations sont toujours tentées : une PlatformView déjà cassée
/// ne doit ni bloquer [HelpTutorialPlayerSession.close], ni empêcher le retrait
/// des références Dart restantes.
///
/// Plus appelée par [_PackageYoutubeController.abandon] depuis
/// youtube_player_iframe 6.0.2 : son `close()` gère nativement la fermeture
/// pré-Ready (vérifie `isInitCompleted`, pas `Ready`). Conservée pour les
/// implémentations de [HelpTutorialYoutubeController] qui en auraient encore
/// besoin.
Future<void> detachHelpTutorialWebView({
  required Future<void> Function() neutralizeNavigation,
  required Future<void> Function() removePlayerChannel,
  required Future<void> Function() loadBlankPage,
  Duration stepTimeout = _webViewDetachStepTimeout,
}) async {
  await _runBoundedCleanup(neutralizeNavigation, stepTimeout);
  await _runBoundedCleanup(removePlayerChannel, stepTimeout);
  await _runBoundedCleanup(loadBlankPage, stepTimeout);
}

Future<void> _runBoundedCleanup(
  Future<void> Function() cleanup,
  Duration timeout,
) async {
  try {
    await cleanup().timeout(timeout);
  } catch (_) {
    // Chaque étape suivante doit être tentée, même si le WebView est cassé.
  }
}
