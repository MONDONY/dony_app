import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bouton du pied collant de l'écran du trajet vu par son voyageur.
enum TripFooterButton {
  /// L'action « À traiter » la plus urgente qui peut porter le pied
  /// ([tripFooterTodo] : une urgente, ou « Arrivé à destination », « Je
  /// pars », « Valider la remise », « Prévenir les destinataires », les
  /// instructions de retrait, « Publier ») : même libellé et même geste que
  /// le bouton de sa carte ([tripTodoButton], [openTripTodoAction]).
  todo,

  /// « Modifier » : trajet modifiable ([canEditTrip]).
  edit,

  /// « Voir les demandes (N) » : des demandes attendent une réponse sans
  /// être une action « À traiter » (cartes pas encore payées, date limite de
  /// dépôt passée, liste pas encore chargée avec `pendingBidCount`).
  seeRequests,

  /// « Partager l'affiche » : trajet ouvert aux demandes.
  sharePoster,
}

/// Pied collant : un bouton principal, et parfois un second (à gauche sur la
/// ligne, ou dessous quand les libellés ne tiennent pas côte à côte).
typedef TripFooter = ({TripFooterButton primary, TripFooterButton? secondary});

/// Pied collant de [trip] pour son voyageur, ou `null` s'il n'a rien à
/// proposer. Fonction pure, la première règle qui s'applique l'emporte :
/// 1. une action « À traiter » qui peut porter le pied ([todo], déjà triée,
///    `tripTodoFor` ; la première selon [tripFooterTodo] : jamais « Ajouter
///    la carte », « Noter », le destinataire refusé ni le code de retrait à
///    renouveler, qui laissent les règles suivantes s'appliquer) : le
///    bouton principal est celle-là ([TripFooterButton.todo]). Le second
///    reste celui des règles d'avant : « Modifier » (si [canEditTrip]) sur
///    un brouillon, ou sur un trajet ACTIVE sans demande à traiter ; aucun
///    quand l'arrivée est à marquer ou les destinataires à prévenir
///    ([tripCanMarkArrived], [tripRecipientsToNotifyDue]) ni quand des
///    demandes attendent ;
/// 2. ACTIVE ou FULL avec des demandes à traiter
///    ([tripPendingRequestCount]) qui ne sont pas une action « À traiter »
///    (cartes pas encore payées, date limite de dépôt passée, liste pas
///    encore chargée) : « Voir les demandes (N) » ;
/// 3. ACTIVE : « Modifier » | « Partager l'affiche », « Modifier » seulement
///    si le trajet est modifiable ([canEditTrip] : des colis acceptés le
///    ferment, l'affiche reste) ;
/// 4. sinon (FULL, COMPLETED, CANCELLED, REMOVED_BY_ADMIN, IN_PROGRESS sans
///    rien à traiter, statut inconnu) : aucun pied.
///
/// [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
/// tant que la liste n'a pas répondu.
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
  List<TripTodoItem> todo = const [],
}) {
  if (!isOwner) return null;
  final canEdit = canEditTrip(trip, tripHasBids(trip, bids));
  final edit = canEdit ? TripFooterButton.edit : null;
  final pending = tripPendingRequestCount(
    trip,
    tripBidsAfterAnswers(bids, answered),
  );
  final requestsWaiting =
      (trip.status == 'ACTIVE' || trip.status == 'FULL') && pending > 0;
  if (tripFooterTodo(todo) != null) {
    final arrivalStep =
        bids != null &&
        (tripCanMarkArrived(trip.status, bids) ||
            tripRecipientsToNotifyDue(trip.status, bids));
    final keepsEdit =
        !arrivalStep &&
        (trip.status == 'DRAFT' ||
            (!requestsWaiting && canShareTripPoster(trip)));
    return (primary: TripFooterButton.todo, secondary: keepsEdit ? edit : null);
  }
  if (requestsWaiting) {
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
/// - l'action « À traiter » en tête : [openTripTodoAction] (`source:
///   footer`), le geste de sa grosse carte ;
/// - « Modifier » : [openTripEdit] (relecture si l'édition enregistre) ;
/// - « Voir les demandes (N) » : [openTripRequests] (relecture au retour) ;
/// - « Partager l'affiche » : [openTripPoster].
///
/// La file « À traiter » est recalculée ici sur les mêmes données que le
/// corps ([TripTodoLiveData.todo] : trajet, colis, [departed], [stripe],
/// demandes traitées depuis l'écran) : le pied et la grosse carte suivent
/// toujours la même action.
class TripOwnerStickyBar extends StatelessWidget {
  const TripOwnerStickyBar({
    super.key,
    required this.trip,
    required this.bids,
    required this.isOwner,
    this.departed = false,
    this.stripe = const StripeAccountInitial(),
  });

  final AnnouncementModel trip;

  /// Colis chargés par l'écran, `null` tant que la liste n'a pas répondu.
  final List<BidModel>? bids;
  final bool isOwner;

  /// « Je pars » déjà confirmé depuis cet appareil (`TripDepartCubit`).
  final bool departed;

  /// Compte de paiement par carte (`StripeAccountBloc`).
  final StripeAccountState stripe;

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
    final live = TripTodoLiveData(
      trip: trip,
      bids: bids,
      departed: departed,
      stripe: stripe,
    );
    final todo = isOwner
        ? live.todo(answered: answered)
        : const <TripTodoItem>[];
    final footer = tripFooterFor(
      trip: trip,
      bids: bids,
      isOwner: isOwner,
      answered: answered,
      todo: todo,
    );
    if (footer == null) return const SizedBox.shrink();
    final pending = tripPendingRequestCount(
      trip,
      tripBidsAfterAnswers(bids, answered),
    );
    final first = tripFooterTodo(todo);
    String label(TripFooterButton button) => _label(
      context.l10n,
      button,
      pending: pending,
      todo: first,
      cardReady: live.cardReady,
    );
    void act(TripFooterButton button) =>
        _act(context, button, live: live, todo: first);
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    final primary = _button(
      footer.primary,
      label: label(footer.primary),
      primary: true,
      todo: first,
      onPressed: () => act(footer.primary),
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
                  secondaryButton,
                  label: label(secondaryButton),
                  primary: false,
                  todo: first,
                  onPressed: () => act(secondaryButton),
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

  /// Libellé de [button] ; [pending] : demandes à traiter affichées ;
  /// [todo] : action en tête de la file.
  String _label(
    AppLocalizations l,
    TripFooterButton button, {
    required int pending,
    required TripTodoItem? todo,
    required bool cardReady,
  }) => switch (button) {
    TripFooterButton.todo => tripTodoButton(l, todo!, cardReady: cardReady),
    TripFooterButton.edit => l.commonEdit,
    TripFooterButton.seeRequests => l.listingSeeRequestsButton(pending),
    TripFooterButton.sharePoster => l.tripPosterShareButton,
  };

  Widget _button(
    TripFooterButton button, {
    required String label,
    required bool primary,
    required TripTodoItem? todo,
    required VoidCallback onPressed,
  }) => DonyButton(
    key: Key(
      button == TripFooterButton.todo
          ? 'trip-footer-todo-${todo!.kind.name}'
          : 'trip-footer-${button.name}',
    ),
    label: label,
    // Icône seulement sur « Prévenir les destinataires », toujours seul : à
    // 1/3 ou 2/3 de ligne, elle ferait rétrécir le libellé.
    iconAsset:
        button == TripFooterButton.todo && todo?.kind == TripTodoKind.notify
        ? 'message-circle'
        : null,
    variant: primary ? DonyButtonVariant.primary : DonyButtonVariant.secondary,
    flat: true,
    onPressed: onPressed,
  );

  void _act(
    BuildContext context,
    TripFooterButton button, {
    required TripTodoLiveData live,
    required TripTodoItem? todo,
  }) {
    switch (button) {
      case TripFooterButton.todo:
        unawaited(
          openTripTodoAction(
            context,
            live,
            todo!,
            source: TripTodoSource.footer,
          ),
        );
      case TripFooterButton.edit:
        unawaited(openTripEdit(context, trip));
      case TripFooterButton.seeRequests:
        unawaited(openTripRequests(context, trip.id));
      case TripFooterButton.sharePoster:
        openTripPoster(context, trip);
    }
  }
}
