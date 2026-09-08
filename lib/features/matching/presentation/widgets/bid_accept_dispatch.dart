import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dispatche l'acceptation d'un [bid] côté voyageur vers le bon bloc selon
/// le mode de paiement.
///
/// Le cash passe par [BidAcceptanceBloc] (flux commission), tandis que le
/// mobile money et la carte (Stripe) passent tous deux par [BidBloc], avec
/// un event dédié pour le mobile money (aucune interaction Stripe requise
/// côté voyageur, contrairement à la carte).
///
/// Factorisé depuis trois sites identiques (`pending_bids_screen.dart`,
/// `demandes_screen.dart`, `bid_detail_action_bars.dart`) — chaque site garde
/// son propre effet de bord (indicateur de traitement, etc.) autour de cet
/// appel, seul le choix de branche est partagé.
void dispatchBidAccept(BuildContext context, BidModel bid) {
  if (bid.paymentMethod == BidPaymentMethod.cash) {
    context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(bid.id));
  } else if (bid.paymentMethod == BidPaymentMethod.mobileMoney) {
    context.read<BidBloc>().add(BidAcceptMobileMoneyRequested(bid.id));
  } else {
    context.read<BidBloc>().add(BidAcceptRequested(bid.id));
  }
}
