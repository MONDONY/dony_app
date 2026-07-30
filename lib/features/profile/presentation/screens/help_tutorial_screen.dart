import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const _youtubeWatchHost = 'www.youtube.com';
const _youtubePrivacyEnhancedOrigin = 'https://www.youtube-nocookie.com';

enum HelpTutorialPlayerEvent { playing, ended, error }

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

  Widget buildInline({required Widget Function(Widget player) frameBuilder});

  Future<void> close();
}

typedef HelpTutorialPlayerSessionFactory =
    HelpTutorialPlayerSession Function(
      HelpTutorialPlayerConfiguration configuration,
    );

HelpTutorialPlayerSession createYoutubeTutorialPlayerSession(
  HelpTutorialPlayerConfiguration configuration,
) {
  return _YoutubeTutorialPlayerSession(configuration);
}

class HelpTutorialScreen extends StatelessWidget {
  const HelpTutorialScreen({
    super.key,
    required this.tutorialId,
    this.playerSessionFactory = createYoutubeTutorialPlayerSession,
  });

  final String tutorialId;
  final HelpTutorialPlayerSessionFactory playerSessionFactory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HelpCenterBloc, HelpCenterState>(
      builder: (context, state) {
        final config = switch (state) {
          HelpCenterSuccess(:final config) => config,
          HelpCenterError(:final config) => config,
          _ => null,
        };
        final tutorial = config?.tutorialById(tutorialId);
        final body = switch ((state, tutorial)) {
          (HelpCenterInitial() || HelpCenterLoading(), _) =>
            const DonyEmptyState(type: DonyEmptyStateType.loading, title: ''),
          (_, null) => const DonyEmptyState(
            title: 'Tutoriel introuvable',
            description: 'Ce tutoriel n’est plus disponible.',
            iconAsset: 'circle-help',
          ),
          (_, final tutorial?) => _HelpTutorialContent(
            tutorial: tutorial,
            youtubeChannelUrl: config?.youtubeChannelUrl,
            playerSessionFactory: playerSessionFactory,
          ),
        };

        return DonyPageScaffold(
          title: 'Tutoriel vidéo',
          scrollable: tutorial != null,
          body: body,
        );
      },
    );
  }
}

class _HelpTutorialContent extends StatelessWidget {
  const _HelpTutorialContent({
    required this.tutorial,
    required this.youtubeChannelUrl,
    required this.playerSessionFactory,
  });

  final HelpTutorial tutorial;
  final Uri? youtubeChannelUrl;
  final HelpTutorialPlayerSessionFactory playerSessionFactory;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tutorial.title,
                  style: tt.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  tutorial.description,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (tutorial.durationLabel case final duration?) ...[
                  const SizedBox(height: DonySpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                      vertical: DonySpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      duration,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            )
            .animate()
            .fadeIn(duration: DonyDuration.slow, curve: DonyCurve.enter)
            .slideY(begin: 0.04, end: 0, curve: DonyCurve.enter),
        const SizedBox(height: DonySpacing.xl),
        _HelpTutorialPlayerHost(
          key: ValueKey(tutorial.id),
          tutorial: tutorial,
          sessionFactory: playerSessionFactory,
          onStarted: () => context.read<HelpCenterBloc>().add(
            HelpTutorialPlaybackRequested(
              tutorialId: tutorial.id,
              action: HelpPlaybackAction.started,
            ),
          ),
          onCompleted: () => context.read<HelpCenterBloc>().add(
            HelpTutorialPlaybackRequested(
              tutorialId: tutorial.id,
              action: HelpPlaybackAction.completed,
            ),
          ),
          onOpenExternal: () => context.read<HelpCenterBloc>().add(
            HelpExternalOpenRequested.tutorial(
              uri: Uri.https(_youtubeWatchHost, '/watch', {
                'v': tutorial.youtubeVideoId,
              }),
              tutorialId: tutorial.id,
            ),
          ),
        ),
        if (youtubeChannelUrl case final channelUrl?) ...[
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            label: 'S’abonner à la chaîne',
            iconAsset: 'circle-play',
            variant: DonyButtonVariant.secondary,
            onPressed: () => context.read<HelpCenterBloc>().add(
              HelpExternalOpenRequested.youtubeSubscription(
                uri: channelUrl,
                source: null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _PlayerViewStatus { ready, loading, error }

class _HelpTutorialPlayerHost extends StatefulWidget {
  const _HelpTutorialPlayerHost({
    super.key,
    required this.tutorial,
    required this.sessionFactory,
    required this.onStarted,
    required this.onCompleted,
    required this.onOpenExternal,
  });

  final HelpTutorial tutorial;
  final HelpTutorialPlayerSessionFactory sessionFactory;
  final VoidCallback onStarted;
  final VoidCallback onCompleted;
  final VoidCallback onOpenExternal;

  @override
  State<_HelpTutorialPlayerHost> createState() =>
      _HelpTutorialPlayerHostState();
}

class _HelpTutorialPlayerHostState extends State<_HelpTutorialPlayerHost> {
  final _statusController = StreamController<_PlayerViewStatus>.broadcast(
    sync: true,
  );
  HelpTutorialPlayerSession? _session;
  // ignore: cancel_subscriptions
  StreamSubscription<HelpTutorialPlayerEvent>? _eventSubscription;
  _PlayerViewStatus _currentStatus = _PlayerViewStatus.loading;
  bool _startedReported = false;
  bool _completedReported = false;
  bool _restarting = false;

  HelpTutorialPlayerConfiguration get _configuration =>
      HelpTutorialPlayerConfiguration(videoId: widget.tutorial.youtubeVideoId);

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void didUpdateWidget(_HelpTutorialPlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tutorial.youtubeVideoId != widget.tutorial.youtubeVideoId) {
      _startedReported = false;
      _completedReported = false;
      _restart();
    }
  }

  void _createSession() {
    try {
      final session = widget.sessionFactory(_configuration);
      _session = session;
      _eventSubscription = session.events.listen(
        _onPlayerEvent,
        onError: (_) => _emitStatus(_PlayerViewStatus.error),
      );
      _emitStatus(_PlayerViewStatus.ready);
    } catch (_) {
      _emitStatus(_PlayerViewStatus.error);
    }
  }

  void _onPlayerEvent(HelpTutorialPlayerEvent event) {
    switch (event) {
      case HelpTutorialPlayerEvent.playing:
        if (!_startedReported) {
          _startedReported = true;
          widget.onStarted();
        }
      case HelpTutorialPlayerEvent.ended:
        if (!_completedReported) {
          _completedReported = true;
          widget.onCompleted();
        }
      case HelpTutorialPlayerEvent.error:
        _emitStatus(_PlayerViewStatus.error);
    }
  }

  void _emitStatus(_PlayerViewStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _restart() {
    if (_restarting) {
      return;
    }
    _restarting = true;
    _emitStatus(_PlayerViewStatus.loading);
    _releaseCurrentSession();
    if (mounted) {
      _createSession();
    }
    _restarting = false;
  }

  void _releaseCurrentSession() {
    final subscription = _eventSubscription;
    final session = _session;
    _eventSubscription = null;
    _session = null;

    if (subscription != null) {
      unawaited(_ignoreCleanupError(subscription.cancel()));
    }
    if (session != null) {
      unawaited(_ignoreCleanupError(session.close()));
    }
  }

  @override
  void dispose() {
    _releaseCurrentSession();
    unawaited(_statusController.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_PlayerViewStatus>(
      stream: _statusController.stream,
      initialData: _currentStatus,
      builder: (context, snapshot) {
        return AnimatedSwitcher(
          duration: DonyDuration.base,
          switchInCurve: DonyCurve.enter,
          switchOutCurve: DonyCurve.exit,
          child: switch (snapshot.data ?? _currentStatus) {
            _PlayerViewStatus.ready => _buildPlayer(context),
            _PlayerViewStatus.loading => _buildLoading(context),
            _PlayerViewStatus.error => _PlayerErrorCard(
              onRetry: _restart,
              onOpenExternal: widget.onOpenExternal,
            ),
          },
        );
      },
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final session = _session;
    if (session == null) {
      return _buildLoading(context);
    }
    final cs = Theme.of(context).colorScheme;
    final configuration = _configuration;

    return KeyedSubtree(
      key: const ValueKey('help-tutorial-player-ready'),
      child: session.buildInline(
        frameBuilder: (player) => AspectRatio(
          key: const Key('help-tutorial-player-aspect-ratio'),
          aspectRatio: configuration.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              child: player,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      key: const ValueKey('help-tutorial-player-loading'),
      aspectRatio: _configuration.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Center(
          child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
        ),
      ),
    );
  }
}

Future<void> _ignoreCleanupError(Future<void> cleanup) async {
  try {
    await cleanup;
  } catch (_) {
    // La fermeture du WebView ne doit pas provoquer une erreur d’interface.
  }
}

class _PlayerErrorCard extends StatelessWidget {
  const _PlayerErrorCard({required this.onRetry, required this.onOpenExternal});

  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      key: const ValueKey('help-tutorial-player-error'),
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        children: [
          DonyIconContainer(
            iconAsset: 'circle-alert',
            size: DonyIconContainerSize.lg,
            backgroundColor: cs.errorLight,
            iconColor: cs.error,
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'Lecture impossible',
            style: tt.titleLarge?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Vérifie ta connexion ou ouvre la vidéo directement dans YouTube.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            label: 'Réessayer',
            iconAsset: 'refresh-cw',
            onPressed: onRetry,
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Ouvrir dans YouTube',
            iconAsset: 'external-link',
            variant: DonyButtonVariant.secondary,
            onPressed: onOpenExternal,
          ),
        ],
      ),
    );
  }
}

final class _YoutubeTutorialPlayerSession implements HelpTutorialPlayerSession {
  _YoutubeTutorialPlayerSession(this.configuration)
    : _controller = YoutubePlayerController.fromVideoId(
        videoId: configuration.videoId,
        autoPlay: configuration.autoPlay,
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
      ) {
    events = _controller.stream
        .map(_toPlayerEvent)
        .where((event) => event != null)
        .cast<HelpTutorialPlayerEvent>()
        .distinct();
  }

  final HelpTutorialPlayerConfiguration configuration;
  final YoutubePlayerController _controller;
  @override
  late final Stream<HelpTutorialPlayerEvent> events;
  bool _closed = false;

  @override
  Widget buildInline({required Widget Function(Widget player) frameBuilder}) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: configuration.aspectRatio,
      backgroundColor: Colors.black,
      builder: (context, player) => frameBuilder(player),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _controller.close();
  }
}

HelpTutorialPlayerEvent? _toPlayerEvent(YoutubePlayerValue value) {
  if (value.hasError) {
    return HelpTutorialPlayerEvent.error;
  }
  return switch (value.playerState) {
    PlayerState.playing => HelpTutorialPlayerEvent.playing,
    PlayerState.ended => HelpTutorialPlayerEvent.ended,
    _ => null,
  };
}
