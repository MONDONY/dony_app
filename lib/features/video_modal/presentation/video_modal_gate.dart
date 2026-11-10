import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/guest_access_guard.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
import 'package:dony/features/video_modal/presentation/widgets/info_modal_sheet.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_image.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Vrai si l'écran de [context] est au premier plan : aucune feuille, boîte
/// de dialogue ni page par-dessus, dans son navigateur comme dans ceux qui le
/// contiennent (branche du shell, puis navigateur racine, où vivent les
/// feuilles `DonyBottomSheet`).
bool isVideoModalFrontmost(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null) return true;
  if (!route.isCurrent) return false;
  final navigator = route.navigator;
  if (navigator == null || !navigator.mounted) return true;
  return isVideoModalFrontmost(navigator.context);
}

/// Ouvre un modal : feuille vidéo puis lecteur si la vidéo est demandée, ou
/// feuille d'information et l'action du bouton touché.
abstract final class VideoModalPresenter {
  static bool _presenting = false;

  @visibleForTesting
  static void resetForTest() => _presenting = false;

  /// Se termine quand la feuille et le lecteur sont refermés. Rend `true` si
  /// l'appelant peut poursuivre vers son formulaire ; `false` si une action
  /// d'information a déjà emmené la personne ailleurs (écran ou lien).
  static Future<bool> present(
    BuildContext context, {
    required VideoModalBloc bloc,
    required VideoModalCampaign campaign,
    required VideoModalTrigger trigger,
    @visibleForTesting ExternalUrlLauncher? launcher,
    @visibleForTesting bool Function()? hasRealSession,
    @visibleForTesting VideoModalImageLoader? imageLoader,
  }) async {
    if (_presenting) return true;
    _presenting = true;
    void answer(VideoModalEventType event, {VideoModalActionKind? kind}) =>
        bloc.add(
          VideoModalAnswerRequested(
            campaign: campaign,
            trigger: trigger,
            event: event,
            actionKind: kind,
          ),
        );
    try {
      // Image préchargée AVANT l'affichage, 3 s au plus. Échec : une
      // bannière s'affiche sans image ; une affiche ne s'affiche pas et rien
      // n'est compté (ni SHOWN ni « un modal par session »), on retentera à
      // la prochaine occasion.
      VideoModalImage? image;
      if (campaign.hasImage) {
        image = await (imageLoader ?? loadVideoModalImage)(campaign.imageUrl!);
        if (!context.mounted) return true;
        if (image == null && campaign.isPoster) return true;
        if (!isVideoModalFrontmost(context)) return true;
      }
      answer(VideoModalEventType.shown);
      if (campaign.isInfo) {
        return await _presentInfo(
          context,
          campaign: campaign,
          image: image,
          answer: answer,
          launcher: launcher,
          hasRealSession: hasRealSession,
        );
      }
      final choice = await VideoModalSheet.show(context, campaign: campaign);
      switch (choice) {
        case VideoModalChoice.dismiss:
          answer(VideoModalEventType.dismissed);
        case null:
          // Fermé d'un geste : pas une réponse, seul SHOWN est compté.
          break;
        case VideoModalChoice.watch:
          answer(VideoModalEventType.opened);
          if (!context.mounted) return true;
          final result = await context.push<VideoModalPlayerResult>(
            videoModalPlayerRoute,
            extra: VideoModalPlayerArgs(campaign: campaign, trigger: trigger),
          );
          if (!context.mounted || trigger.opensForm) return true;
          _follow(context, result);
      }
      return true;
    } finally {
      _presenting = false;
    }
  }

  static Future<bool> _presentInfo(
    BuildContext context, {
    required VideoModalCampaign campaign,
    required VideoModalImage? image,
    required void Function(VideoModalEventType, {VideoModalActionKind? kind})
    answer,
    ExternalUrlLauncher? launcher,
    bool Function()? hasRealSession,
  }) async {
    final choice = await InfoModalSheet.show(
      context,
      campaign: campaign,
      image: image,
    );
    // Fermé d'un geste : pas une réponse, seul SHOWN est compté.
    if (choice == null) return true;
    // Croix (carte centrée, plein écran) : fermeture explicite, sans action.
    if (choice == InfoModalChoice.closed) {
      answer(VideoModalEventType.dismissed, kind: VideoModalActionKind.close);
      return true;
    }
    final action = choice == InfoModalChoice.primary
        ? campaign.primaryAction
        : campaign.secondaryAction;
    if (action == null) return true;
    // Bouton principal : « touché » (OPENED) quand il mène quelque part ;
    // secondaire ou fermeture : DISMISSED.
    final opened =
        choice == InfoModalChoice.primary &&
        action.kind != VideoModalActionKind.close;
    answer(
      opened ? VideoModalEventType.opened : VideoModalEventType.dismissed,
      kind: action.kind,
    );
    if (!context.mounted) return true;
    final left = await runInfoAction(
      context,
      action,
      launcher: launcher,
      hasRealSession: hasRealSession,
    );
    return !left;
  }

  /// Exécute l'action d'un bouton. Rend `true` si la personne a quitté le
  /// parcours en cours (écran ouvert, feuille de connexion, lien externe).
  @visibleForTesting
  static Future<bool> runInfoAction(
    BuildContext context,
    VideoModalAction action, {
    ExternalUrlLauncher? launcher,
    bool Function()? hasRealSession,
  }) async {
    switch (action.kind) {
      case VideoModalActionKind.close:
        return false;
      case VideoModalActionKind.url:
        final url = Uri.tryParse(action.url ?? '');
        if (url != null) {
          // `open` ne lève jamais : un échec ne casse rien.
          await (launcher ?? ExternalUrlLauncher()).open(url);
        }
        return true;
      case VideoModalActionKind.screen:
        final screen = action.screen;
        if (screen == null) return false;
        final real =
            (hasRealSession ??
            () => getItSafe<FirebaseSessionProbe>()?.hasRealSession ?? false)();
        // Visiteur devant un écran protégé : la feuille de connexion, jamais
        // un écran cassé.
        if (!real && !GuestAccessGuard.isPublicGuestPath(screen.route)) {
          unawaited(AuthRequiredSheet.show(context));
        } else if (screen.isShellTab) {
          context.go(screen.route);
        } else {
          unawaited(context.push<Object?>(screen.route));
        }
        return true;
    }
  }

  /// Actions de fin de vidéo, hors formulaire.
  static void _follow(BuildContext context, VideoModalPlayerResult? result) {
    switch (result) {
      case VideoModalPlayerResult.search:
        context.go('/home');
      case VideoModalPlayerResult.publishTrip:
        final real = getItSafe<FirebaseSessionProbe>()?.hasRealSession ?? false;
        if (real) {
          unawaited(context.push<Object?>('/trips/publish-intro'));
        } else {
          unawaited(AuthRequiredSheet.show(context));
        }
      case VideoModalPlayerResult.closed:
      case VideoModalPlayerResult.completed:
      case null:
        break;
    }
  }
}

/// Modal posé devant un formulaire (« Publier un trajet », « Envoyer un
/// colis ») : à appeler par chaque point d'entrée, juste avant de pousser la
/// route du formulaire.
abstract final class VideoModalGate {
  /// Ouvre le modal de [trigger] s'il y en a un pour cette session, et se
  /// termine une fois le modal (et son lecteur) refermé ; aussitôt sinon.
  /// Rend `true` quand l'appelant poursuit vers le formulaire ; `false` si un
  /// modal d'information a déjà ouvert un autre écran ou un lien (le
  /// formulaire n'est alors pas poussé par-dessus).
  static Future<bool> before(
    BuildContext context,
    VideoModalTrigger trigger,
  ) async {
    final bloc = getItSafe<VideoModalBloc>();
    if (bloc == null || bloc.isClosed) return true;
    final campaign = bloc.state.candidateFor({trigger});
    if (campaign == null || !isVideoModalFrontmost(context)) return true;
    return VideoModalPresenter.present(
      context,
      bloc: bloc,
      campaign: campaign,
      trigger: trigger,
    );
  }
}
