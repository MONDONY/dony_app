import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_billet_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_city_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_dates_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_filter_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// « Abidjan (ABJ) », ou le code seul quand la ville n'a pas de nom (trajet
/// repris d'un bon plan, qui ne porte que les codes).
String _placeLabel(FlightPlace place) =>
    place.name == place.code ? place.code : '${place.name} (${place.code})';

/// Onglet Billets (`/flights`) : billets d'avion en affiliation.
///
/// Formulaire et bons plans d'abord ; une recherche lancée bascule l'onglet
/// sur ses résultats (même écran, flèche de retour vers le formulaire).
/// Yadony ne vend rien : « Voir l'offre » ouvre le site partenaire dans le
/// navigateur.
class FlightsScreen extends StatelessWidget {
  const FlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<FlightSearchCubit>()..loadDefaults()),
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

class _FlightsView extends StatelessWidget {
  const _FlightsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlightLinkCubit, FlightLinkState>(
      listenWhen: (a, b) => b.failures > a.failures,
      listener: (context, state) => ErrorPresenter.show(context, state.error),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<FlightSearchCubit, FlightSearchState>(
            buildWhen: (a, b) => a.showsResults != b.showsResults,
            builder: (context, state) =>
                state.showsResults ? const _ResultsView() : const _FormView(),
          ),
        ),
      ),
    );
  }
}

// ── Formulaire et bons plans ────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      key: const Key('flights-form'),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(l.flightsTitle, style: tt.displayMedium),
              ),
            ),
            IconButton(
              key: const Key('flights-alerts-button'),
              tooltip: l.flightsAlertsTooltip,
              onPressed: () => openFlightAlerts(context),
              icon: DonyIcon('bell', color: cs.onSurface),
            ),
            const DonyFeedbackButton(),
          ],
        ),
        const SizedBox(height: DonySpacing.base),
        const _SearchForm(),
        const SizedBox(height: DonySpacing.xl),
        const _DealsSection(),
        const SizedBox(height: DonySpacing.base),
        Container(
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
      ],
    );
  }
}

class _SearchForm extends StatelessWidget {
  const _SearchForm();

  Future<void> _pickDates(BuildContext context, FlightSearchQuery q) async {
    final cubit = context.read<FlightSearchCubit>();
    final choice = await FlightDatesSheet.show(
      context,
      departure: q.departure,
      returnDate: q.returnDate,
    );
    if (choice != null) cubit.setDates(choice.departure, choice.returnDate);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<FlightSearchCubit, FlightSearchState>(
      buildWhen: (a, b) => a.query != b.query,
      builder: (context, state) {
        final cubit = context.read<FlightSearchCubit>();
        final q = state.query;
        String when(FlightWhen? w) => w == null
            ? l.flightsDatesAny
            : w.wholeMonth
            ? FlightFormat.month(l, w.date)
            : FlightFormat.dateTime(l, w.date, withTime: false);

        // Material et non Container décoré : l'interrupteur (ListTile) peint
        // son encre sur le Material le plus proche.
        return Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            side: BorderSide(color: cs.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        DonyTextField.tappable(
                          key: const Key('flights-origin'),
                          label: l.flightsFieldDeparture,
                          value: q.origin == null
                              ? null
                              : _placeLabel(q.origin!),
                          onTap: () async {
                            final place = await FlightCitySheet.show(
                              context,
                              departure: true,
                            );
                            if (place != null) cubit.setOrigin(place);
                          },
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        DonyTextField.tappable(
                          key: const Key('flights-destination'),
                          label: l.flightsFieldArrival,
                          value: q.destination == null
                              ? null
                              : _placeLabel(q.destination!),
                          onTap: () async {
                            final place = await FlightCitySheet.show(
                              context,
                              departure: false,
                            );
                            if (place != null) cubit.setDestination(place);
                          },
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      end: DonySpacing.md,
                      top: 34,
                      child: Material(
                        color: cs.surface,
                        shape: CircleBorder(
                          side: BorderSide(color: cs.outline),
                        ),
                        child: IconButton(
                          key: const Key('flights-swap'),
                          tooltip: l.flightsSwapTooltip,
                          onPressed: cubit.swap,
                          icon: RotatedBox(
                            quarterTurns: 1,
                            child: DonyIcon(
                              'arrow-left-right',
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DonyTextField.tappable(
                        key: const Key('flights-departure-date'),
                        label: l.flightsOutboundLabel,
                        value: when(q.departure),
                        onTap: () => _pickDates(context, q),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: DonyTextField.tappable(
                        key: const Key('flights-return-date'),
                        label: l.flightsReturnLabel,
                        value: q.returnDate == null
                            ? l.flightsOneWay
                            : when(q.returnDate),
                        onTap: () => _pickDates(context, q),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  key: const Key('flights-direct'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.flightsDirectOnly),
                  value: q.directOnly,
                  onChanged: cubit.setDirectOnly,
                ),
                DonyButton(
                  key: const Key('flights-search-button'),
                  label: l.flightsSearchButton,
                  onPressed: q.isComplete ? cubit.search : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DealsSection extends StatelessWidget {
  const _DealsSection();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<FlightDealsCubit, FlightDealsState>(
      builder: (context, state) {
        if (state.status == FlightDealsStatus.hidden ||
            state.status == FlightDealsStatus.initial) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.flightsDealsTitle, style: tt.headlineMedium),
            const SizedBox(height: DonySpacing.md),
            SizedBox(
              height: 196,
              child: state.status == FlightDealsStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      key: const Key('flights-deals'),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: state.deals.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: DonySpacing.md),
                      itemBuilder: (context, i) => FlightDealCard(
                        deal: state.deals[i],
                        onTap: () => context.read<FlightSearchCubit>().openDeal(
                          state.deals[i],
                          personalized: state.personalized,
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

// ── Résultats ───────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView();

  Future<void> _openFilters(
    BuildContext context,
    FlightSearchState state,
  ) async {
    final cubit = context.read<FlightSearchCubit>();
    final filters = await FlightFilterSheet.show(
      context,
      offers: state.result?.offers ?? const [],
      current: state.filters,
      currency: state.result?.currency ?? 'EUR',
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<FlightSearchCubit, FlightSearchState>(
      builder: (context, state) {
        final cubit = context.read<FlightSearchCubit>();
        final q = state.query;
        final originName = q.origin?.name ?? state.result?.originCode ?? '';
        final destinationName =
            q.destination?.name ?? state.result?.destinationCode ?? '';
        final offers = state.visibleOffers;
        final cheapest = state.cheapest;
        final fastest = state.fastest;

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs,
            DonySpacing.sm,
            DonySpacing.sm,
            DonySpacing.sm,
          ),
          child: Row(
            children: [
              DonyAppBarBackButton(onBack: cubit.backToForm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.flightsRouteTitle(originName, destinationName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineMedium,
                    ),
                    if (state.status == FlightSearchStatus.loaded)
                      Text(
                        l.flightsResultsCount(offers.length),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('flights-create-alert'),
                tooltip: l.flightsAlertCreateTooltip,
                onPressed: state.status == FlightSearchStatus.loaded
                    ? () => _createAlert(context, state)
                    : null,
                icon: DonyIcon('bell', color: cs.primary),
              ),
              const DonyFeedbackButton(),
            ],
          ),
        );

        final Widget body = switch (state.status) {
          FlightSearchStatus.loading || FlightSearchStatus.editing => ListView(
            padding: const EdgeInsets.all(DonySpacing.lg),
            children: const [
              DonyTicketCardSkeleton(),
              SizedBox(height: DonySpacing.base),
              DonyTicketCardSkeleton(),
            ],
          ),
          FlightSearchStatus.error => DonyEmptyState(
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            title: l.commonLoadError,
            description: ErrorPresenter.resolve(state.error, l10n: l).message,
            actionLabel: l.commonRetry,
            onAction: cubit.search,
          ),
          FlightSearchStatus.loaded when (state.result?.offers ?? []).isEmpty =>
            DonyEmptyState(
              mascotte: DonyMascotteType.aucunResultat,
              title: l.flightsEmptyTitle,
              description: l.flightsEmptyDescription,
              actionLabel: l.flightsAlertCreate,
              onAction: () => _createAlert(context, state),
            ),
          FlightSearchStatus.loaded => ListView.separated(
            key: const Key('flights-results'),
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              0,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            itemCount: offers.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: DonySpacing.base),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _FilterBar(
                  activeFilters: state.filters.isFiltering,
                  onTap: () => _openFilters(context, state),
                );
              }
              final offer = offers[i - 1];
              return BlocSelector<FlightLinkCubit, FlightLinkState, bool>(
                selector: (s) => s.openingPath == offer.offerPath,
                builder: (context, opening) => FlightBilletCard(
                  offer: offer,
                  originName: originName,
                  destinationName: destinationName,
                  cheapest: offers.length > 1 && identical(offer, cheapest),
                  fastest:
                      offers.length > 1 &&
                      !identical(offer, cheapest) &&
                      identical(offer, fastest),
                  opening: opening,
                  onOpen: () => context.read<FlightLinkCubit>().open(
                    offer,
                    source: 'search',
                  ),
                ),
              );
            },
          ),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.activeFilters, required this.onTap});

  final bool activeFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DonyChip(
        key: const Key('flights-filters'),
        label: activeFilters ? l.flightsFiltersActive : l.flightsFiltersTitle,
        selected: activeFilters,
        icon: Icons.tune_rounded,
        onTap: onTap,
      ),
    );
  }
}
