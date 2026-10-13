import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_alert_offers_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_results_parts.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Chemin de l'écran « Vols trouvés » d'une alerte. [notification] : ouvert
/// depuis une notification `FLIGHT_PRICE_ALERT` (propriété `source` de
/// `flights_alert_offers_viewed`).
String flightAlertOffersLocation(String alertId, {bool notification = false}) =>
    '/flights/alerts/$alertId/offers${notification ? '?source=notification' : ''}';

/// Vols trouvés par une alerte prix (`/flights/alerts/:id/offers`) : les vols
/// de la période sous le seuil, du moins cher au plus cher. Ouvert par
/// « Voir » dans « Mes alertes » (l'alerte arrive en `extra`) ou par la
/// notification `FLIGHT_PRICE_ALERT`.
///
/// Les prix sont relus à l'ouverture. Plus rien sous le seuil (ou un back
/// qui ne connaît pas encore la route) : l'écran le dit et propose la
/// recherche en direct sur Aviasales.
class FlightAlertOffersScreen extends StatelessWidget {
  const FlightAlertOffersScreen({
    super.key,
    required this.alertId,
    this.alert,
    this.source = FlightAlertOffersSource.list,
  });

  final String alertId;
  final FlightAlert? alert;
  final FlightAlertOffersSource source;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<FlightAlertOffersCubit>(
            param1: FlightAlertOffersArgs(
              alertId: alertId,
              alert: alert,
              source: source,
            ),
          )..load(),
        ),
        BlocProvider(create: (_) => getIt<FlightLinkCubit>()),
      ],
      child: const _OffersView(),
    );
  }
}

class _OffersView extends StatelessWidget {
  const _OffersView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return BlocListener<FlightLinkCubit, FlightLinkState>(
      listenWhen: (a, b) => b.failures > a.failures,
      listener: (context, state) => ErrorPresenter.show(context, state.error),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: FlightStatusBar.of(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.sm,
                    DonySpacing.xs,
                    DonySpacing.xs,
                  ),
                  child: Row(
                    children: [
                      FlightRoundButton(
                        key: const Key('flight-alert-offers-back'),
                        icon: 'arrow-left',
                        tooltip: l.commonBack,
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/flights/alerts'),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Expanded(
                        child: Text(
                          l.flightsAlertOffersTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const DonyFeedbackButton(),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      BlocBuilder<
                        FlightAlertOffersCubit,
                        FlightAlertOffersState
                      >(
                        builder: (context, state) => AnimatedSwitcher(
                          duration: DonyDuration.base,
                          switchInCurve: DonyCurve.enter,
                          switchOutCurve: DonyCurve.exit,
                          child: switch (state.status) {
                            FlightAlertOffersStatus.loading =>
                              const _OffersSkeleton(),
                            FlightAlertOffersStatus.error => DonyEmptyState(
                              key: const Key('flight-alert-offers-error'),
                              mascotte: DonyMascotteType.erreurLegere,
                              type: DonyEmptyStateType.error,
                              title: l.commonLoadError,
                              description: ErrorPresenter.resolve(
                                state.error,
                                l10n: l,
                              ).message,
                              actionLabel: l.commonRetry,
                              onAction: context
                                  .read<FlightAlertOffersCubit>()
                                  .load,
                            ),
                            FlightAlertOffersStatus.empty => _EmptyView(
                              key: const Key('flight-alert-offers-empty'),
                              state: state,
                            ),
                            FlightAlertOffersStatus.loaded => _OffersList(
                              key: const Key('flight-alert-offers-list'),
                              state: state,
                            ),
                          },
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre la recherche Aviasales du trajet, quand il y en a une.
VoidCallback? _aviasales(BuildContext context, FlightAlertOffersState state) {
  final target = state.aviasalesTarget(DateTime.now());
  if (target == null) return null;
  return () =>
      context.read<FlightLinkCubit>().openAllAirlines(target, from: 'alert');
}

bool _aviasalesOpening(BuildContext context, FlightAlertOffersState state) {
  final path = state.searchPath(DateTime.now());
  return context.select<FlightLinkCubit, bool>(
    (c) => path != null && c.state.openingPath == path,
  );
}

class _OffersList extends StatelessWidget {
  const _OffersList({super.key, required this.state});

  final FlightAlertOffersState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final result = state.result!;
    final cheapest = result.cheapest!;
    final onAviasales = _aviasales(context, state);
    final opening = _aviasalesOpening(context, state);
    final aviasalesBody = switch (state.aviasales(DateTime.now())?.day) {
      FlightAviasalesDay.cheapest => l.flightsAlertOffersMoreBodyCheapest,
      FlightAviasalesDay.tomorrow => l.flightsAlertOffersMoreBodyTomorrow,
      _ => l.flightsAlertOffersMoreBody,
    };

    String savings(FlightOffer offer) {
      final diff = result.maxPrice - offer.price;
      if (diff < 1) return l.flightsAlertAtYourPrice;
      return l.flightsAlertBelowBy(FlightFormat.price(diff, offer.currency));
    }

    final items = <Widget>[
      _Summary(state: state),
      _Banner(
        text: l.flightsAlertOffersBanner(
          result.offers.length,
          FlightFormat.price(cheapest.price, cheapest.currency),
        ),
      ),
      for (final offer in result.offers)
        BlocSelector<FlightLinkCubit, FlightLinkState, bool>(
          selector: (s) => s.openingPath == offer.offerPath,
          builder: (context, opening) => FlightOfferCard(
            offer: offer,
            opening: opening,
            showDates: true,
            savingsLabel: savings(offer),
            onOpen: () =>
                context.read<FlightLinkCubit>().open(offer, source: 'alert'),
          ),
        ),
      if (onAviasales != null)
        FlightAllAirlinesCard(
          key: const Key('flight-alert-offers-aviasales'),
          title: l.flightsAlertOffersMoreTitle,
          body: aviasalesBody,
          opening: opening,
          onTap: onAviasales,
        ),
    ];

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.xs,
        DonySpacing.base,
        flightNavBarReserve(context) + DonySpacing.huge,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.sm + 2),
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key, required this.state});

  final FlightAlertOffersState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasSummary = state.result != null || state.alert != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSummary)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.xs,
              DonySpacing.base,
              DonySpacing.sm + 2,
            ),
            child: _Summary(state: state),
          ),
        Expanded(
          child: FlightEmptyResults(
            title: l.flightsAlertOffersEmptyTitle,
            body: l.flightsAlertOffersEmptyBody,
            suggestions: const [],
            onLiveSearch: _aviasales(context, state),
            liveSearchOpening: _aviasalesOpening(context, state),
          ),
        ),
      ],
    );
  }
}

/// Carte résumé de l'alerte : trajet, période, aller simple ou
/// aller-retour, prix max.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final FlightAlertOffersState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final FlightAlertOffers? r = state.result;
    final a = state.alert;
    final origin = r?.originLabel ?? a?.originDisplay ?? r?.originCode ?? '';
    final destination =
        r?.destinationLabel ??
        a?.destinationDisplay ??
        r?.destinationCode ??
        '';
    final roundTrip = r?.roundTrip ?? a?.isRoundTrip ?? false;
    final maxPrice = r?.maxPrice ?? a?.maxPrice;
    final currency = r?.currency ?? a?.currency ?? 'EUR';
    final details = [
      if (a != null)
        ...FlightFormat.alertDates(l, a)
      else if (roundTrip)
        l.flightsRoundTrip
      else
        l.flightsOneWay,
      if (maxPrice != null)
        l.flightsAlertOffersMax(FlightFormat.price(maxPrice, currency)),
    ];

    return Container(
      key: const Key('flight-alert-offers-summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm + DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlightFormat.route(l, origin, destination, roundTrip: roundTrip),
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            details.join(' · '),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau vert « 3 vols sous votre prix, le moins cher à 389 € ».
class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('flight-alert-offers-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm + DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
      ),
      child: Row(
        children: [
          DonyIcon('check', size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          Expanded(
            child: Text(
              text,
              style: tt.bodySmall?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: cs.success,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chargement léger : le résumé et trois cartes de vol en squelette.
class _OffersSkeleton extends StatelessWidget {
  const _OffersSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    BoxDecoration card() => BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      border: Border.all(color: cs.outline),
    );
    return DonyShimmer(
      child: ListView(
        key: const Key('flight-alert-offers-loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.xs,
          DonySpacing.base,
          0,
        ),
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: card(),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DonySkeletonBox(width: 140, height: 14),
                SizedBox(height: DonySpacing.xs + DonySpacing.xxs),
                DonySkeletonBox(width: 200, height: 10),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: DonySpacing.sm + 2),
            Container(
              height: 136,
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: card(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DonySkeletonCircle(diameter: 24),
                      SizedBox(width: DonySpacing.sm),
                      DonySkeletonBox(width: 120, height: 11),
                      Spacer(),
                      DonySkeletonBox(
                        width: 90,
                        height: 18,
                        radius: DonyRadius.full,
                      ),
                    ],
                  ),
                  SizedBox(height: DonySpacing.md),
                  Row(
                    children: [
                      DonySkeletonBox(width: 48, height: 18),
                      Spacer(),
                      DonySkeletonBox(width: 90, height: 8),
                      Spacer(),
                      DonySkeletonBox(width: 48, height: 18),
                    ],
                  ),
                  Spacer(),
                  Row(
                    children: [
                      DonySkeletonBox(width: 80, height: 10),
                      Spacer(),
                      DonySkeletonBox(width: 64, height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
