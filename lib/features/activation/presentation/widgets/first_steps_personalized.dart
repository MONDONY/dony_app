import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Variante analytics des premiers pas (`first_steps_choice.variant`).
String firstStepsVariant(ActivationStatus s) {
  final full = s.total > 0;
  return switch (s.intent) {
    null => 'unknown',
    UserIntent.sender => full ? 'sender_full' : 'sender_empty',
    UserIntent.both => full ? 'both_full' : 'both_empty',
    UserIntent.traveler => full ? 'traveler_full' : 'traveler_empty',
  };
}

/// Premiers pas selon l'intention : trajets de la ligne (expéditeur), colis
/// en attente (voyageur), alerte ou publication quand la ligne est vide.
class FirstStepsPersonalized extends StatelessWidget {
  const FirstStepsPersonalized({
    super.key,
    required this.status,
    required this.onChoose,
  });

  final ActivationStatus status;

  /// Trace le choix (`choice`, `variant`) puis exécute la navigation `go`.
  final void Function(String choice, String variant, VoidCallback go) onChoose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final variant = firstStepsVariant(status);
    final code = status.destinationCountry;
    final country = code == null
        ? l.firstStepsYourDestination
        : countryName(l, code);
    final isTraveler = status.intent == UserIntent.traveler;
    final full = status.total > 0;
    final dateFormat = DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    final String title;
    final String? subtitle;
    final String primaryLabel;
    final String primaryChoice;
    final VoidCallback primaryGo;
    if (isTraveler) {
      title = full
          ? l.firstStepsTravelerPackagesTitle(status.total, country)
          : l.firstStepsTravelerNoPackagesTitle;
      subtitle = null;
      primaryLabel = l.firstStepsTravelerCta;
      primaryChoice = 'publish_trip';
      primaryGo = () => context.go('/trips/publish-intro');
    } else if (full) {
      title = l.firstStepsSenderTripsTitle(status.total, country);
      subtitle = null;
      primaryLabel = l.firstStepsSenderTripsCta;
      primaryChoice = 'see_trips';
      primaryGo = () => context.go('/home');
    } else {
      title = l.firstStepsSenderNoTripsTitle(country);
      subtitle = l.firstStepsSenderNoTripsSubtitle;
      primaryLabel = l.firstStepsSenderAlertCta;
      primaryChoice = 'create_alert';
      // Une alerte exige des villes : le formulaire existant s'ouvre avec le
      // pays visé déjà renseigné.
      primaryGo = () => CorridorAlertFormSheet.show(
        context,
        prefill: CorridorAlertDraft(
          departureCity: '',
          arrivalCity: '',
          arrivalCountryCode: code,
          direction: AlertDirection.senderWantsTrips,
        ),
        isSender: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DonyIcon('shield-check', size: 18, color: cs.primary),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      l.firstStepsVerified,
                      style: text.labelLarge?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.base),
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: DonySpacing.lg),
                if (!isTraveler)
                  for (final t in status.trips)
                    _OpportunityTile(
                      key: Key('first-steps-trip-${t.id}'),
                      line: l.firstStepsTripLine(
                        t.departureCity,
                        t.arrivalCity,
                      ),
                      detail: [
                        dateFormat.format(t.departureDate),
                        if (t.availableKg != null)
                          l.firstStepsKgAvailable(
                            t.availableKg!.toStringAsFixed(0),
                          ),
                      ].join(' · '), // i18n-ignore
                      onTap: () => onChoose(
                        'open_trip',
                        variant,
                        () => context.push('/announcements/${t.id}/trip'),
                      ),
                    ),
                if (isTraveler)
                  for (final p in status.packages)
                    _OpportunityTile(
                      key: Key('first-steps-package-${p.id}'),
                      line: l.firstStepsTripLine(
                        p.departureCity,
                        p.arrivalCity,
                      ),
                      detail: [
                        dateFormat.format(p.desiredDate),
                        if (p.weightKg != null)
                          l.firstStepsPackageWeight(
                            p.weightKg!.toStringAsFixed(0),
                          ),
                      ].join(' · '), // i18n-ignore
                      onTap: () => onChoose(
                        'open_package',
                        variant,
                        () => context.push('/package-requests/${p.id}/public'),
                      ),
                    ),
              ],
            ),
          ),
        ),
        DonyButton(
          key: const Key('first-steps-primary'),
          label: primaryLabel,
          onPressed: () => onChoose(primaryChoice, variant, primaryGo),
        ),
        if (!isTraveler) ...[
          const SizedBox(height: DonySpacing.xs),
          DonyButton(
            key: const Key('first-steps-publish-parcel'),
            label: l.firstStepsSenderPublishLink,
            variant: DonyButtonVariant.ghost,
            onPressed: () => onChoose(
              'publish_parcel',
              variant,
              () => context.go('/parcels/send-intro'),
            ),
          ),
        ],
        if (status.intent == UserIntent.both)
          DonyButton(
            key: const Key('first-steps-both-travel'),
            label: l.firstStepsBothTravelLink,
            variant: DonyButtonVariant.ghost,
            onPressed: () => onChoose(
              'publish_trip',
              variant,
              () => context.go('/trips/publish-intro'),
            ),
          ),
      ],
    );
  }
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile({
    super.key,
    required this.line,
    required this.detail,
    required this.onTap,
  });

  final String line;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: DonyCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: text.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
