import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mes alertes prix (`/flights/alerts`, deeplink `yadony://flights/alerts`,
/// notification `FLIGHT_PRICE_ALERT`). Réservé aux comptes : un visiteur est
/// arrêté avant (bouton cloche de l'onglet Billets).
class FlightAlertsScreen extends StatelessWidget {
  const FlightAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<FlightAlertsCubit>()..load(),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<FlightAlertsCubit>();
    final created = await FlightAlertSheet.show(
      context,
      currencyCode: FlightsRepository.displayCurrencyFromHive() ?? 'EUR',
      onSubmit: (draft) async {
        final ok = await cubit.create(draft, source: 'alerts');
        if (!ok && context.mounted) {
          unawaited(ErrorPresenter.show(context, cubit.state.error));
        }
        return ok;
      },
    );
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
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<FlightAlertsCubit, FlightAlertsState>(
      // Erreur d'une bascule ou d'une suppression sur une liste déjà
      // affichée : snackbar. Une erreur de premier chargement s'affiche en
      // plein écran, une erreur de création depuis la feuille (`_create`),
      // liste vide comprise.
      listenWhen: (a, b) =>
          b.error != null &&
          b.error != a.error &&
          b.alerts.isNotEmpty &&
          !a.creating,
      listener: (context, state) => ErrorPresenter.show(context, state.error),
      builder: (context, state) {
        final full = state.alerts.length >= FlightAlertsCubit.maxAlerts;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DonyAppBar(
            title: l.flightsAlertsTitle,
            actions: [
              if (state.status == FlightAlertsStatus.loaded)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: DonySpacing.sm),
                    child: Text(
                      l.flightsAlertsCount(
                        state.alerts.length,
                        FlightAlertsCubit.maxAlerts,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton:
              state.status == FlightAlertsStatus.loaded &&
                  !full &&
                  state.alerts.isNotEmpty
              ? FlightPillButton(
                  key: const Key('flight-alerts-new'),
                  icon: 'plus',
                  label: l.flightsAlertNewTitle,
                  onPressed: () => _create(context),
                )
              : null,
          body: switch (state.status) {
            FlightAlertsStatus.initial ||
            FlightAlertsStatus.loading => ListView(
              key: const Key('flight-alerts-loading'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                0,
              ),
              children: const [
                DonyListCardSkeleton(),
                SizedBox(height: DonySpacing.md),
                DonyListCardSkeleton(),
                SizedBox(height: DonySpacing.md),
                DonyListCardSkeleton(),
              ],
            ),
            FlightAlertsStatus.error when state.alerts.isEmpty =>
              DonyEmptyState(
                mascotte: DonyMascotteType.erreurLegere,
                type: DonyEmptyStateType.error,
                title: l.commonLoadError,
                description: ErrorPresenter.resolve(
                  state.error,
                  l10n: l,
                ).message,
                actionLabel: l.commonRetry,
                onAction: context.read<FlightAlertsCubit>().load,
              ),
            _ when state.alerts.isEmpty => DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: l.flightsAlertsEmptyTitle,
              description: l.flightsAlertsEmptyDescription,
              actionLabel: l.flightsAlertNewTitle,
              onAction: () => _create(context),
            ),
            _ => ListView(
              key: const Key('flight-alerts-list'),
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                DonySpacing.huge * 2,
              ),
              children: [
                for (final alert in state.alerts) ...[
                  _AlertCard(alert: alert),
                  const SizedBox(height: DonySpacing.md),
                ],
                Text(
                  full ? l.flightsAlertsLimitReached : l.flightsAlertsFootnote,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          },
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final FlightAlert alert;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<FlightAlertsCubit>();

    String period(DateTime? from, DateTime? to) => from == null || to == null
        ? l.flightsAlertAnyDate
        : l.flightsAlertPeriod(
            FlightFormat.day(l, from),
            FlightFormat.day(l, to),
          );

    final details = [
      l.flightsAlertDepartureLine(
        period(alert.departureFrom, alert.departureTo),
      ),
      if (alert.isRoundTrip)
        l.flightsAlertReturnLine(period(alert.returnFrom, alert.returnTo))
      else
        l.flightsOneWay,
      if (alert.directOnly) l.flightsDirectOnly,
    ];
    final lastSeen = alert.lastSeenPrice;

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: DonyIcon('trash-2', color: cs.onError),
      ),
      onDismissed: (_) => cubit.delete(alert.id),
      child: Opacity(
        opacity: alert.active ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.flightsRouteTitle(
                        alert.originDisplay,
                        alert.destinationDisplay,
                      ),
                      style: tt.titleLarge,
                    ),
                  ),
                  FlightToggle(
                    key: Key('flight-alert-switch-${alert.id}'),
                    value: alert.active,
                    semanticLabel: l.flightsAlertActiveLabel,
                    onChanged: (v) => cubit.setActive(alert.id, v),
                  ),
                ],
              ),
              for (final line in details)
                Text(
                  line,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              const SizedBox(height: DonySpacing.sm),
              Row(
                children: [
                  _Figure(
                    label: l.flightsAlertThresholdShort,
                    value: l.flightsAlertAtMost(
                      FlightFormat.price(alert.maxPrice, alert.currency),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xl),
                  _Figure(
                    label: l.flightsAlertLastSeen,
                    value: lastSeen == null
                        ? l.flightsAlertNotChecked
                        : FlightFormat.price(lastSeen, alert.currency),
                    highlight: lastSeen != null && lastSeen <= alert.maxPrice,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? cs.success : cs.onSurface,
          ),
        ),
      ],
    );
  }
}
