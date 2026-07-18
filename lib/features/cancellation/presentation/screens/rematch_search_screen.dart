import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Alternatives disponibles » après annulation d'un trajet.
///
/// Deux modes :
/// - [cancellation] déjà en main (navigation optimisée depuis un écran qui
///   l'a déjà chargé) → rendu direct, pas de fetch.
/// - [cancellation] absent (ex : ouverture depuis la notification FCM
///   `TRIP_CANCELLED`) → fetch self-contained via [CancellationBloc] avec
///   [cancellationId].
class RematchSearchScreen extends StatefulWidget {
  final String cancellationId;
  final CancellationModel? cancellation;

  const RematchSearchScreen({
    super.key,
    required this.cancellationId,
    this.cancellation,
  });

  @override
  State<RematchSearchScreen> createState() => _RematchSearchScreenState();
}

class _RematchSearchScreenState extends State<RematchSearchScreen> {
  /// Suggestion actuellement en cours de résolution (fetch du vrai
  /// [AnnouncementModel] par `suggestion.announcementId`). Flag UI-only —
  /// pas d'état métier ici, seulement quelle carte affiche un spinner /
  /// doit ignorer un nouveau tap pendant que le fetch est en vol. Précédent :
  /// `ValueNotifier` pour état local (cf. règle bottom sheet du CLAUDE.md).
  final ValueNotifier<String?> _loadingSuggestionId = ValueNotifier(null);

  /// Nombre de suggestions affichées au moment du tap — capturé pour
  /// l'event analytics `rematch_accepted`, tiré seulement au succès du fetch.
  int _pendingSuggestionsCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.cancellation == null) {
      context
          .read<CancellationBloc>()
          .add(RematchSuggestionsRequested(widget.cancellationId));
    }
  }

  @override
  void dispose() {
    _loadingSuggestionId.dispose();
    super.dispose();
  }

  /// Tap sur une `TravelerCard` (carte entière tactile) : fetch le vrai
  /// [AnnouncementModel] par `suggestion.announcementId` via l'`AnnouncementBloc`
  /// dédié à cette route (même chemin data que `AnnouncementDetailScreen` /
  /// `TripOwnerDetailScreen` — `GET /announcements/{id}`, fonctionne aussi
  /// pour une annonce qui n'appartient pas à l'utilisateur courant, cf.
  /// `TravelerProfileScreen`). Un stub ne doit jamais atteindre
  /// `showTravelerAnnouncementSheet` : `travelerId`/`pricingMode`/
  /// `priceGridItems`/`acceptedPaymentMethods` doivent venir du back.
  void _onSuggestionTap(RematchSuggestionModel suggestion, int suggestionsCount) {
    // Ignore un second tap tant qu'un fetch est déjà en vol (évite une
    // double requête / une race entre deux résolutions concurrentes).
    if (_loadingSuggestionId.value != null) {
      return;
    }
    _pendingSuggestionsCount = suggestionsCount;
    _loadingSuggestionId.value = suggestion.suggestionId;
    context
        .read<AnnouncementBloc>()
        .add(AnnouncementDetailRequested(suggestion.announcementId));
  }

  void _onAnnouncementState(BuildContext context, AnnouncementState state) {
    if (state is AnnouncementDetailLoaded) {
      _loadingSuggestionId.value = null;
      // Analytics tirée juste avant l'ouverture de la sheet — même point
      // que l'ancien code, désormais gaté par le succès du fetch.
      unawaited(getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.rematchAccepted,
        properties: {'count': _pendingSuggestionsCount},
      ));
      showTravelerAnnouncementSheet(
        context,
        announcement: state.announcement,
      );
    } else if (state is AnnouncementNotFound || state is AnnouncementError) {
      _loadingSuggestionId.value = null;
      DonySnackbar.show(
        context,
        message: 'Cette annonce n\'est plus disponible',
        type: DonySnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancellation = widget.cancellation;

    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: _onAnnouncementState,
      child: Scaffold(
        appBar: const DonyAppBar(
          title: 'Alternatives disponibles',
        ),
        body: cancellation != null
            ? _RematchBody(
                suggestions: cancellation.rematchSuggestions,
                affectedBidsCount: cancellation.affectedBidsCount,
                loadingSuggestionId: _loadingSuggestionId,
                onSuggestionTap: _onSuggestionTap,
              )
            : BlocBuilder<CancellationBloc, CancellationState>(
                builder: (context, state) {
                  if (state is RematchSuggestionsLoaded) {
                    return _RematchBody(
                      suggestions: state.suggestions,
                      affectedBidsCount: null,
                      loadingSuggestionId: _loadingSuggestionId,
                      onSuggestionTap: _onSuggestionTap,
                    );
                  }
                  if (state is CancellationError) {
                    return DonyEmptyState(
                      type: DonyEmptyStateType.error,
                      mascotte: DonyMascotteType.assis,
                      title: 'Erreur de chargement',
                      description: ErrorPresenter.resolve(state.error).message,
                      actionLabel: 'Réessayer',
                      onAction: () => context.read<CancellationBloc>().add(
                            RematchSuggestionsRequested(widget.cancellationId),
                          ),
                    );
                  }
                  // CancellationInitial / CancellationLoading / tout autre état
                  // transitoire du même bloc (registerFactory → instance dédiée
                  // à cette route).
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RematchBody extends StatelessWidget {
  final List<RematchSuggestionModel> suggestions;

  /// `null` quand la suggestion vient du fetch self-contained (notification
  /// FCM) — le back n'expose pas encore ce compteur sur
  /// `GET /cancellations/{id}/rematch-suggestions`, seulement sur la réponse
  /// d'annulation elle-même.
  final int? affectedBidsCount;

  /// `suggestionId` de la carte dont le fetch du vrai `AnnouncementModel`
  /// est en vol, `null` si aucune. Pilote le spinner léger + désactive les
  /// autres cartes pendant la résolution (UI-only, cf. `_RematchSearchScreenState`).
  final ValueListenable<String?> loadingSuggestionId;

  final void Function(RematchSuggestionModel suggestion, int suggestionsCount)
      onSuggestionTap;

  const _RematchBody({
    required this.suggestions,
    required this.affectedBidsCount,
    required this.loadingSuggestionId,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(h, DonySpacing.lg, h, DonySpacing.huge),
      child: DonyLayout.constrained(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmationBanner(
              affectedCount: affectedBidsCount,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.xl),
            if (suggestions.isEmpty)
              const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Aucun voyageur disponible',
                description:
                    'Aucun voyageur disponible dans les 72h — votre remboursement est traité',
              )
            else ...[
              Text(
                '${suggestions.length} voyageur${suggestions.length > 1 ? 's' : ''} disponible${suggestions.length > 1 ? 's' : ''}',
                style: tt.titleLarge?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: DonySpacing.base),
              ...suggestions.asMap().entries.map((e) {
                final suggestion = e.value;
                return ValueListenableBuilder<String?>(
                  valueListenable: loadingSuggestionId,
                  builder: (context, loadingId, _) {
                    final isLoading = loadingId == suggestion.suggestionId;
                    final isDisabled = loadingId != null && !isLoading;
                    return Stack(
                      children: [
                        Opacity(
                          opacity: isDisabled ? 0.4 : 1,
                          child: IgnorePointer(
                            ignoring: loadingId != null,
                            child: TravelerCard(
                              key: Key(
                                  'rematch-traveler-card-${suggestion.suggestionId}'),
                              announcement: _toAnnouncementModel(suggestion),
                              index: e.key,
                              isOwnAnnouncement: false,
                              onTap: () => onSuggestionTap(
                                suggestion,
                                suggestions.length,
                              ),
                            ),
                          ),
                        ),
                        if (isLoading)
                          Positioned.fill(
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }),
            ],
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Retour à l\'accueil',
              onPressed: () => context.go('/home'),
              variant: DonyButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  final int? affectedCount;
  final ColorScheme cs;
  final TextTheme tt;
  const _ConfirmationBanner({
    required this.affectedCount,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final count = affectedCount;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon('circle-check', color: cs.success, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Trajet annulé',
                style: tt.titleMedium?.copyWith(color: cs.success),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            count != null
                ? '$count expéditeur${count > 1 ? 's' : ''} remboursé${count > 1 ? 's' : ''} automatiquement.'
                : 'Votre remboursement est en cours.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Mappe une suggestion de rematch vers l'[AnnouncementModel] attendu par
/// `TravelerCard` pour le RENDU DE LISTE UNIQUEMENT (nom, note, corridor,
/// prix indicatif €/kg). C'est un stub incomplet — `travelerId: 'temp'`,
/// `TravelerProfile(id: 'temp')`, pas de `pricingMode`/`priceGridItems`/
/// `acceptedPaymentMethods` — donc il NE DOIT JAMAIS être passé à
/// `showTravelerAnnouncementSheet` : le bloc voyageur y devient tappable et
/// pousserait `/profile/public` avec l'id 'temp', et une annonce en pricing
/// MIXED/GRID s'afficherait à tort en €/kg. `TravelerCard` n'utilise
/// `announcement.traveler` que pour l'affichage (nom/note/avatar/badges) —
/// son unique callback tactile est `onTap`, jamais une navigation interne
/// basée sur `traveler.id` — donc ce stub reste sûr pour le rendu de liste.
/// Le TAP, lui, passe par `_RematchSearchScreenState._onSuggestionTap` qui
/// fetch le vrai `AnnouncementModel` par `suggestion.announcementId`.
///
/// `totalTrips` n'est PAS alimenté par `travelerRatingCount` : ce sont deux
/// notions différentes (nombre d'avis ≠ nombre de trajets effectués) et
/// `TravelerCard` n'a pas de slot dédié « nombre d'avis » — l'afficher comme
/// un nombre de trajets induirait l'expéditeur en erreur au moment de choisir
/// un voyageur de confiance. `travelerRatingCount` reste dans le modèle mais
/// n'est actuellement rendu nulle part sur cet écran.
AnnouncementModel _toAnnouncementModel(RematchSuggestionModel suggestion) {
  final hasTravelerInfo =
      suggestion.travelerFirstName != null || suggestion.travelerRating != null;

  return AnnouncementModel(
    id: suggestion.announcementId,
    travelerId: 'temp',
    departureCity: suggestion.departureCity,
    arrivalCity: suggestion.arrivalCity,
    departureDate: suggestion.departureDate,
    availableKg: suggestion.availableKg,
    totalKg: suggestion.availableKg,
    pricePerKg: suggestion.pricePerKg,
    status: 'ACTIVE',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    traveler: hasTravelerInfo
        ? TravelerProfile(
            id: 'temp',
            displayName: suggestion.travelerFirstName,
            averageRating: suggestion.travelerRating,
          )
        : null,
  );
}
