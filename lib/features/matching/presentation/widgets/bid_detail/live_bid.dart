import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rend [builder] avec le colis courant : le dernier [BidDetailLoaded] du
/// `BidBloc` de l'écran pour ce colis, à défaut [bid] (celui de l'ouverture).
/// Sans `BidBloc` ([live] faux), rendu statique avec [bid].
///
/// Sert aux bottom sheets des tuiles de la fiche colis (expéditeur et
/// voyageur) : un sheet reste ouvert pendant les rechargements de l'écran
/// (relevé périodique, changement de destinataire fait depuis le sheet).
class LiveBid extends StatelessWidget {
  const LiveBid({
    super.key,
    required this.bid,
    required this.live,
    required this.builder,
  });

  final BidModel bid;
  final bool live;
  final Widget Function(BuildContext context, BidModel bid) builder;

  @override
  Widget build(BuildContext context) {
    if (!live) return builder(context, bid);
    return BlocBuilder<BidBloc, BidState>(
      buildWhen: (_, state) =>
          state is BidDetailLoaded && state.bid.id == bid.id,
      builder: (context, state) => builder(
        context,
        state is BidDetailLoaded && state.bid.id == bid.id ? state.bid : bid,
      ),
    );
  }
}
