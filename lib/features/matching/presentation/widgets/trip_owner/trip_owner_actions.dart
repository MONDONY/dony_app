import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Actions du voyageur sur son trajet, communes au pied collant et au menu ⋮
// de l'écran du trajet. Chacune agit depuis [context],
// le contexte de l'écran : il porte l'`AnnouncementBloc`, le `BidBloc` et le
// `CancellationBloc` de la route, dont les écouteurs de l'écran tirent les
// suites (snackbar, rechargement, sortie de l'écran).

/// Statuts de colis qui interdisent de reporter le trajet.
const _rescheduleBlockingStatuses = {'IN_TRANSIT', 'ARRIVED', 'COMPLETED'};

/// Le trajet peut-il être reporté (vol annulé, voyage repoussé) ? Là où
/// « Modifier » est bloqué par des demandes ou des colis ([hasBids]), sur un
/// trajet encore à venir, complet ou passé « en cours ».
bool tripCanReschedule(AnnouncementModel trip, bool hasBids) =>
    hasBids && const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(trip.status);

/// Pourquoi le report d'un trajet reportable ([tripCanReschedule]) est
/// verrouillé.
enum TripRescheduleBlock {
  /// Un colis est en route, arrivé ou livré : le voyage a eu lieu
  /// (FLUTTER-BD). Même règle que le back (`TripRescheduleRules`), qui refuse
  /// de toute façon.
  parcelOnTheWay,

  /// Les deux reports permis sont déjà faits (`remainingReschedules == 0` ;
  /// `null`, back ancien, laisse ouvert).
  limitReached,
}

/// Verrou du report de [trip] d'après ses colis chargés ([bids], `null` tant
/// que la liste n'a pas répondu), ou `null` si le report est ouvert.
TripRescheduleBlock? tripRescheduleBlockFor(
  AnnouncementModel trip,
  List<BidModel>? bids,
) {
  if (bids?.any((b) => _rescheduleBlockingStatuses.contains(b.status)) ??
      false) {
    return TripRescheduleBlock.parcelOnTheWay;
  }
  if (trip.remainingReschedules == 0) return TripRescheduleBlock.limitReached;
  return null;
}

/// Phrase qui explique le verrou [block].
String tripRescheduleBlockMessage(
  AppLocalizations l,
  TripRescheduleBlock block,
) => switch (block) {
  TripRescheduleBlock.parcelOnTheWay => l.tripRescheduleParcelOnTheWayMessage,
  TripRescheduleBlock.limitReached => l.tripRescheduleLimitReachedMessage,
};

/// « Dépublier » : confirmation, puis `AnnouncementUnpublishRequested`. Le
/// trajet relu (`AnnouncementUpdated`) est repris par l'écran.
Future<void> confirmTripUnpublish(
  BuildContext context,
  AnnouncementModel trip,
) async {
  final l = context.l10n;
  final confirmed = await DonyDialog.show(
    context,
    title: l.tripOwnerUnpublishDialogTitle,
    message: l.tripOwnerUnpublishDialogMessage,
    confirmLabel: l.tripOwnerUnpublishTile,
    iconAsset: 'eye-off',
  );
  if (confirmed == true && context.mounted) {
    context.read<AnnouncementBloc>().add(
      AnnouncementUnpublishRequested(trip.id),
    );
  }
}

/// « Supprimer » : confirmation, question sur les étapes suivantes d'un voyage
/// à plusieurs étapes ([askCancelFollowingLegs], FLUTTER-4D), puis
/// `AnnouncementDeleteRequested`. L'écran sort à la suppression ; un colis
/// accepté (409) lui fait proposer l'annulation.
Future<void> confirmTripDelete(
  BuildContext context,
  AnnouncementModel trip,
) async {
  final l = context.l10n;
  final confirmed = await DonyDialog.show(
    context,
    title: l.tripOwnerDeleteDialogTitle,
    message: trip.status == 'CANCELLED'
        ? l.tripOwnerDeleteCancelledMessage
        : l.tripOwnerDeleteActiveMessage,
    confirmLabel: l.commonDelete,
    variant: DonyDialogVariant.destructive,
    iconAsset: 'trash-2',
  );
  if (confirmed != true || !context.mounted) return;
  final following = await askCancelFollowingLegs(context, trip.id);
  if (!context.mounted || following == null) return;
  context.read<AnnouncementBloc>().add(
    AnnouncementDeleteRequested(trip.id, followingLegIds: following),
  );
}

/// « Annuler le voyage » : feuille d'annulation, avec le nombre de colis déjà
/// remis ([tripHandedOverParcelCount]) pour qu'elle annonce leur retour
/// (piège n°6 de l'inventaire : l'ancienne grille d'actions ne le passait
/// pas).
/// L'écran écoute le `CancellationBloc` (snackbar, relecture, FLUTTER-FH).
Future<void> openTripCancellation(
  BuildContext context,
  AnnouncementModel trip,
  List<BidModel>? bids,
) => CancellationBottomSheet.show(
  context,
  announcementId: trip.id,
  handedOverParcels: tripHandedOverParcelCount(bids),
);

/// Attente bornée des étapes du voyage avant la question des étapes
/// suivantes ([askCancelFollowingLegs]) : au-delà, la question se pose sur ce
/// qui est connu.
const kTripLegsSettleTimeout = Duration(seconds: 5);

/// Voyage à plusieurs étapes (FLUTTER-4D) : avant d'annuler une étape,
/// propose d'annuler aussi les suivantes encore ouvertes.
///
/// Rend les identifiants à annuler en plus (vide : les garder), ou `null` si
/// le voyageur a fermé la question sans choisir. Sans [TripGroupCubit] dans
/// l'arbre, ou pour un trajet isolé, rend une liste vide sans rien demander.
///
/// Les étapes ne sont lues qu'une fois tranchées (`loaded` ou `hidden`) : un
/// cubit pas encore chargé (créé à la volée, réseau lent) aurait encore
/// l'état vide de départ, et la question serait sautée sans bruit (les étapes
/// suivantes restaient publiées). Un cubit jamais chargé est lancé sur
/// [announcementId] ; l'attente est bornée par [kTripLegsSettleTimeout].
Future<List<String>?> askCancelFollowingLegs(
  BuildContext context,
  String announcementId,
) async {
  final cubit = maybeRead<TripGroupCubit>(context);
  if (cubit == null) return const [];
  final state = await _settledLegs(cubit, announcementId);
  if (!context.mounted) return null;
  final following = state.info.openLegsAfter(announcementId);
  if (following.isEmpty) return const [];
  final l = context.l10n;
  final cancelThem = await DonyDialog.show(
    context,
    title: l.tripLegsCancelFollowingTitle,
    message: l.tripLegsCancelFollowingMessage(following.length),
    confirmLabel: l.tripLegsCancelFollowingConfirm,
    cancelLabel: l.tripLegsCancelFollowingKeep,
    variant: DonyDialogVariant.destructive,
    icon: Icons.alt_route_rounded,
  );
  if (cancelThem == null) return null;
  return cancelThem ? following.map((leg) => leg.id).toList() : const [];
}

/// État des étapes de [cubit] une fois tranché, ou le dernier connu après
/// [kTripLegsSettleTimeout] (ou si le cubit se ferme avant).
Future<TripGroupState> _settledLegs(
  TripGroupCubit cubit,
  String announcementId,
) async {
  bool settled(TripGroupState s) =>
      s.status == TripGroupStatus.loaded || s.status == TripGroupStatus.hidden;
  if (settled(cubit.state)) return cubit.state;
  if (cubit.state.status == TripGroupStatus.initial) {
    unawaited(cubit.load(announcementId));
  }
  try {
    return await cubit.stream
        .firstWhere(settled)
        .timeout(kTripLegsSettleTimeout);
  } on TimeoutException {
    return cubit.state;
  } on StateError {
    // Flux fermé sans état tranché.
    return cubit.state;
  }
}
