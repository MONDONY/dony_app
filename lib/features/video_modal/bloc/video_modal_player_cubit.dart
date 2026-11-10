import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum VideoModalPlayerStatus { loading, ready, ended, error }

/// État du lecteur plein écran d'un modal vidéo. Signale `COMPLETED` au
/// [VideoModalBloc] la première fois que la vidéo arrive au bout.
class VideoModalPlayerCubit extends Cubit<VideoModalPlayerStatus> {
  VideoModalPlayerCubit({
    required VideoModalBloc modalBloc,
    required this.campaign,
    required this.trigger,
  }) : _modalBloc = modalBloc,
       super(VideoModalPlayerStatus.loading);

  final VideoModalBloc _modalBloc;
  final VideoModalCampaign campaign;
  final VideoModalTrigger trigger;
  bool _completedReported = false;

  void onPlayerEvent(HelpTutorialPlayerEvent event) {
    switch (event) {
      case HelpTutorialPlayerEvent.ready:
        if (state == VideoModalPlayerStatus.loading) {
          emit(VideoModalPlayerStatus.ready);
        }
      case HelpTutorialPlayerEvent.playing:
        emit(VideoModalPlayerStatus.ready);
      case HelpTutorialPlayerEvent.ended:
        if (!_completedReported) {
          _completedReported = true;
          if (!_modalBloc.isClosed) {
            _modalBloc.add(
              VideoModalAnswerRequested(
                campaign: campaign,
                trigger: trigger,
                event: VideoModalEventType.completed,
              ),
            );
          }
        }
        emit(VideoModalPlayerStatus.ended);
      case HelpTutorialPlayerEvent.error:
        fail();
    }
  }

  /// Le lecteur ne peut pas démarrer (WebView, réseau, vidéo privée).
  void fail() {
    if (state != VideoModalPlayerStatus.ended) {
      emit(VideoModalPlayerStatus.error);
    }
  }
}
