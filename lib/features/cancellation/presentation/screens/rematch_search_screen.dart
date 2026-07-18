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
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
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
  Widget build(BuildContext context) {
    final cancellation = widget.cancellation;

    return Scaffold(
      appBar: const DonyAppBar(
        title: 'Alternatives disponibles',
      ),
      body: cancellation != null
          ? _RematchBody(
              suggestions: cancellation.rematchSuggestions,
              affectedBidsCount: cancellation.affectedBidsCount,
            )
          : BlocBuilder<CancellationBloc, CancellationState>(
              builder: (context, state) {
                if (state is RematchSuggestionsLoaded) {
                  return _RematchBody(
                    suggestions: state.suggestions,
                    affectedBidsCount: null,
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

  const _RematchBody({
    required this.suggestions,
    required this.affectedBidsCount,
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
              ...suggestions.asMap().entries.map((e) => TravelerCard(
                    key: Key('rematch-traveler-card-${e.value.suggestionId}'),
                    announcement: _toAnnouncementModel(e.value),
                    index: e.key,
                    isOwnAnnouncement: false,
                    onTap: () => _acceptSuggestion(
                      context,
                      suggestion: e.value,
                      suggestionsCount: suggestions.length,
                    ),
                  )),
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
/// `TravelerCard` / `showTravelerAnnouncementSheet`. Mêmes valeurs de repli
/// que l'ancien mapping (id = announcementId, status ACTIVE, totalKg =
/// availableKg) — étendu avec le prénom/note voyageur désormais exposés par
/// `RematchSuggestionModel`.
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

/// Tap sur une `TravelerCard` (carte entière tactile) : tire l'event
/// analytics widget-level `rematch_accepted` (précédent : `TripParcelsSection`
/// pour `trip_parcels_filtered`) puis ouvre le même overlay que le feed de
/// recherche (`showTravelerAnnouncementSheet` — cf. `home_screen.dart`
/// tap non-owned card) qui mène au flux de création de bid réel
/// (`CreateBidBottomSheet`). Il n'existe PAS de route `/search/{id}/bid` dans
/// `router.dart` — l'ancien `context.push` vers cette route poussait vers une
/// page inexistante. Aucune PII dans les properties analytics — uniquement le
/// nombre d'alternatives affichées.
void _acceptSuggestion(
  BuildContext context, {
  required RematchSuggestionModel suggestion,
  required int suggestionsCount,
}) {
  unawaited(getIt<AnalyticsService>().logEvent(
    AnalyticsEvents.rematchAccepted,
    properties: {'count': suggestionsCount},
  ));
  showTravelerAnnouncementSheet(
    context,
    announcement: _toAnnouncementModel(suggestion),
  );
}
