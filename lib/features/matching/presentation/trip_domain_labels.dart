import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellés traduits du mode de transport d'un trajet.
extension TransportModeL10n on TransportMode {
  String label(AppLocalizations l) => switch (this) {
    TransportMode.plane => l.tripTransportPlane,
    TransportMode.car => l.tripTransportCar,
    TransportMode.train => l.tripTransportTrain,
    TransportMode.bus => l.tripTransportBus,
    TransportMode.boat => l.tripTransportBoat,
    TransportMode.other => l.tripTransportOther,
  };
}

/// Libellés et infobulles traduits d'un filtre d'urgence de départ.
extension UrgencyFilterL10n on UrgencyFilter {
  String label(AppLocalizations l) => switch (this) {
    UrgencyFilter.veryUrgent => l.tripUrgencyVeryUrgent,
    UrgencyFilter.urgent => l.tripUrgencyUrgent,
    UrgencyFilter.soon => l.tripUrgencySoon,
    UrgencyFilter.later => l.tripUrgencyLater,
  };

  String tooltip(AppLocalizations l) => switch (this) {
    UrgencyFilter.veryUrgent => l.tripUrgencyVeryUrgentTooltip,
    UrgencyFilter.urgent => l.tripUrgencyUrgentTooltip,
    UrgencyFilter.soon => l.tripUrgencySoonTooltip,
    UrgencyFilter.later => l.tripUrgencyLaterTooltip,
  };
}

/// Libellés traduits d'une unité de capacité (valise, kg libre, personnalisé).
extension CapacityUnitL10n on CapacityUnit {
  String label(AppLocalizations l) => switch (this) {
    CapacityUnit.suitcase23kg => l.tripCapacitySuitcase23,
    CapacityUnit.suitcase32kg => l.tripCapacitySuitcase32,
    CapacityUnit.kgFree => l.tripKgFree,
    CapacityUnit.custom => l.tripCapacityCustom,
  };
}

/// Nom affiché du voyageur, avec repli traduit quand `displayName` est
/// absent ou vide.
///
/// Le serveur renvoie désormais toujours un `displayName` non vide : « Prénom
/// N. » ou, à défaut de prénom, le username du compte. Le repli sur
/// [AppLocalizations.tripTravelerFallbackName] ne couvre plus qu'une réponse
/// tronquée ou un cache antérieur.
///
/// Portée sur [TravelerProfile] (et non [AnnouncementModel]) : c'est ce type
/// qui porte le champ `displayName`, et tous les appelants existants
/// détiennent déjà un `TravelerProfile?` (`announcement.traveler`), jamais un
/// `AnnouncementModel` directement.
extension AnnouncementTravelerName on TravelerProfile {
  String travelerName(AppLocalizations l) {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    return l.tripTravelerFallbackName;
  }
}
