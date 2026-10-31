import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bouton du pied collant de l'écran du trajet vu par son voyageur.
enum TripFooterButton {
  /// « Arrivé à destination » : trajet parti (`IN_PROGRESS`), un colis est
  /// remis ou en transit.
  markArrived,

  /// « Prévenir les destinataires (N) » : l'arrivée est marquée.
  notifyRecipients,

  /// « Modifier » : trajet modifiable ([canEditTrip]).
  edit,

  /// « Publier » : brouillon.
  publish,

  /// « Voir les demandes (N) » : des demandes attendent une réponse.
  seeRequests,

  /// « Partager l'affiche » : trajet ouvert aux demandes.
  sharePoster,
}

/// Pied collant : un bouton principal, et parfois un second (à gauche sur la
/// ligne, ou dessous quand les libellés ne tiennent pas côte à côte).
typedef TripFooter = ({TripFooterButton primary, TripFooterButton? secondary});

/// Statuts d'un trajet dont les colis voyagent encore.
const _travellingStatuses = {'ACTIVE', 'FULL', 'IN_PROGRESS'};

/// Pied collant de [trip] pour son voyageur, ou `null` s'il n'a rien à
/// proposer. Fonction pure, la première règle qui s'applique l'emporte :
/// 1. trajet IN_PROGRESS (parti) avec un colis remis ou en transit
///    ([tripCanMarkArrived]) : « Arrivé à destination ». Sur un trajet
///    ACTIVE ou FULL, des colis déjà remis (étape de remise, avant le
///    départ) ne le proposent pas : le pied passe aux règles suivantes ;
/// 2. trajet ACTIVE, FULL ou IN_PROGRESS dont l'arrivée est marquée (un
///    colis `ARRIVED`, plus aucun remis ni en transit,
///    [tripHasParcelsOnBoard] faux) : « Prévenir les destinataires (N) » ;
/// 3. brouillon : « Modifier » | « Publier » ;
/// 4. ACTIVE ou FULL avec des demandes à traiter
///    ([tripPendingRequestCount]) : « Voir les demandes (N) » ;
/// 5. ACTIVE sans demande à traiter : « Modifier » | « Partager l'affiche »,
///    « Modifier » seulement si le trajet est modifiable ([canEditTrip] : des
///    colis acceptés le ferment, l'affiche reste) ;
/// 6. sinon (COMPLETED, CANCELLED, REMOVED_BY_ADMIN, FULL sans demande,
///    colis remis compris, IN_PROGRESS sans colis à faire avancer, statut
///    inconnu) : aucun pied.
///
/// [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
/// tant que la liste n'a pas répondu ; les règles 1 et 2 attendent alors la
/// liste, les compteurs du modèle servent aux autres.
///
/// Le départ confirmé (« Je pars », drapeau local de `TripDepartCubit`)
/// n'entre pas dans la règle : il ne change pas le statut du trajet côté
/// back, seul `IN_PROGRESS` ouvre « Arrivé à destination ».
///
/// [answered] : demandes traitées depuis l'écran
/// ([TripBidAnswerController.answered]) ; celles que la liste montre encore
/// en attente ne comptent plus dans « Voir les demandes (N) »
/// ([tripBidsAfterAnswers], même règle que la carte et la case Demandes).
///
/// [isOwner] faux : aucun pied, comme « À traiter » et « Votre trajet ».
TripFooter? tripFooterFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required bool isOwner,
  Set<String> answered = const {},
}) {
  if (!isOwner) return null;
  if (bids != null && _travellingStatuses.contains(trip.status)) {
    if (tripCanMarkArrived(trip.status, bids)) {
      return (primary: TripFooterButton.markArrived, secondary: null);
    }
    if (!tripHasParcelsOnBoard(bids) &&
        tripHasArrivedParcel(bids) &&
        recipientsToNotify(bids).isNotEmpty) {
      return (primary: TripFooterButton.notifyRecipients, secondary: null);
    }
  }
  final canEdit = canEditTrip(trip, tripHasBids(trip, bids));
  final edit = canEdit ? TripFooterButton.edit : null;
  if (trip.status == 'DRAFT') {
    return (primary: TripFooterButton.publish, secondary: edit);
  }
  final pending = tripPendingRequestCount(
    trip,
    tripBidsAfterAnswers(bids, answered),
  );
  if ((trip.status == 'ACTIVE' || trip.status == 'FULL') && pending > 0) {
    return (primary: TripFooterButton.seeRequests, secondary: null);
  }
  if (canShareTripPoster(trip)) {
    return (primary: TripFooterButton.sharePoster, secondary: edit);
  }
  return null;
}

/// Barre collante de l'écran du trajet vu par son voyageur ([tripFooterFor]).
///
/// Un seul bouton, ou deux sur une ligne (secondaire à gauche 1/3, principal
/// à droite 2/3), comme `TravelerStickyBar` de la fiche colis. Les deux
/// libellés sont mesurés à la taille du thème et à l'échelle de texte de
/// l'appareil : s'ils ne tiennent pas sur une ligne dans leur part du bouton,
/// les boutons s'empilent en pleine largeur, le principal en haut (règle
/// « texte des boutons » : jamais de libellé rétréci par le `FittedBox` du
/// `DonyButton`).
///
/// Les actions partent du contexte de la barre, sous les blocs de l'écran :
/// - « Arrivé à destination » : `ArrivalInstructionsBottomSheet`
///   (`isEditing: false`), qui envoie `AnnouncementTripMarkArrivedRequested`
///   (position approximative jointe par le bloc) ; l'écran ouvre ensuite
///   « Prévenir les destinataires » de lui-même ;
/// - « Prévenir les destinataires (N) » : `NotifyRecipientsSheet`
///   (`source: manual`) ;
/// - « Modifier » : [openTripEdit] (relecture si l'édition enregistre) ;
/// - « Publier » : `AnnouncementPublishRequested`. KYC, date passée, limite
///   PRO et écran de succès restent gérés par l'écouteur de l'écran ;
/// - « Voir les demandes (N) » : [openTripRequests] (relecture au retour) ;
/// - « Partager l'affiche » : [openTripPoster].
class TripOwnerStickyBar extends StatelessWidget {
  const TripOwnerStickyBar({
    super.key,
    required this.trip,
    required this.bids,
    required this.isOwner,
  });

  final AnnouncementModel trip;

  /// Colis chargés par l'écran, `null` tant que la liste n'a pas répondu.
  final List<BidModel>? bids;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    // Suit les demandes traitées depuis l'écran quand le scope de réponse
    // est au-dessus (posé par l'écran au-dessus du Scaffold).
    final answered = TripBidAnswerScope.maybeOf(context)?.answered;
    if (answered == null) return _bar(context, const {});
    return ValueListenableBuilder<Set<String>>(
      valueListenable: answered,
      builder: (context, ids, _) => _bar(context, ids),
    );
  }

  Widget _bar(BuildContext context, Set<String> answered) {
    final footer = tripFooterFor(
      trip: trip,
      bids: bids,
      isOwner: isOwner,
      answered: answered,
    );
    if (footer == null) return const SizedBox.shrink();
    final pending = tripPendingRequestCount(
      trip,
      tripBidsAfterAnswers(bids, answered),
    );
    String label(TripFooterButton button) =>
        _label(context.l10n, button, pending: pending);
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    final primary = _button(
      context,
      footer.primary,
      label: label(footer.primary),
      primary: true,
    );
    final secondaryButton = footer.secondary;
    return Container(
      key: const Key('trip-owner-sticky-bar'),
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: secondaryButton == null
          ? primary
          : LayoutBuilder(
              builder: (context, constraints) {
                final secondary = _button(
                  context,
                  secondaryButton,
                  label: label(secondaryButton),
                  primary: false,
                );
                if (_fitSideBySide(
                  context,
                  constraints.maxWidth,
                  primary: label(footer.primary),
                  secondary: label(secondaryButton),
                )) {
                  return Row(
                    children: [
                      Expanded(child: secondary),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(flex: 2, child: primary),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primary,
                    const SizedBox(height: DonySpacing.sm),
                    secondary,
                  ],
                );
              },
            ),
    );
  }

  /// Les deux libellés (sans icône) tiennent-ils, à la taille du thème
  /// (`labelLarge`) et à l'échelle de texte de l'appareil, dans le contenu de
  /// leur bouton (1/3 et 2/3 de [width], moins la marge intérieure) ?
  static bool _fitSideBySide(
    BuildContext context,
    double width, {
    required String primary,
    required String secondary,
  }) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final row = width - DonySpacing.md;
    // Marge intérieure du bouton, plus 2 px pour la bordure du contour.
    const inner = 2 * DonySpacing.base + 2;
    return measure(secondary) <= row / 3 - inner &&
        measure(primary) <= row * 2 / 3 - inner;
  }

  /// Libellé de [button] ; [pending] : demandes à traiter affichées.
  String _label(
    AppLocalizations l,
    TripFooterButton button, {
    required int pending,
  }) => switch (button) {
    TripFooterButton.markArrived => l.tripOwnerMarkArrivedButton,
    TripFooterButton.notifyRecipients => l.notifyRecipientsButton(
      recipientsToNotify(bids ?? const []).length,
    ),
    TripFooterButton.edit => l.commonEdit,
    TripFooterButton.publish => l.tripOwnerPublishTile,
    TripFooterButton.seeRequests => l.listingSeeRequestsButton(pending),
    TripFooterButton.sharePoster => l.tripPosterShareButton,
  };

  Widget _button(
    BuildContext context,
    TripFooterButton button, {
    required String label,
    required bool primary,
  }) => DonyButton(
    key: Key('trip-footer-${button.name}'),
    label: label,
    // Icône seulement sur un bouton seul (« Prévenir… ») : à 1/3 ou 2/3 de
    // ligne, elle ferait rétrécir le libellé.
    iconAsset: button == TripFooterButton.notifyRecipients
        ? 'message-circle'
        : null,
    variant: primary ? DonyButtonVariant.primary : DonyButtonVariant.secondary,
    flat: true,
    onPressed: () => _act(context, button),
  );

  void _act(BuildContext context, TripFooterButton button) {
    switch (button) {
      case TripFooterButton.markArrived:
        unawaited(
          ArrivalInstructionsBottomSheet.show(
            context,
            announcementId: trip.id,
            initialInstructions: trip.arrivalInstructions,
          ),
        );
      case TripFooterButton.notifyRecipients:
        unawaited(
          NotifyRecipientsSheet.show(
            context,
            bids: bids ?? const [],
            source: NotifyRecipientsSource.manual,
            instructions: trip.arrivalInstructions,
          ),
        );
      case TripFooterButton.edit:
        unawaited(openTripEdit(context, trip));
      case TripFooterButton.publish:
        context.read<AnnouncementBloc>().add(
          AnnouncementPublishRequested(trip.id),
        );
      case TripFooterButton.seeRequests:
        unawaited(openTripRequests(context, trip.id));
      case TripFooterButton.sharePoster:
        openTripPoster(context, trip);
    }
  }
}
