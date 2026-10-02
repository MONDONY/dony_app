import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/first_steps_personalized.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Carte épinglée sur l'accueil : KYC vérifié et aucune première action.
bool shouldShowFirstActionCard(
  ActivationState state, {
  required bool isKycVerified,
}) =>
    isKycVerified && state is ActivationLoaded && !state.status.firstActionDone;

/// Rappel fixe (pas de croix) qui mène aux premiers pas tant que la personne
/// n'a ni publié, ni réservé, ni fait d'offre, ni créé d'alerte.
class FirstActionCard extends StatelessWidget {
  const FirstActionCard({super.key, required this.status, this.analytics});

  final ActivationStatus status;

  /// Injectable pour les tests ; `null` lit le service du conteneur.
  final AnalyticsService? analytics;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final code = status.destinationCountry;
    final country = code == null
        ? l.firstStepsYourDestination
        : countryName(l, code);
    final full = status.total > 0;
    final message = switch (status.intent) {
      null => l.firstActionCardUnknown,
      UserIntent.traveler =>
        full
            ? l.firstActionCardTravelerPackages(country)
            : l.firstActionCardTravelerNone,
      _ =>
        full
            ? l.firstActionCardSenderTrips(country)
            : l.firstActionCardSenderNone,
    };
    return DonyCard(
      key: const Key('first-action-card'),
      onTap: () {
        final service = analytics ?? getItSafe<AnalyticsService>();
        if (service != null) {
          unawaited(
            service.logEvent(
              AnalyticsEvents.firstActionCardTapped,
              properties: {'variant': firstStepsVariant(status)},
            ),
          );
        }
        unawaited(context.push(firstStepsRoute));
      },
      child: Row(
        children: [
          DonyIconContainer(
            iconAsset: 'sparkles',
            iconColor: cs.primary,
            backgroundColor: cs.primaryContainer,
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: DonySpacing.sm),
          Text(
            l.firstActionCardCta,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
