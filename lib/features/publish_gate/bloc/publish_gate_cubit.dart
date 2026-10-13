import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_state.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/models/publish_draft_entry.dart';
import 'package:dony/features/publish_gate/data/repositories/publish_commitment_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Choix fait dans la feuille des brouillons (propriété `choice`).
enum PublishDraftChoice {
  local('local'),
  server('server'),
  createNew('new'),
  dismissed('dismissed');

  const PublishDraftChoice(this.wire);

  final String wire;
}

/// Aiguillage avant le formulaire de publication (trajet ou demande).
///
/// Première publication du rôle (ou nouvelle version du texte) : écran des
/// engagements, case à cocher, acceptation enregistrée sur le serveur. Les
/// fois suivantes, l'écran est sauté. Dans les deux cas, s'il reste des
/// brouillons (sur ce téléphone ou sur le serveur), la feuille « Terminer ou
/// créer » passe avant le formulaire.
class PublishGateCubit extends Cubit<PublishGateState> {
  PublishGateCubit({
    required this.role,
    required PublishCommitmentRepository commitments,
    required FormDraftStore drafts,
    required AnnouncementRepository announcements,
    required PackageRequestRepository packageRequests,
    required AnalyticsService analytics,
  }) : _commitments = commitments,
       _drafts = drafts,
       _announcements = announcements,
       _packageRequests = packageRequests,
       _analytics = analytics,
       super(const PublishGateState());

  final PublishCommitmentRole role;
  final PublishCommitmentRepository _commitments;
  final FormDraftStore _drafts;
  final AnnouncementRepository _announcements;
  final PackageRequestRepository _packageRequests;
  final AnalyticsService _analytics;

  /// Nombre maximal de brouillons serveur proposés, les plus récents.
  static const maxServerDrafts = 5;

  FormDraftKind get _kind => switch (role) {
    PublishCommitmentRole.traveler => FormDraftKind.trip,
    PublishCommitmentRole.sender => FormDraftKind.packageRequest,
  };

  /// [kycVerified] faux : l'écran reste affiché, il porte le chemin vers la
  /// vérification d'identité, préalable à toute publication.
  Future<void> start({required bool kycVerified}) async {
    emit(const PublishGateState());
    PublishCommitments? fetched;
    try {
      fetched = await _commitments.fetch();
    } on Object catch (e) {
      // Hors ligne ou back antérieur : on montre les engagements, l'accord
      // sera relu avant d'être envoyé.
      debugPrint('PublishGateCubit.start: commitments unavailable ($e)');
    }
    if (isClosed) return;
    final required = fetched?.of(role).required ?? true;
    if (!required && kycVerified) {
      emit(
        state.copyWith(
          commitmentRequired: false,
          version: fetched?.currentVersion,
        ),
      );
      await _loadDrafts();
      return;
    }
    emit(
      state.copyWith(
        status: PublishGateStatus.intro,
        commitmentRequired: required,
        version: fetched?.currentVersion,
        introShown: true,
      ),
    );
  }

  void setChecked(bool value) => emit(state.copyWith(checked: value));

  /// « Continuer » de l'écran des engagements.
  Future<void> accept() async {
    if (state.status == PublishGateStatus.accepting) return;
    if (state.commitmentRequired) {
      if (!state.checked) return;
      emit(state.copyWith(status: PublishGateStatus.accepting));
      var recorded = true;
      try {
        final version =
            state.version ?? (await _commitments.fetch()).currentVersion;
        await _commitments.accept(role, version);
      } on AppException catch (e) {
        if (isClosed) return;
        if (e.code == 'publish-commitment-outdated') {
          await _reloadAfterOutdated();
          return;
        }
        if (e is! NotFoundException) {
          _failAccept();
          return;
        }
        // Back antérieur sans la route : rien à enregistrer, on laisse
        // publier. L'écran reviendra à chaque fois, comme avant.
        recorded = false;
      } on Object {
        if (isClosed) return;
        _failAccept();
        return;
      }
      if (isClosed) return;
      if (recorded) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.publishCommitmentAccepted,
            properties: {'role': role.wire.toLowerCase()},
          ),
        );
      }
      emit(state.copyWith(commitmentRequired: false));
    }
    await _loadDrafts();
  }

  void _failAccept() => emit(
    state.copyWith(
      status: PublishGateStatus.intro,
      error: PublishGateError.acceptFailed,
      bumpError: true,
    ),
  );

  /// Le texte a changé : nouvelle version, case décochée, à relire.
  Future<void> _reloadAfterOutdated() async {
    String? version;
    try {
      version = (await _commitments.fetch()).currentVersion;
    } on Object {
      version = null;
    }
    if (isClosed) return;
    emit(
      PublishGateState(
        status: PublishGateStatus.intro,
        version: version,
        introShown: true,
        error: PublishGateError.outdated,
        errorSeq: state.errorSeq + 1,
      ),
    );
  }

  Future<void> _loadDrafts() async {
    emit(state.copyWith(status: PublishGateStatus.checkingDrafts));
    final local = await _localDraft();
    final server = await _serverDrafts();
    if (isClosed) return;
    final drafts = [?local, ...server];
    if (drafts.isNotEmpty) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.publishDraftsSheetShown,
          properties: {
            'role': role.wire.toLowerCase(),
            'local': local != null,
            'server_count': server.length,
          },
        ),
      );
    }
    emit(state.copyWith(status: PublishGateStatus.ready, drafts: drafts));
  }

  Future<LocalPublishDraft?> _localDraft() async {
    final stored = await _drafts.read(_kind);
    if (stored == null) return null;
    switch (role) {
      case PublishCommitmentRole.traveler:
        final d = TripFormDraft.fromJson(stored.data);
        return LocalPublishDraft(
          draft: stored,
          departureCity: d.departureCity,
          arrivalCity: d.arrivalCity,
          date: d.departureDate,
        );
      case PublishCommitmentRole.sender:
        final d = PackageRequestFormDraft.decode(stored.data);
        return LocalPublishDraft(
          draft: stored,
          departureCity: d.departureCity,
          arrivalCity: d.arrivalCity,
          date: d.desiredDate,
        );
    }
  }

  /// Brouillons serveur du rôle. Un échec n'empêche pas de publier : on
  /// propose simplement moins de choix.
  Future<List<PublishDraftEntry>> _serverDrafts() async {
    try {
      switch (role) {
        case PublishCommitmentRole.traveler:
          final mine = await _announcements.getMyAnnouncements();
          final drafts =
              mine.announcements.where((a) => a.status == 'DRAFT').toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return [
            for (final a in drafts.take(maxServerDrafts)) ServerTripDraft(a),
          ];
        case PublishCommitmentRole.sender:
          final mine = await _packageRequests.findMine(size: 50);
          final drafts =
              mine.content
                  .where((r) => r.status == PackageRequestStatus.draft)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return [
            for (final r in drafts.take(maxServerDrafts)) ServerRequestDraft(r),
          ];
      }
    } on Object catch (e) {
      debugPrint('PublishGateCubit: server drafts unavailable ($e)');
      return const [];
    }
  }

  /// Trace le choix fait dans la feuille des brouillons. La navigation reste
  /// à l'écran.
  void trackChoice(PublishDraftChoice choice, {PublishDraftEntry? entry}) {
    final properties = <String, Object>{
      'role': role.wire.toLowerCase(),
      'choice': choice.wire,
    };
    if (entry is LocalPublishDraft) {
      properties['step'] = entry.draft.step;
      properties['age_days'] = DateTime.now()
          .difference(entry.draft.savedAt)
          .inDays;
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.publishDraftChosen,
        properties: properties,
      ),
    );
  }
}
