import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Outils communs aux bottom sheets de l'écran du trajet (« À traiter » et
// « Votre trajet ») : un sheet reste ouvert pendant les rechargements de
// l'écran et suit les données relues par ses blocs.

/// Le trajet porté par [state] s'il s'agit de [id], sinon `null` (états
/// sans trajet : chargement, erreur, suppression…).
AnnouncementModel? tripAnnouncementIn(AnnouncementState state, String id) {
  final a = switch (state) {
    AnnouncementDetailLoaded(:final announcement) ||
    AnnouncementUpdated(:final announcement) ||
    AnnouncementPublished(:final announcement) ||
    AnnouncementTripArrived(:final announcement) ||
    AnnouncementArrivalInstructionsUpdated(:final announcement) ||
    AnnouncementRescheduled(:final announcement) => announcement,
    _ => null,
  };
  return a?.id == id ? a : null;
}

/// Suit le bloc [B] quand il est [present] : ne reconstruit que pour un état
/// dont [select] tire une valeur, et rend la dernière connue (`null` tant
/// qu'aucune ne l'a été). Absent : `null`.
Widget followBloc<B extends StateStreamable<S>, S, V extends Object>({
  required bool present,
  required V? Function(S state) select,
  required Widget Function(BuildContext context, V? value) builder,
}) {
  if (!present) return Builder(builder: (context) => builder(context, null));
  return BlocBuilder<B, S>(
    buildWhen: (_, state) => select(state) != null,
    builder: (context, state) => builder(context, select(state)),
  );
}

/// Ferme le sheet dès que [gone] (les données relues ne justifient plus sa
/// tuile) et que le sheet est au premier plan (`ModalRoute.isCurrentOf` :
/// reconstruit quand une confirmation ouverte par-dessus se referme, jamais
/// refermée à sa place).
class CloseTripSheetWhenGone extends StatelessWidget {
  const CloseTripSheetWhenGone({
    super.key,
    required this.gone,
    required this.child,
  });

  final bool gone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTop = ModalRoute.isCurrentOf(context) ?? false;
    if (onTop && gone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) closeSheetIfOnTop(context);
      });
    }
    return child;
  }
}
