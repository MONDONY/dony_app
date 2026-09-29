import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Un colis vient de changer d'état hors des listes : paiement, accord ou
/// refus dans le fil de négociation d'un trajet.
///
/// Sans ce signal, « Mes colis », « Demandes reçues », « Discussions de prix »
/// et le cache de colis lu par la feuille du trajet gardaient l'état d'avant :
/// la feuille reproposait « Faire une demande » sur un trajet déjà payé, et le
/// back la refusait seulement au paiement (409 `already-bid`).
///
/// [context] sert au `BidBloc` global (fourni par `app.dart`, pas un
/// singleton) ; les autres surfaces sont des singletons. Chaque cible est
/// facultative : un test ou un point d'entrée isolé peut ne pas les avoir.
void refreshActivityAfterBidChange([BuildContext? context]) {
  if (context != null && context.mounted) {
    try {
      context.read<BidBloc>().add(
        const BidMyListAutoRefreshRequested(force: true),
      );
    } catch (_) {
      /* Pas de BidBloc au-dessus de ce contexte. */
    }
  }
  if (getIt.isRegistered<TravelerBidsBloc>()) {
    getIt<TravelerBidsBloc>().add(const TravelerBidsRequested(force: true));
  }
  if (getIt.isRegistered<BidNegotiationListBloc>()) {
    getIt<BidNegotiationListBloc>().add(
      const BidNegotiationListFetchRequested(),
    );
  }
  if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
    getIt<EnvoisRefreshNotifier>().requestRefresh();
  }
}
