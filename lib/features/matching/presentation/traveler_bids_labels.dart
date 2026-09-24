import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellé traduit d'un filtre de l'écran « Demandes reçues ».
///
/// Remplace `TravelerBidFilterX.label` (getter français en dur, supprimé) :
/// le reste de l'extension (`matches`) ne change pas.
extension TravelerBidFilterL10n on TravelerBidFilter {
  String label(AppLocalizations l) => switch (this) {
    TravelerBidFilter.aTraiter => l.bidListFilterToReview,
    TravelerBidFilter.acceptees => l.bidListFilterAccepted,
    TravelerBidFilter.terminees => l.bidListFilterCompleted,
  };
}
