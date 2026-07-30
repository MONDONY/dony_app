part of 'help_center_bloc.dart';

sealed class HelpCenterEvent extends Equatable {
  const HelpCenterEvent();
}

final class HelpCenterLoadRequested extends HelpCenterEvent {
  const HelpCenterLoadRequested();

  @override
  List<Object?> get props => const [];
}

final class HelpCenterOpenRequested extends HelpCenterEvent {
  const HelpCenterOpenRequested();

  @override
  List<Object?> get props => const [];
}

final class HelpTutorialOpenRequested extends HelpCenterEvent {
  const HelpTutorialOpenRequested({
    required this.tutorialId,
    required this.source,
  });

  final String tutorialId;
  final TutorialContext? source;

  @override
  List<Object?> get props => [tutorialId, source];
}

enum HelpPlaybackAction { started, completed }

final class HelpTutorialPlaybackRequested extends HelpCenterEvent {
  const HelpTutorialPlaybackRequested({
    required this.tutorialId,
    required this.action,
  });

  final String tutorialId;
  final HelpPlaybackAction action;

  @override
  List<Object?> get props => [tutorialId, action];
}

enum HelpExternalTarget { tutorial, social, youtubeSubscription }

final class HelpExternalOpenRequested extends HelpCenterEvent {
  const HelpExternalOpenRequested._({
    required this.uri,
    required this.target,
    this.tutorialId,
    this.network,
    this.source,
  });

  factory HelpExternalOpenRequested.tutorial({
    required Uri uri,
    required String tutorialId,
  }) {
    return HelpExternalOpenRequested._(
      uri: uri,
      target: HelpExternalTarget.tutorial,
      tutorialId: tutorialId,
    );
  }

  factory HelpExternalOpenRequested.social({required SocialLink link}) {
    return HelpExternalOpenRequested._(
      uri: link.url,
      target: HelpExternalTarget.social,
      network: link.network,
    );
  }

  factory HelpExternalOpenRequested.youtubeSubscription({
    required Uri uri,
    required TutorialContext? source,
  }) {
    return HelpExternalOpenRequested._(
      uri: uri,
      target: HelpExternalTarget.youtubeSubscription,
      source: source,
    );
  }

  final Uri uri;
  final HelpExternalTarget target;
  final String? tutorialId;
  final SocialNetwork? network;
  final TutorialContext? source;

  @override
  List<Object?> get props => [uri, target, tutorialId, network, source];
}
