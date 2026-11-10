import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
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

/// Ouvre un modal vidéo : feuille, puis lecteur si la vidéo est demandée.
abstract final class VideoModalPresenter {
  static bool _presenting = false;

  @visibleForTesting
  static void resetForTest() => _presenting = false;

  /// Se termine quand la feuille et le lecteur sont refermés.
  static Future<void> present(
    BuildContext context, {
    required VideoModalBloc bloc,
    required VideoModalCampaign campaign,
    required VideoModalTrigger trigger,
  }) async {
    if (_presenting) return;
    _presenting = true;
    void answer(VideoModalEventType event) => bloc.add(
      VideoModalAnswerRequested(
        campaign: campaign,
        trigger: trigger,
        event: event,
      ),
    );
    try {
      answer(VideoModalEventType.shown);
      final choice = await VideoModalSheet.show(context, campaign: campaign);
      switch (choice) {
        case VideoModalChoice.dismiss:
          answer(VideoModalEventType.dismissed);
        case null:
          // Fermé d'un geste : pas une réponse, seul SHOWN est compté.
          break;
        case VideoModalChoice.watch:
          answer(VideoModalEventType.opened);
          if (!context.mounted) return;
          final result = await context.push<VideoModalPlayerResult>(
            videoModalPlayerRoute,
            extra: VideoModalPlayerArgs(campaign: campaign, trigger: trigger),
          );
          if (!context.mounted || trigger.opensForm) return;
          _follow(context, result);
      }
    } finally {
      _presenting = false;
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
  /// L'appelant poursuit ensuite vers le formulaire dans tous les cas.
  static Future<void> before(
    BuildContext context,
    VideoModalTrigger trigger,
  ) async {
    final bloc = getItSafe<VideoModalBloc>();
    if (bloc == null || bloc.isClosed) return;
    final campaign = bloc.state.candidateFor({trigger});
    if (campaign == null || !isVideoModalFrontmost(context)) return;
    await VideoModalPresenter.present(
      context,
      bloc: bloc,
      campaign: campaign,
      trigger: trigger,
    );
  }
}
