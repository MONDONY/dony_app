import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:equatable/equatable.dart';

sealed class VideoModalEvent extends Equatable {
  const VideoModalEvent();

  @override
  List<Object?> get props => [];
}

/// Charge les campagnes éligibles, une fois par session et par type de
/// session (visiteur ou compte) et langue. Avec un compte, envoie d'abord les
/// réponses faites sans compte.
final class VideoModalLoadRequested extends VideoModalEvent {
  const VideoModalLoadRequested({
    required this.lang,
    required this.realSession,
  });

  final String lang;
  final bool realSession;

  @override
  List<Object?> get props => [lang, realSession];
}

/// Le déclencheur `APP_OPEN` a été évalué : il ne vaut qu'une fois.
final class VideoModalAppOpenConsumedRequested extends VideoModalEvent {
  const VideoModalAppOpenConsumedRequested();
}

/// Réponse ou affichage d'un modal.
final class VideoModalAnswerRequested extends VideoModalEvent {
  const VideoModalAnswerRequested({
    required this.campaign,
    required this.trigger,
    required this.event,
    this.actionKind,
  });

  final VideoModalCampaign campaign;
  final VideoModalTrigger trigger;
  final VideoModalEventType event;

  /// Action du bouton touché, pour un modal d'information seulement.
  final VideoModalActionKind? actionKind;

  @override
  List<Object?> get props => [campaign, trigger, event, actionKind];
}
