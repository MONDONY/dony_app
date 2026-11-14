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
    this.stepNumber,
    this.stepCount,
  });

  final StoredFormDraft draft;

  /// Étape où la saisie s'est arrêtée (1 = première) et nombre d'étapes du
  /// formulaire. `null` : repli sur l'index historique à trois étapes de
  /// [StoredFormDraft.step] (le trajet en a cinq depuis les modes de
  /// transport : « étape 3 sur 3 » à l'étape 5, recette du 13/11).
  final int? stepNumber;
  final int? stepCount;
  @override
  final String? departureCity;
  @override
  final String? arrivalCity;
  @override
  final DateTime? date;

  @override
  List<Object?> get props => [
    draft.savedAt,
    departureCity,
    arrivalCity,
    date,
    stepNumber,
    stepCount,
  ];
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

/// Brouillons d'une même série (trajet récurrent par dates précises),
/// regroupés sur une ligne. Triés par date de départ.
class ServerTripDraftSeries extends PublishDraftEntry {
  const ServerTripDraftSeries(this.announcements)
    : assert(announcements.length > 1);

  final List<AnnouncementModel> announcements;

  @override
  String get departureCity => announcements.first.departureCity;
  @override
  String get arrivalCity => announcements.first.arrivalCity;
  @override
  DateTime get date => announcements.first.departureDate;

  @override
  List<Object?> get props => [for (final a in announcements) a.id];
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
  DateTime? get date => request.desiredDate;

  @override
  List<Object?> get props => [request.id];
}
