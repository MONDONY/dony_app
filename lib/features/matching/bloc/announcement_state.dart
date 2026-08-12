import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';

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

  AnnouncementSearchLoaded(this.results, {this.isReloading = false})
    : isEmpty = results.isEmpty;
}

class AnnouncementNotFound extends AnnouncementState {}

/// Émis après l'ouverture réussie de la capacité excédentaire d'un trajet
/// dédié. Porte l'annonce rechargée (surplus publié, capacité publique à jour).
class AnnouncementSurplusOpened extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementSurplusOpened(this.announcement);
}

class AnnouncementProLimitReached extends AnnouncementState {
  final String message;
  AnnouncementProLimitReached(this.message);
}

/// Émis après la publication réussie d'un trajet (brouillon → ACTIF).
class AnnouncementPublished extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementPublished(this.announcement);
}

/// Le compte a atteint sa limite de brouillons (voyageur non-PRO).
class AnnouncementDraftLimitReached extends AnnouncementState {
  final String message;
  AnnouncementDraftLimitReached(this.message);
}

/// La publication requiert une identité vérifiée (KYC) au préalable.
class AnnouncementKycRequired extends AnnouncementState {
  final String message;
  AnnouncementKycRequired(this.message);
}

/// La date de départ du trajet est passée : publication refusée tant que
/// l'utilisateur n'a pas corrigé la date.
class AnnouncementDepartureDatePassed extends AnnouncementState {
  final String message;
  AnnouncementDepartureDatePassed(this.message);
}
