import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';

/// Demande de l'expéditeur déjà présente sur un trajet.
sealed class ExistingTripRequest {
  const ExistingTripRequest();
}

/// Un colis en cours, de la demande à la livraison.
class ExistingTripBid extends ExistingTripRequest {
  const ExistingTripBid(this.bid);
  final BidModel bid;
}

/// Une discussion de prix encore ouverte (en cours, ou accord pas encore réglé).
class ExistingTripNegotiation extends ExistingTripRequest {
  const ExistingTripNegotiation(this.bidId);
  final String bidId;
}

/// Contrôle, au moment où l'expéditeur veut commander, qu'il n'a pas déjà une
/// demande sur ce trajet.
///
/// La feuille du trajet décidait sur le cache du `BidBloc` (`GET /bids/me`),
/// que rien ne rafraîchissait après une négociation payée dans son fil ; et
/// `GET /bids/me` tait les bids `NEGOTIATING`. L'expéditeur remplissait donc
/// tout le formulaire pour se voir refuser au paiement (409 `already-bid`).
/// Ce contrôle relit le serveur, colis ET discussions de prix.
class ExistingTripRequestLookup {
  const ExistingTripRequestLookup(this._bids, this._negotiations);

  final BidRepository _bids;
  final BidNegotiationRepository _negotiations;

  /// Null si rien n'est trouvé, ou si le serveur ne répond pas : le back
  /// reste l'arbitre, on ne bloque pas un expéditeur sur une panne réseau.
  Future<ExistingTripRequest?> find(String announcementId) async {
    // Seul ce trajet, et seuls les colis en cours : une page suffit.
    final bidsFuture = Future.sync(
      () => _bids.getMyBidsFiltered(
        statuses: MyActiveBidsLookup.ongoingBidStatuses,
        announcementId: announcementId,
        maxPages: 1,
      ),
    ).then<List<BidModel>>((b) => b, onError: (Object _) => const <BidModel>[]);
    final negotiationsFuture = Future.sync(_negotiations.myNegotiations)
        .then<List<BidNegotiationSummary>>(
          (n) => n,
          onError: (Object _) => const <BidNegotiationSummary>[],
        );
    final bids = await bidsFuture;
    final negotiations = await negotiationsFuture;

    for (final bid in bids) {
      if (bid.announcementId == announcementId &&
          MyActiveBidsLookup.ongoingBidStatuses.contains(bid.status)) {
        return ExistingTripBid(bid);
      }
    }
    for (final n in negotiations) {
      // Seuls mes fils d'expéditeur : `role` peut manquer sur un vieux serveur.
      if (n.announcementId == announcementId &&
          !n.isClosed &&
          n.role != 'TRAVELER') {
        return ExistingTripNegotiation(n.bidId);
      }
    }
    return null;
  }
}
