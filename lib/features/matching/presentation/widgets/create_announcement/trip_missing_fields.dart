// Champs obligatoires manquants des étapes 1 et 2 de « Publier un trajet » :
// marque d'un champ, bandeau en tête d'étape, pastilles au-dessus du bouton.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_missing_fields_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Nom d'un champ obligatoire, tel que le voyageur le lit à l'écran.
String tripRequiredFieldLabel(AppLocalizations l, TripRequiredField f) =>
    switch (f) {
      TripRequiredField.departureCity => l.tripPublishDepartureCityLabel,
      TripRequiredField.arrivalCity => l.tripPublishArrivalCityLabel,
      TripRequiredField.departureDate => l.tripPublishDepartureDateLabel,
      TripRequiredField.departureTime => l.tripPublishDepartureTimeLabel,
      TripRequiredField.transportMode => l.tripPublishFieldTransportModeName,
      TripRequiredField.handoverDeadline => l.tripPublishHandoverDeadlineLabel,
      TripRequiredField.pickupAddress => l.tripPublishFieldPickupAddressName,
      TripRequiredField.deliveryAddress =>
        l.tripPublishFieldDeliveryAddressName,
    };

/// Message sous un champ vide, repris des gardes de la publication.
String tripRequiredFieldMessage(
  AppLocalizations l,
  TripRequiredField f,
) => switch (f) {
  TripRequiredField.departureCity => l.tripPublishFieldDepartureCityRequired,
  TripRequiredField.arrivalCity => l.tripPublishFieldArrivalCityRequired,
  TripRequiredField.departureDate => l.tripPublishFieldDepartureDateRequired,
  TripRequiredField.departureTime => l.tripPublishFieldDepartureTimeRequired,
  TripRequiredField.transportMode => l.tripPublishFieldTransportModeRequired,
  TripRequiredField.handoverDeadline =>
    l.tripPublishFieldHandoverDeadlineRequired,
  TripRequiredField.pickupAddress => l.tripPublishFieldPickupAddressRequired,
  TripRequiredField.deliveryAddress =>
    l.tripPublishFieldDeliveryAddressRequired,
};

/// Marque d'un champ obligatoire resté vide après « Continuer » : contour et
/// fond couleur d'avertissement, messages dessous dans la même couleur.
///
/// Non marqué, le champ est rendu tel quel (seuls les messages passés dans
/// [messages] restent, ex. date limite postérieure au départ).
class TripMissingFieldFrame extends StatelessWidget {
  const TripMissingFieldFrame({
    super.key,
    required this.marked,
    required this.child,
    this.messages = const [],
    this.messageKey,
  });

  final bool marked;
  final Widget child;
  final List<String> messages;

  /// Clé posée sur le premier message, pour les finders de test.
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(marked ? DonySpacing.xs : 0),
          decoration: BoxDecoration(
            color: marked ? cs.warningLight : null,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: marked
                ? Border.all(color: cs.warning, width: 1.5)
                : Border.all(color: Colors.transparent, width: 0),
          ),
          child: child,
        ),
        for (final (i, m) in messages.indexed)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(
                top: DonySpacing.xs,
                left: DonySpacing.base,
                right: DonySpacing.base,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DonyIcon(
                      'circle-alert',
                      size: 14,
                      color: cs.warning,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      m,
                      key: i == 0 ? messageKey : null,
                      style: tt.bodySmall?.copyWith(color: cs.warning),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bandeau en tête d'étape : « Il reste N champs obligatoires… ».
class TripMissingFieldsBanner extends StatelessWidget {
  const TripMissingFieldsBanner({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripMissingFieldsCubit, TripMissingFieldsState>(
      builder: (context, state) {
        if (!state.showSummaryAt(step)) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Semantics(
            liveRegion: true,
            child: Container(
              key: Key('trip-missing-banner-$step'),
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.warningLight,
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(color: cs.warning),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DonyIcon(
                      'circle-alert',
                      size: 18,
                      color: cs.warning,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      context.l10n.tripStepMissingBanner(state.missing.length),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Au-dessus du bouton du bas : « Il manque N champs : » et une pastille par
/// champ, qui fait défiler jusqu'à lui.
class TripMissingFieldsChips extends StatelessWidget {
  const TripMissingFieldsChips({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripMissingFieldsCubit, TripMissingFieldsState>(
      builder: (context, state) {
        if (!state.showSummaryAt(step)) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final l = context.l10n;
        return Padding(
          key: const Key('trip-missing-chips'),
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.tripStepMissingTitle(state.missing.length),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.xs,
                children: [
                  for (final f in state.missing)
                    ActionChip(
                      key: Key('trip-missing-chip-${f.name}'),
                      avatar: DonyIcon(
                        'circle-alert',
                        size: 14,
                        color: cs.warning,
                      ),
                      label: Text(
                        tripRequiredFieldLabel(l, f),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      side: BorderSide(color: cs.warning),
                      backgroundColor: cs.warningLight,
                      onPressed: () =>
                          context.read<TripMissingFieldsCubit>().chipTapped(f),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
