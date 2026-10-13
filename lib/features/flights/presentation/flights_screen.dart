import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_city_picker_screen.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_dates_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_filter_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_loading_view.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_recent_searches.dart';
import 'package:dony/features/flights/presentation/widgets/flight_results_parts.dart';
import 'package:dony/features/flights/presentation/widgets/flight_search_form.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouverture de l'écran Billets sur un bon plan touché ailleurs (bloc
/// « Billets d'avion » du hub Activités) : la recherche de ce trajet part dès
/// l'ouverture, comme un bon plan touché dans l'écran lui-même.
class FlightsLaunch {
  const FlightsLaunch({required this.deal, required this.personalized});

  final FlightDeal deal;
  final bool personalized;
}

/// Écran Billets (`/announcements/flights`, alias `/flights`) : billets
/// d'avion en affiliation, ouvert par-dessus le hub Activités, la barre
/// d'onglets restant visible.
///
/// Formulaire, recherches récentes et bons plans d'abord ; une recherche
/// lancée passe par l'écran d'attente puis bascule l'écran sur ses
/// résultats (retour au formulaire par la flèche ou la pastille résumé).
/// Yadony ne vend rien : une offre s'ouvre chez le partenaire, dans le
/// navigateur.
class FlightsScreen extends StatelessWidget {
  const FlightsScreen({super.key, this.launch});

  /// Bon plan à chercher dès l'ouverture ; `null` : formulaire prérempli.
  final FlightsLaunch? launch;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = getIt<FlightSearchCubit>();
            final launch = this.launch;
            if (launch != null) {
              unawaited(
                cubit.openDeal(launch.deal, personalized: launch.personalized),
              );
            } else {
              unawaited(cubit.loadDefaults());
            }
            return cubit;
          },
        ),
        BlocProvider(create: (_) => getIt<FlightDealsCubit>()..load()),
        BlocProvider(create: (_) => getIt<FlightLinkCubit>()),
      ],
      child: const _FlightsView(),
    );
  }
}

/// Ouvre les alertes prix, ou propose de créer un compte à un visiteur : les
/// alertes supposent une identité et un push.
Future<void> openFlightAlerts(BuildContext context) {
  if (!getIt<FirebaseSessionProbe>().hasRealSession) {
    return AuthRequiredSheet.show(
      context,
      reason: AuthRequiredReason.flightAlert,
    );
  }
  return context.push('/flights/alerts');
}

/// Nom affiché d'une ville de la recherche : le nom saisi, sinon le code.
String _cityName(FlightSearchState state, {required bool origin}) {
  final place = origin ? state.query.origin : state.query.destination;
  final code = origin
      ? state.result?.originCode
      : state.result?.destinationCode;
  return place?.name ?? code ?? '';
}

class _FlightsView extends StatelessWidget {
  const _FlightsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlightLinkCubit, FlightLinkState>(
      listenWhen: (a, b) => b.failures > a.failures,
      listener: (context, state) => ErrorPresenter.show(context, state.error),
      // Fond clair du thème : sans cette région, les icônes blanches posées
      // par l'écran d'attente (fond nuit) restaient sur les résultats.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: FlightStatusBar.of(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: BlocBuilder<FlightSearchCubit, FlightSearchState>(
            buildWhen: (a, b) => a.status != b.status,
            builder: (context, state) => AnimatedSwitcher(
              duration: DonyDuration.base,
              switchInCurve: DonyCurve.enter,
              switchOutCurve: DonyCurve.exit,
              child: switch (state.status) {
                FlightSearchStatus.editing => const SafeArea(
                  key: ValueKey('form'),
                  bottom: false,
                  child: _FormView(),
                ),
                FlightSearchStatus.loading => _Loading(
                  key: const ValueKey('loading'),
                  state: state,
                ),
                _ => const SafeArea(
                  key: ValueKey('results'),
                  bottom: false,
                  child: _ResultsView(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Formulaire, recherches récentes et bons plans ───────────────────────────

class _FormView extends StatelessWidget {
  const _FormView();

  Future<void> _pickRoute(
    BuildContext context, {
    required bool departure,
  }) async {
    final cubit = context.read<FlightSearchCubit>();
    final q = cubit.state.query;
    final pick = await pickFlightRoute(
      context,
      FlightRoutePickerArgs(
        origin: q.origin,
        destination: q.destination,
        departure: departure,
      ),
    );
    if (pick != null) {
      cubit.setRoute(origin: pick.origin, destination: pick.destination);
    }
  }

  Future<void> _pickDates(
    BuildContext context, {
    bool returnFirst = false,
  }) async {
    final cubit = context.read<FlightSearchCubit>();
    final q = cubit.state.query;
    final choice = await FlightDatesSheet.show(
      context,
      departure: q.departure,
      returnDate: q.returnDate,
      roundTrip: q.roundTrip,
      returnFirst: returnFirst,
    );
    if (choice != null) cubit.setDates(choice.departure, choice.returnDate);
  }

  /// Aller-retour sans date de retour : la feuille des dates s'ouvre sur le
  /// retour, puis la recherche part si la date est choisie.
  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<FlightSearchCubit>();
    if (cubit.state.query.needsReturnDate) {
      await _pickDates(context, returnFirst: true);
      if (cubit.state.query.needsReturnDate) return;
    }
    await cubit.search();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      key: const Key('flights-form'),
      padding: EdgeInsets.only(
        bottom: flightNavBarReserve(context) + DonySpacing.huge,
      ),
      children: [
        Padding(
          // À gauche, la zone tappable de 44 du bouton retour déborde de sa
          // pastille : la pastille tombe sur la marge du formulaire.
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.md,
            DonySpacing.sm,
            DonySpacing.xs,
            DonySpacing.sm,
          ),
          child: Row(
            children: [
              // Écran poussé par-dessus Activités : retour au hub. Ouvert par
              // un lien sans rien à dépiler, le hub est rouvert à la place.
              FlightRoundButton(
                key: const Key('flights-close'),
                icon: 'arrow-left',
                tooltip: l.commonBack,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/announcements'),
              ),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.flightsTitle, style: tt.displayMedium),
                ),
              ),
              FlightRoundButton(
                key: const Key('flights-alerts-button'),
                icon: 'bell',
                tooltip: l.flightsAlertsTooltip,
                onPressed: () => openFlightAlerts(context),
              ),
              const DonyFeedbackButton(),
            ],
          ),
        ),
        BlocBuilder<FlightSearchCubit, FlightSearchState>(
          buildWhen: (a, b) => a.query != b.query,
          builder: (context, state) {
            final cubit = context.read<FlightSearchCubit>();
            final q = state.query;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.lg,
                  ),
                  child: FlightTripTypeSwitch(
                    roundTrip: q.roundTrip,
                    onChanged: cubit.setRoundTrip,
                  ),
                ),
                const SizedBox(height: DonySpacing.md + DonySpacing.xxs),
                FlightSearchForm(
                  query: q,
                  onPickCity: ({required departure}) =>
                      _pickRoute(context, departure: departure),
                  onSwap: cubit.swap,
                  onPickDates: () => _pickDates(context),
                  onDirectChanged: cubit.setDirectOnly,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.base,
                    DonySpacing.lg,
                    0,
                  ),
                  child: DonyButton(
                    key: const Key('flights-search-button'),
                    label: l.flightsSearchButton,
                    iconAsset: 'search',
                    onPressed: q.isComplete ? () => _submit(context) : null,
                  ),
                ),
              ],
            );
          },
        ),
        BlocBuilder<FlightSearchCubit, FlightSearchState>(
          buildWhen: (a, b) => a.recents != b.recents,
          builder: (context, state) {
            if (state.recents.isEmpty) return const SizedBox.shrink();
            final cubit = context.read<FlightSearchCubit>();
            return FlightRecentSearches(
              key: const Key('flights-recents'),
              recents: state.recents,
              onOpen: cubit.openRecent,
              onClear: cubit.clearRecents,
            );
          },
        ),
        const _DealsSection(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.xl,
            DonySpacing.lg,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceWarm,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Text(
              l.flightsAffiliationNotice,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _DealsSection extends StatelessWidget {
  const _DealsSection();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<FlightDealsCubit, FlightDealsState>(
      builder: (context, state) {
        if (state.status == FlightDealsStatus.hidden ||
            state.status == FlightDealsStatus.initial) {
          return const SizedBox.shrink();
        }
        final loading = state.status == FlightDealsStatus.loading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.md,
              ),
              child: FlightSectionTitle(title: l.flightsDealsTitle),
            ),
            SizedBox(
              height: 196,
              child: ListView.separated(
                key: loading
                    ? const Key('flights-deals-loading')
                    : const Key('flights-deals'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
                clipBehavior: Clip.none,
                physics: loading ? const NeverScrollableScrollPhysics() : null,
                itemCount: loading ? 2 : state.deals.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DonySpacing.md),
                itemBuilder: (context, i) => loading
                    ? const _DealSkeleton()
                    // Calée en haut : la carte garde sa hauteur naturelle au
                    // lieu de s'étirer sur toute la bande.
                    : Align(
                        alignment: Alignment.topCenter,
                        child: FlightDealCard(
                          deal: state.deals[i],
                          onTap: () =>
                              context.read<FlightSearchCubit>().openDeal(
                                state.deals[i],
                                personalized: state.personalized,
                              ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Squelette d'un mini-billet, mêmes dimensions que [FlightDealCard].
class _DealSkeleton extends StatelessWidget {
  const _DealSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyShimmer(
      child: Container(
        width: FlightDealCard.width,
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: DonyShadow.sm,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DonySkeletonCircle(diameter: 26),
                SizedBox(width: DonySpacing.sm),
                DonySkeletonBox(width: 90),
              ],
            ),
            SizedBox(height: DonySpacing.base),
            DonySkeletonBox(height: 22),
            SizedBox(height: DonySpacing.sm),
            DonySkeletonBox(width: 120),
            Spacer(),
            DonySkeletonBox(width: 80, height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Attente ─────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading({super.key, required this.state});

  final FlightSearchState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = state.query;
    final chip = [
      FlightFormat.route(
        l,
        q.origin?.code ?? '',
        q.destination?.code ?? '',
        roundTrip: q.isRoundTrip,
      ),
      FlightFormat.dates(l, q.departure, q.returnDate),
      l.flightsPassengers(1),
    ].join(' · ');
    return FlightLoadingView(
      routeChip: chip,
      destinationName: _cityName(state, origin: false),
    );
  }
}

// ── Résultats ───────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView();

  Future<void> _openFilters(
    BuildContext context,
    FlightSearchState state,
    FlightFilterSection? section,
  ) async {
    final cubit = context.read<FlightSearchCubit>();
    final filters = await FlightFilterSheet.show(
      context,
      offers: state.result?.offers ?? const [],
      current: state.filters,
      currency: state.result?.currency ?? 'EUR',
      focus: section,
    );
    if (filters != null) cubit.applyFilters(filters);
  }

  Future<void> _createAlert(
    BuildContext context,
    FlightSearchState state,
  ) async {
    if (!getIt<FirebaseSessionProbe>().hasRealSession) {
      await AuthRequiredSheet.show(
        context,
        reason: AuthRequiredReason.flightAlert,
      );
      return;
    }
    final q = state.query;
    final alerts = getIt<FlightAlertsCubit>();
    DateTimeRange? range(FlightWhen? w) =>
        w == null ? null : DateTimeRange(start: w.first, end: w.last);
    final created = await FlightAlertSheet.show(
      context,
      origin: q.origin,
      destination: q.destination,
      departure: range(q.departure),
      returnRange: range(q.returnDate),
      directOnly: q.directOnly,
      currentLowest: state.cheapest?.price,
      currencyCode: state.result?.currency ?? 'EUR',
      onSubmit: (draft) async {
        final ok = await alerts.create(draft, source: 'results');
        if (!ok && context.mounted) {
          unawaited(ErrorPresenter.show(context, alerts.state.error));
        }
        return ok;
      },
    );
    unawaited(alerts.close());
    if ((created ?? false) && context.mounted) {
      DonySnackbar.show(
        context,
        message: context.l10n.flightsAlertCreated,
        type: DonySnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<FlightSearchCubit, FlightSearchState>(
      builder: (context, state) {
        final cubit = context.read<FlightSearchCubit>();
        final q = state.query;
        final roundTrip = state.result?.roundTrip ?? q.isRoundTrip;
        final route = FlightFormat.route(
          l,
          _cityName(state, origin: true),
          _cityName(state, origin: false),
          roundTrip: roundTrip,
        );
        final dates = FlightFormat.dates(l, q.departure, q.returnDate);
        final offers = state.result?.offers ?? const <FlightOffer>[];

        if (state.status == FlightSearchStatus.error ||
            (state.status == FlightSearchStatus.loaded && offers.isEmpty)) {
          final error = state.status == FlightSearchStatus.error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FlightResultsHeader(
                route: route,
                dates: dates,
                onBack: cubit.backToForm,
              ),
              Expanded(
                child: FlightEmptyResults(
                  title: error
                      ? l.flightsSearchErrorTitle
                      : l.flightsNoFlightsTitle,
                  body: error
                      ? ErrorPresenter.resolve(state.error, l10n: l).message
                      : l.flightsNoFlightsBody,
                  suggestions: _suggestions(context, state, error: error),
                  onLiveSearch: error || state.result?.searchPath == null
                      ? null
                      : () {
                          cubit.trackSuggestion(
                            FlightEmptySuggestion.aviasales,
                          );
                          context.read<FlightLinkCubit>().openAllAirlines(
                            state.result!,
                            from: 'empty',
                          );
                        },
                  liveSearchOpening: context.select<FlightLinkCubit, bool>(
                    (c) =>
                        c.state.openingPath != null &&
                        c.state.openingPath == state.result?.searchPath,
                  ),
                ),
              ),
            ],
          );
        }

        final visible = state.visibleOffers;
        final summaries = state.tabSummaries;
        final cheapest = summaries[FlightResultsTab.cheapest]?.offer;
        final fastest = summaries[FlightResultsTab.fastest]?.offer;
        final facets = FlightFacets.of(offers);
        final searchPath = state.result?.searchPath;
        // Vols à quelques jours des dates demandées : bandeau et dates.
        final nearby = state.result?.nearbyDates ?? false;

        Widget card(FlightOffer offer) {
          FlightOfferBadge? badge;
          if (visible.length > 1 && identical(offer, cheapest)) {
            badge = FlightOfferBadge.cheapest;
          } else if (visible.length > 1 && identical(offer, fastest)) {
            badge = FlightOfferBadge.fastest;
          }
          return BlocSelector<FlightLinkCubit, FlightLinkState, bool>(
            selector: (s) => s.openingPath == offer.offerPath,
            builder: (context, opening) => FlightOfferCard(
              offer: offer,
              badge: badge,
              opening: opening,
              showDates: nearby,
              requestedDeparture: q.departure,
              requestedReturn: q.returnDate,
              onOpen: () =>
                  context.read<FlightLinkCubit>().open(offer, source: 'search'),
            ),
          );
        }

        // Peu de vols ou vols à dates proches : notre cache est maigre sur ce
        // trajet, la recherche en direct d'Aviasales passe devant.
        final fewResults =
            searchPath != null &&
            (nearby || visible.length < FlightSearchState.fewResultsThreshold);

        Widget more(Key key, {bool prominent = false}) =>
            BlocSelector<FlightLinkCubit, FlightLinkState, bool>(
              selector: (s) => s.openingPath == searchPath,
              builder: (context, opening) => FlightAllAirlinesCard(
                key: key,
                opening: opening,
                prominent: prominent,
                onTap: () => context.read<FlightLinkCubit>().openAllAirlines(
                  state.result!,
                  from: 'results',
                ),
              ),
            );

        final items = <Widget>[
          if (nearby)
            FlightNearbyDatesNotice(
              key: const Key('flights-nearby-dates'),
              days: state.result!.nearbyDaysWindow,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xs,
              DonySpacing.xs,
              DonySpacing.xs,
              0,
            ),
            child: Text(
              roundTrip
                  ? l.flightsResultsSummaryRoundTrip(visible.length)
                  : l.flightsResultsSummaryOneWay(visible.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Liste maigre : Aviasales en tête, c'est là que sont les autres vols.
          if (fewResults)
            more(const Key('flights-all-airlines-top'), prominent: true),
          for (final (i, offer) in visible.indexed) ...[
            card(offer),
            if (!fewResults &&
                i == 2 &&
                visible.length > 3 &&
                searchPath != null)
              more(const Key('flights-all-airlines-inline')),
          ],
          if (searchPath != null && !fewResults)
            more(const Key('flights-all-airlines')),
        ];

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlightResultsHeader(
                  route: route,
                  dates: dates,
                  onBack: cubit.backToForm,
                ),
                FlightSortTabs(
                  summaries: summaries,
                  selected: state.effectiveTab,
                  onSelect: cubit.selectTab,
                ),
                const SizedBox(height: DonySpacing.xs),
                FlightFilterChips(
                  activeCount: state.filters.activeCount,
                  showAirlines: facets.airlines.isNotEmpty,
                  showTimes: facets.slots.isNotEmpty,
                  onOpen: (section) => _openFilters(context, state, section),
                ),
                Expanded(
                  child: ListView.separated(
                    key: const Key('flights-results'),
                    padding: EdgeInsets.fromLTRB(
                      DonySpacing.md,
                      0,
                      DonySpacing.md,
                      flightNavBarReserve(context) +
                          DonySpacing.huge +
                          DonySpacing.xxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, i) => SizedBox(
                      height: i == 0 ? DonySpacing.sm : DonySpacing.sm + 2,
                    ),
                    itemBuilder: (_, i) => items[i],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: flightNavBarReserve(context) + DonySpacing.base,
              child: Center(
                child: FlightPillButton(
                  key: const Key('flights-alert-fab'),
                  icon: 'bell',
                  label: l.flightsAlertFab,
                  onPressed: () => _createAlert(context, state),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Sorties de l'écran « Aucun vol » (ou d'erreur).
  List<FlightSuggestion> _suggestions(
    BuildContext context,
    FlightSearchState state, {
    required bool error,
  }) {
    final l = context.l10n;
    final cubit = context.read<FlightSearchCubit>();
    final q = state.query;
    final destination = _cityName(state, origin: false);
    final departure = q.departure;

    if (error) {
      return [
        FlightSuggestion(
          key: const Key('flights-retry'),
          icon: 'refresh-cw',
          title: l.commonRetry,
          subtitle: l.flightsRouteTitle(
            _cityName(state, origin: true),
            destination,
          ),
          onTap: cubit.search,
        ),
        _alertSuggestion(context, state),
      ];
    }

    return [
      if (q.origin != null &&
          q.origin!.code != FlightSearchCubit.paris.code &&
          q.destination?.code != FlightSearchCubit.paris.code)
        FlightSuggestion(
          key: const Key('flights-suggest-paris'),
          icon: 'plane',
          title: FlightFormat.route(
            l,
            FlightSearchCubit.paris.name,
            destination,
            roundTrip: q.isRoundTrip,
          ),
          subtitle: l.flightsSuggestSameDates,
          onTap: cubit.searchFromParis,
        ),
      if (departure != null && !departure.wholeMonth)
        FlightSuggestion(
          key: const Key('flights-suggest-month'),
          icon: 'calendar',
          title: l.flightsSuggestWholeMonth(
            FlightFormat.monthName(l, departure.date),
          ),
          subtitle: l.flightsSuggestFlexible(
            FlightFormat.route(
              l,
              _cityName(state, origin: true),
              destination,
              roundTrip: q.isRoundTrip,
            ),
          ),
          onTap: cubit.searchWholeMonth,
        ),
      _alertSuggestion(context, state),
    ];
  }

  FlightSuggestion _alertSuggestion(
    BuildContext context,
    FlightSearchState state,
  ) {
    final l = context.l10n;
    return FlightSuggestion(
      key: const Key('flights-suggest-alert'),
      icon: 'bell',
      accent: true,
      title: l.flightsSuggestAlert,
      subtitle: l.flightsSuggestAlertBody,
      onTap: () {
        context.read<FlightSearchCubit>().trackSuggestion(
          FlightEmptySuggestion.alert,
        );
        _createAlert(context, state);
      },
    );
  }
}
