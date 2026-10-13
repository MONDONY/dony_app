import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/presentation/flights_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:dony/features/settings/presentation/widgets/flights_visible_builder.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran Billets, ouvert par-dessus le hub dans la branche Activités.
const kActivitesFlightsRoute = '/announcements/flights';

/// Bloc « Billets d'avion » du hub Activités, à la place des statistiques
/// (parties dans le menu ☰) : titre et « Tout voir », mini-billets des bons
/// plans qui défilent de côté, puis « Rechercher un vol ».
///
/// Entièrement masqué, sans charger les bons plans, tant que le flag
/// `flights_enabled` est éteint ou que l'utilisateur a coupé « Afficher les
/// billets d'avion » dans les Paramètres. Sans bon
/// plan (liste vide ou échec), seuls le titre et le bouton restent : la
/// recherche reste l'action principale.
class ActivitesFlightsSection extends StatelessWidget {
  const ActivitesFlightsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FlightsVisibleBuilder(
      builder: (context, shown) {
        if (!shown) return const SizedBox.shrink();
        return BlocProvider(
          create: (_) => getIt<FlightDealsCubit>()..load(),
          child: const _FlightsSectionView(),
        );
      },
    );
  }
}

void _log(String event, [Map<String, Object>? properties]) {
  unawaited(getIt<AnalyticsService>().logEvent(event, properties: properties));
}

class _FlightsSectionView extends StatelessWidget {
  const _FlightsSectionView();

  void _openFlights(BuildContext context, String event) {
    _log(event);
    unawaited(context.push<Object?>(kActivitesFlightsRoute));
  }

  void _openDeal(BuildContext context, FlightDeal deal, bool personalized) {
    _log(AnalyticsEvents.activitesHubFlightsDealOpened, {
      'discount_percent': deal.discountPercent,
    });
    unawaited(
      context.push<Object?>(
        kActivitesFlightsRoute,
        extra: FlightsLaunch(deal: deal, personalized: personalized),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Column(
      key: const Key('hub-flights-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.xl,
            DonySpacing.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.activityFlightsSectionTitle,
                  style: tt.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('hub-flights-see-all'),
                onPressed: () => _openFlights(
                  context,
                  AnalyticsEvents.activitesHubFlightsSeeAllTapped,
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(kDonyMinTapTarget, kDonyMinTapTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                  ),
                  foregroundColor: cs.primary,
                  textStyle: tt.labelLarge,
                ),
                child: Text(l.activityFlightsSeeAll),
              ),
            ],
          ),
        ),
        BlocBuilder<FlightDealsCubit, FlightDealsState>(
          builder: (context, state) {
            if (state.status == FlightDealsStatus.hidden) {
              return const SizedBox(height: DonySpacing.xs);
            }
            final loading = state.status != FlightDealsStatus.loaded;
            return Padding(
              padding: const EdgeInsets.only(top: DonySpacing.xs),
              child: SingleChildScrollView(
                key: Key(
                  loading ? 'hub-flights-deals-loading' : 'hub-flights-deals',
                ),
                scrollDirection: Axis.horizontal,
                physics: loading ? const NeverScrollableScrollPhysics() : null,
                // L'ombre des mini-billets déborde : ni coupée en haut ni en
                // bas, et le carrousel va jusqu'aux bords de l'écran.
                clipBehavior: Clip.none,
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xs,
                  DonySpacing.lg,
                  DonySpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      for (var i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: DonySpacing.md),
                        const FlightDealMiniCardSkeleton(),
                      ]
                    else
                      for (var i = 0; i < state.deals.length; i++) ...[
                        if (i > 0) const SizedBox(width: DonySpacing.md),
                        FlightDealMiniCard(
                          key: Key('hub-flight-deal-$i'),
                          deal: state.deals[i],
                          onTap: () => _openDeal(
                            context,
                            state.deals[i],
                            state.personalized,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            0,
          ),
          child: DonyButton(
            key: const Key('hub-flights-search'),
            label: l.flightsSearchButton,
            iconAsset: 'search',
            variant: DonyButtonVariant.secondary,
            onPressed: () => _openFlights(
              context,
              AnalyticsEvents.activitesHubFlightsSearchTapped,
            ),
          ),
        ),
      ],
    );
  }
}
