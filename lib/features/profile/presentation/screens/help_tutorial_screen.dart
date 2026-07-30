import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';

const _youtubeWatchHost = 'www.youtube.com';

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
        return switch ((state, tutorial)) {
          (HelpCenterInitial() || HelpCenterLoading(), _) =>
            const DonyPageScaffold(
              title: 'Tutoriel vidéo',
              scrollable: false,
              body: DonyEmptyState(type: DonyEmptyStateType.loading, title: ''),
            ),
          (_, null) => const DonyPageScaffold(
            title: 'Tutoriel vidéo',
            scrollable: false,
            body: DonyEmptyState(
              title: 'Tutoriel introuvable',
              description: 'Ce tutoriel n’est plus disponible.',
              iconAsset: 'circle-help',
            ),
          ),
          (_, final tutorial?) => _HelpTutorialExperience(
            key: ValueKey(tutorial.id),
            tutorial: tutorial,
            youtubeChannelUrl: config?.youtubeChannelUrl,
            sessionFactory: playerSessionFactory,
          ),
        };
      },
    );
  }
}

class _HelpTutorialContent extends StatelessWidget {
  const _HelpTutorialContent({
    required this.tutorial,
    required this.youtubeChannelUrl,
    required this.playerArea,
  });

  final HelpTutorial tutorial;
  final Uri? youtubeChannelUrl;
  final Widget playerArea;

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
        playerArea,
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

class _HelpTutorialExperience extends StatefulWidget {
  const _HelpTutorialExperience({
    super.key,
    required this.tutorial,
    required this.youtubeChannelUrl,
    required this.sessionFactory,
  });

  final HelpTutorial tutorial;
  final Uri? youtubeChannelUrl;
  final HelpTutorialPlayerSessionFactory sessionFactory;

  @override
  State<_HelpTutorialExperience> createState() =>
      _HelpTutorialExperienceState();
}

class _HelpTutorialExperienceState extends State<_HelpTutorialExperience> {
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
  void didUpdateWidget(_HelpTutorialExperience oldWidget) {
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
        onError: (_, _) => _handlePlayerFailure(),
        onDone: () {
          if (_session != null) {
            _handlePlayerFailure();
          }
        },
      );
    } catch (_) {
      _emitStatus(_PlayerViewStatus.error);
    }
  }

  void _onPlayerEvent(HelpTutorialPlayerEvent event) {
    switch (event) {
      case HelpTutorialPlayerEvent.ready:
        _emitStatus(_PlayerViewStatus.ready);
      case HelpTutorialPlayerEvent.playing:
        if (_currentStatus == _PlayerViewStatus.loading) {
          _emitStatus(_PlayerViewStatus.ready);
        }
        if (!_startedReported) {
          _startedReported = true;
          context.read<HelpCenterBloc>().add(
            HelpTutorialPlaybackRequested(
              tutorialId: widget.tutorial.id,
              action: HelpPlaybackAction.started,
            ),
          );
        }
      case HelpTutorialPlayerEvent.ended:
        if (!_completedReported) {
          _completedReported = true;
          context.read<HelpCenterBloc>().add(
            HelpTutorialPlaybackRequested(
              tutorialId: widget.tutorial.id,
              action: HelpPlaybackAction.completed,
            ),
          );
        }
      case HelpTutorialPlayerEvent.error:
        _handlePlayerFailure();
    }
  }

  void _handlePlayerFailure() {
    if (_currentStatus == _PlayerViewStatus.error && _session == null) {
      return;
    }
    _releaseCurrentSession();
    _emitStatus(_PlayerViewStatus.error);
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
        final status = snapshot.data ?? _currentStatus;
        final session = _session;
        if (session == null) {
          return _buildPage(context, status: status);
        }
        return session.buildScaffold(
          pageBuilder: (player) =>
              _buildPage(context, status: status, player: player),
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required _PlayerViewStatus status,
    Widget? player,
  }) {
    return DonyPageScaffold(
      title: 'Tutoriel vidéo',
      body: _HelpTutorialContent(
        tutorial: widget.tutorial,
        youtubeChannelUrl: widget.youtubeChannelUrl,
        playerArea: AnimatedSwitcher(
          duration: DonyDuration.base,
          switchInCurve: DonyCurve.enter,
          switchOutCurve: DonyCurve.exit,
          child: switch (status) {
            _PlayerViewStatus.error => _PlayerErrorCard(
              onRetry: _restart,
              onOpenExternal: _openExternal,
            ),
            _PlayerViewStatus.loading || _PlayerViewStatus.ready =>
              _buildPlayerFrame(context, player: player, status: status),
          },
        ),
      ),
    );
  }

  Widget _buildPlayerFrame(
    BuildContext context, {
    required Widget? player,
    required _PlayerViewStatus status,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('help-tutorial-player-frame'),
      container: true,
      label: 'Lecteur vidéo : ${widget.tutorial.title}',
      child: AspectRatio(
        key: const Key('help-tutorial-player-aspect-ratio'),
        aspectRatio: _configuration.aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ?player,
                if (status == _PlayerViewStatus.loading)
                  ColoredBox(
                    key: const ValueKey('help-tutorial-player-loading'),
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: cs.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openExternal() {
    context.read<HelpCenterBloc>().add(
      HelpExternalOpenRequested.tutorial(
        uri: Uri.https(_youtubeWatchHost, '/watch', {
          'v': widget.tutorial.youtubeVideoId,
        }),
        tutorialId: widget.tutorial.id,
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
