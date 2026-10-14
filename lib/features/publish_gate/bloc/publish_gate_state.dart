import 'package:dony/features/publish_gate/data/models/publish_draft_entry.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:equatable/equatable.dart';

enum PublishGateStatus {
  /// Lecture des engagements.
  loading,

  /// Écran des engagements affiché (à accepter, ou identité à vérifier).
  intro,

  /// Acceptation en cours d'envoi.
  accepting,

  /// Recherche des brouillons, juste avant le formulaire.
  checkingDrafts,

  /// Prêt : la feuille des brouillons s'ouvre s'il y en a, sinon le
  /// formulaire.
  ready,
}

/// Échec à montrer une fois, sous l'écran des engagements.
enum PublishGateError {
  /// L'acceptation n'a pas pu être enregistrée (hors ligne, serveur).
  acceptFailed,

  /// Le texte a changé entre l'affichage et l'acceptation : à relire.
  outdated,
}

class PublishGateState extends Equatable {
  const PublishGateState({
    this.status = PublishGateStatus.loading,
    this.commitmentRequired = true,
    this.version,
    this.checked = false,
    this.introShown = false,
    this.drafts = const [],
    this.templates = const [],
    this.error,
    this.errorSeq = 0,
  });

  final PublishGateStatus status;

  /// L'utilisateur doit encore cocher et accepter ses engagements.
  final bool commitmentRequired;

  /// Version en vigueur, `null` si les engagements n'ont pas pu être lus.
  final String? version;

  /// Case « J'ai lu et pris connaissance de mes engagements ».
  final bool checked;

  /// L'écran des engagements a été montré : fermer la feuille des brouillons
  /// y ramène, au lieu de quitter.
  final bool introShown;

  /// Brouillons à proposer, le local d'abord.
  final List<PublishDraftEntry> drafts;

  /// Modèles de trajet du voyageur, proposés sous les brouillons.
  final List<TripTemplate> templates;

  /// La feuille « Terminer ou créer » a quelque chose à proposer.
  bool get hasChoices => drafts.isNotEmpty || templates.isNotEmpty;

  final PublishGateError? error;

  /// Incrémenté à chaque nouvelle erreur, pour la montrer même répétée.
  final int errorSeq;

  PublishGateState copyWith({
    PublishGateStatus? status,
    bool? commitmentRequired,
    String? version,
    bool? checked,
    bool? introShown,
    List<PublishDraftEntry>? drafts,
    List<TripTemplate>? templates,
    PublishGateError? error,
    bool bumpError = false,
  }) => PublishGateState(
    status: status ?? this.status,
    commitmentRequired: commitmentRequired ?? this.commitmentRequired,
    version: version ?? this.version,
    checked: checked ?? this.checked,
    introShown: introShown ?? this.introShown,
    drafts: drafts ?? this.drafts,
    templates: templates ?? this.templates,
    error: bumpError ? error : this.error,
    errorSeq: bumpError ? errorSeq + 1 : errorSeq,
  );

  @override
  List<Object?> get props => [
    status,
    commitmentRequired,
    version,
    checked,
    introShown,
    drafts,
    templates,
    error,
    errorSeq,
  ];
}
