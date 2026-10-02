import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';

abstract class AnnouncementState {}

class AnnouncementInitial extends AnnouncementState {}

class AnnouncementLoading extends AnnouncementState {}

class AnnouncementCreated extends AnnouncementState {
  final AnnouncementModel announcement;

  AnnouncementCreated(this.announcement);
}

class AnnouncementError extends AnnouncementState {
  final AppException error;
  final List<AnnouncementModel>? previousResults;

  AnnouncementError(this.error, {this.previousResults});
}

class AnnouncementListLoaded extends AnnouncementState {
  final List<AnnouncementModel> announcements;
  final int totalElements;
  AnnouncementListLoaded(this.announcements, {this.totalElements = 0});
}

class AnnouncementDetailLoaded extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementDetailLoaded(this.announcement);
}

class AnnouncementUpdated extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementUpdated(this.announcement);
}

class AnnouncementDeleted extends AnnouncementState {}

/// Émis quand le back refuse la suppression du trajet parce qu'au moins un
/// colis est déjà ACCEPTED. Le voyageur doit passer par le flux d'annulation
/// (qui rembourse l'expéditeur) plutôt que par une suppression directe.
class AnnouncementDeleteBlockedByAcceptedBid extends AnnouncementState {
  final String announcementId;
  AnnouncementDeleteBlockedByAcceptedBid(this.announcementId);
}

class AnnouncementSearchLoaded extends AnnouncementState {
  final List<AnnouncementModel> results;
  final bool isEmpty;
  final bool isReloading;

  /// Total serveur des trajets correspondant aux critères (toutes pages),
  /// `null` quand il n'est pas connu.
  final int? totalElements;

  /// Dernière page chargée (0 = première).
  final int page;

  /// Page suivante en cours de chargement.
  final bool isLoadingMore;

  AnnouncementSearchLoaded(
    this.results, {
    this.isReloading = false,
    this.totalElements,
    this.page = 0,
    this.isLoadingMore = false,
  }) : isEmpty = results.isEmpty;

  /// D'autres trajets restent à charger.
  bool get hasMore => totalElements != null && results.length < totalElements!;

  /// Nombre à afficher : le total serveur s'il est connu, sinon la liste.
  int get displayCount => totalElements ?? results.length;
}

class AnnouncementNotFound extends AnnouncementState {}

/// Émis après l'ouverture réussie de la capacité excédentaire d'un trajet
/// dédié. Porte l'annonce rechargée (surplus publié, capacité publique à jour).
class AnnouncementSurplusOpened extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementSurplusOpened(this.announcement);
}

class AnnouncementProLimitReached extends AnnouncementState {
  final AppException error;
  AnnouncementProLimitReached(this.error);
}

/// Émis après la publication réussie d'un trajet (brouillon → ACTIF).
class AnnouncementPublished extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementPublished(this.announcement);
}

/// Le compte a atteint sa limite de brouillons (voyageur non-PRO).
class AnnouncementDraftLimitReached extends AnnouncementState {
  final AppException error;
  AnnouncementDraftLimitReached(this.error);
}

/// La publication requiert une identité vérifiée (KYC) au préalable.
class AnnouncementKycRequired extends AnnouncementState {
  final AppException error;
  AnnouncementKycRequired(this.error);
}

/// La date de départ du trajet est passée : publication refusée tant que
/// l'utilisateur n'a pas corrigé la date.
class AnnouncementDepartureDatePassed extends AnnouncementState {
  final AppException error;
  AnnouncementDepartureDatePassed(this.error);
}

/// Émis après le marquage groupé « Arrivé à destination » d'un trajet.
class AnnouncementTripArrived extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementTripArrived(this.announcement);
}

/// Émis après la mise à jour des instructions de retrait.
class AnnouncementArrivalInstructionsUpdated extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementArrivalInstructionsUpdated(this.announcement);
}

/// Trajet reporté : `announcement` porte les nouveaux horaires, `result` le
/// nombre d'expéditeurs prévenus et les reports restants.
class AnnouncementRescheduled extends AnnouncementState {
  final AnnouncementModel announcement;
  final TripRescheduleResult result;
  AnnouncementRescheduled(this.announcement, this.result);
}
