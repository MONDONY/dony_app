import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:equatable/equatable.dart';

/// Brouillon proposé dans la feuille « Terminer ou créer » avant le
/// formulaire de publication.
sealed class PublishDraftEntry extends Equatable {
  const PublishDraftEntry();

  String? get departureCity;
  String? get arrivalCity;

  /// Date du trajet ou date souhaitée de l'envoi, si déjà choisie.
  DateTime? get date;
}

/// Saisie gardée sur ce téléphone, même incomplète.
class LocalPublishDraft extends PublishDraftEntry {
  const LocalPublishDraft({
    required this.draft,
    this.departureCity,
    this.arrivalCity,
    this.date,
  });

  final StoredFormDraft draft;
  @override
  final String? departureCity;
  @override
  final String? arrivalCity;
  @override
  final DateTime? date;

  @override
  List<Object?> get props => [draft.savedAt, departureCity, arrivalCity, date];
}

/// Trajet complet enregistré en brouillon sur le serveur, pas encore publié.
class ServerTripDraft extends PublishDraftEntry {
  const ServerTripDraft(this.announcement);

  final AnnouncementModel announcement;

  @override
  String get departureCity => announcement.departureCity;
  @override
  String get arrivalCity => announcement.arrivalCity;
  @override
  DateTime get date => announcement.departureDate;

  @override
  List<Object?> get props => [announcement.id];
}

/// Demande d'envoi complète enregistrée en brouillon sur le serveur.
class ServerRequestDraft extends PublishDraftEntry {
  const ServerRequestDraft(this.request);

  final PackageRequest request;

  @override
  String get departureCity => request.departureCity;
  @override
  String get arrivalCity => request.arrivalCity;
  @override
  DateTime get date => request.desiredDate;

  @override
  List<Object?> get props => [request.id];
}
