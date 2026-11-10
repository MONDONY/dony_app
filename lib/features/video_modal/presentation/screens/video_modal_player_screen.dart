import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/bloc/video_modal_player_cubit.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route du lecteur plein écran d'un modal vidéo (`extra` : [VideoModalPlayerArgs]).
const videoModalPlayerRoute = '/video-modal/player';

class VideoModalPlayerArgs {
  const VideoModalPlayerArgs({required this.campaign, required this.trigger});

  final VideoModalCampaign campaign;
  final VideoModalTrigger trigger;
}

/// Comment le lecteur s'est refermé : l'appelant enchaîne (formulaire,
/// recherche, publication).
enum VideoModalPlayerResult { closed, completed, search, publishTrip }

/// Lecteur plein écran, le même que celui des tutoriels (`youtube_player_iframe`
/// via [HelpTutorialPlayerSession]). À la fin de la vidéo : deux actions pour
/// démarrer, sauf devant un formulaire (« Publier un trajet », « Envoyer un
/// colis »), où le lecteur se referme seul pour continuer vers le formulaire.
class VideoModalPlayerScreen extends StatefulWidget {
  const VideoModalPlayerScreen({
    super.key,
    required this.args,
    required this.modalBloc,
    this.sessionFactory = createYoutubeTutorialPlayerSession,
  });

  final VideoModalPlayerArgs args;
  final VideoModalBloc modalBloc;
  final HelpTutorialPlayerSessionFactory sessionFactory;

  @override
  State<VideoModalPlayerScreen> createState() => _VideoModalPlayerScreenState();
}

class _VideoModalPlayerScreenState extends State<VideoModalPlayerScreen> {
  late final VideoModalPlayerCubit _cubit = VideoModalPlayerCubit(
    modalBloc: widget.modalBloc,
    campaign: widget.args.campaign,
    trigger: widget.args.trigger,
  );
  HelpTutorialPlayerSession? _session;
  StreamSubscription<HelpTutorialPlayerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    try {
      final session = widget.sessionFactory(
        HelpTutorialPlayerConfiguration(
          videoId: widget.args.campaign.youtubeVideoId,
        ),
      );
      _session = session;
      _subscription = session.events.listen(
        _cubit.onPlayerEvent,
        onError: (_, _) => _cubit.fail(),
      );
    } on Object {
      _cubit.fail();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final session = _session;
    _session = null;
    if (session != null) {
      unawaited(session.close().catchError((Object _) {}));
    }
    unawaited(_cubit.close());
    super.dispose();
  }

  void _close(VideoModalPlayerResult result) {
    if (context.canPop()) context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<VideoModalPlayerCubit, VideoModalPlayerStatus>(
        listenWhen: (_, s) =>
            s == VideoModalPlayerStatus.ended && widget.args.trigger.opensForm,
        listener: (_, _) => _close(VideoModalPlayerResult.completed),
        child: Theme(
          data: AppTheme.dark(),
          child: session == null
              ? _VideoModalPlayerPage(args: widget.args, onClose: _close)
              : session.buildScaffold(
                  pageBuilder: (player) => _VideoModalPlayerPage(
                    args: widget.args,
                    onClose: _close,
                    player: player,
                  ),
                ),
        ),
      ),
    );
  }
}

class _VideoModalPlayerPage extends StatelessWidget {
  const _VideoModalPlayerPage({
    required this.args,
    required this.onClose,
    this.player,
  });

  final VideoModalPlayerArgs args;
  final ValueChanged<VideoModalPlayerResult> onClose;
  final Widget? player;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return BlocBuilder<VideoModalPlayerCubit, VideoModalPlayerStatus>(
      builder: (context, status) {
        final ended = status == VideoModalPlayerStatus.ended;
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.sm,
                    DonySpacing.sm,
                    DonySpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          args.campaign.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('video-modal-player-close'),
                        onPressed: () => onClose(
                          ended
                              ? VideoModalPlayerResult.completed
                              : VideoModalPlayerResult.closed,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                        ),
                        child: Text(l.commonClose, maxLines: 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ?player,
                          if (status == VideoModalPlayerStatus.loading)
                            const ColoredBox(
                              key: Key('video-modal-player-loading'),
                              color: Colors.black,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          if (status == VideoModalPlayerStatus.error)
                            ColoredBox(
                              key: const Key('video-modal-player-error'),
                              color: Colors.black,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(DonySpacing.lg),
                                  child: Text(
                                    l.videoModalPlayerError,
                                    textAlign: TextAlign.center,
                                    style: tt.bodyMedium?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (ended && !args.trigger.opensForm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      0,
                      DonySpacing.lg,
                      DonySpacing.base,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DonyButton(
                          key: const Key('video-modal-end-search'),
                          label: l.videoModalPlayerEndSearch,
                          onPressed: () =>
                              onClose(VideoModalPlayerResult.search),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        DonyButton(
                          key: const Key('video-modal-end-publish'),
                          label: l.videoModalPlayerEndPublish,
                          variant: DonyButtonVariant.secondary,
                          onPressed: () =>
                              onClose(VideoModalPlayerResult.publishTrip),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
