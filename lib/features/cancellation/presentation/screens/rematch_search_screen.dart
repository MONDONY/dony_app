import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                    'Aucun voyageur alternatif disponible dans les 72h sur ce corridor — votre remboursement est traité.',
              )
            else ...[
              Text(
                '${suggestions.length} voyageur${suggestions.length > 1 ? 's' : ''} disponible${suggestions.length > 1 ? 's' : ''}',
                style: tt.titleLarge?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: DonySpacing.base),
              ...suggestions.asMap().entries.map((e) => _SuggestionCard(
                    suggestion: e.value,
                    index: e.key,
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

class _SuggestionCard extends StatelessWidget {
  final RematchSuggestionModel suggestion;
  final int index;
  const _SuggestionCard({required this.suggestion, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                iconAsset: 'plane-takeoff',
                backgroundColor: cs.primaryContainer,
                iconColor: cs.primary,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  '${suggestion.departureCity} → ${suggestion.arrivalCity}',
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              _Chip(
                iconAsset: 'calendar',
                label: DateFormat('dd MMM yyyy').format(suggestion.departureDate),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: DonySpacing.md),
              _Chip(
                iconAsset: 'scale',
                label: '${suggestion.availableKg} kg dispo',
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: DonySpacing.md),
              _Chip(
                iconAsset: 'euro',
                label: '${formatKgPrice(netToSenderPrice(suggestion.pricePerKg))} €/kg',
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Envoyer une demande',
            onPressed: () => context.push(
              '/search/${suggestion.announcementId}/bid',
              extra: AnnouncementModel(
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
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0);
  }
}

class _Chip extends StatelessWidget {
  final String iconAsset;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  const _Chip({
    required this.iconAsset,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon(iconAsset, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
