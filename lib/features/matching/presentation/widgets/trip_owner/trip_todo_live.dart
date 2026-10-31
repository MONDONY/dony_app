import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:flutter/widgets.dart';

/// Blocs de l'écran du trajet dont dépendent les tuiles « À traiter » :
/// trajet relu, colis du trajet, compte de paiement par carte, « Je pars ».
/// Chacun peut manquer (tests, écran sans ce bloc) : la valeur de départ
/// tient alors lieu de donnée.
class TripTodoBlocs {
  const TripTodoBlocs({
    required this.announcement,
    required this.bids,
    required this.stripe,
    required this.depart,
  });

  /// Les blocs fournis au-dessus de [context] (`maybeRead`).
  factory TripTodoBlocs.of(BuildContext context) => TripTodoBlocs(
    announcement: maybeRead<AnnouncementBloc>(context),
    bids: maybeRead<BidBloc>(context),
    stripe: maybeRead<StripeAccountBloc>(context),
    depart: maybeRead<TripDepartCubit>(context),
  );

  final AnnouncementBloc? announcement;
  final BidBloc? bids;
  final StripeAccountBloc? stripe;
  final TripDepartCubit? depart;
}

/// Dernières données connues des tuiles « À traiter » du trajet.
class TripTodoLiveData {
  const TripTodoLiveData({
    required this.trip,
    required this.bids,
    required this.departed,
    required this.stripe,
  });

  /// Dernier trajet relu par l'écran, à défaut celui de départ.
  final AnnouncementModel trip;

  /// Derniers colis chargés (`BidListLoaded`), `null` tant que la liste n'a
  /// jamais répondu. Un rechargement (`BidLoading`, erreur) garde la
  /// dernière liste : la tuile `requests` ne retombe pas sur
  /// `pendingBidCount`, que le détail ne sert pas.
  final List<BidModel>? bids;
  final bool departed;
  final StripeAccountState stripe;

  int get pendingCount => tripPendingRequestCount(trip, bids);
  bool get cardReady => tripCardPaymentsReady(stripe);

  List<TripTodoTile> get tiles => tripTodoTilesFor(
    trip: trip,
    bids: bids,
    isOwner: true,
    departed: departed,
    stripe: stripe,
  );
}

/// Rend [builder] avec les dernières données connues des tuiles « À
/// traiter » de [trip]. Chaque bloc présent dans [blocs] est suivi, et seuls
/// ses états porteurs de données reconstruisent : un chargement ou une
/// erreur garde les dernières valeurs, l'écran et ses sheets ne clignotent
/// pas. Un bloc absent laisse la valeur de départ.
///
/// La section « À traiter » de l'écran et les sheets de ses tuiles s'en
/// servent tous deux : une tuile affichée et son sheet voient exactement les
/// mêmes données (le sheet ne se referme pas seul à l'ouverture).
class TripTodoLive extends StatelessWidget {
  const TripTodoLive({
    super.key,
    required this.trip,
    required this.blocs,
    this.initialBids,
    required this.builder,
  });

  /// Trajet de départ, remplacé par le dernier relu par l'écran (même id).
  final AnnouncementModel trip;
  final TripTodoBlocs blocs;

  /// Derniers colis connus de l'appelant, tant que le `BidBloc` n'en porte
  /// pas : un sheet ouvert pendant un rechargement de l'écran part des
  /// colis de la tuile touchée au lieu de retomber sur `pendingBidCount`.
  final List<BidModel>? initialBids;
  final Widget Function(BuildContext context, TripTodoLiveData live) builder;

  @override
  Widget build(BuildContext context) {
    return followBloc<AnnouncementBloc, AnnouncementState, AnnouncementModel>(
      present: blocs.announcement != null,
      select: (s) => tripAnnouncementIn(s, trip.id),
      builder: (context, current) =>
          followBloc<BidBloc, BidState, List<BidModel>>(
            present: blocs.bids != null,
            select: (s) => s is BidListLoaded ? s.bids : null,
            builder: (context, bids) =>
                followBloc<
                  StripeAccountBloc,
                  StripeAccountState,
                  StripeAccountState
                >(
                  present: blocs.stripe != null,
                  // Chargement ou erreur : le dernier statut connu reste.
                  select: (s) => s is StripeAccountReady ? s : null,
                  builder: (context, stripe) =>
                      followBloc<TripDepartCubit, TripDepartState, bool>(
                        present: blocs.depart != null,
                        select: (s) => s.departed,
                        builder: (context, departed) => builder(
                          context,
                          TripTodoLiveData(
                            trip: current ?? trip,
                            bids: bids ?? initialBids,
                            departed: departed ?? false,
                            stripe: stripe ?? const StripeAccountInitial(),
                          ),
                        ),
                      ),
                ),
          ),
    );
  }
}
