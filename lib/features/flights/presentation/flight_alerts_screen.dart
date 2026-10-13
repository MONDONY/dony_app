import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:dony/features/flights/presentation/flight_alert_offers_screen.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

    final details = [
      ...FlightFormat.alertDates(l, alert),
      if (alert.directOnly) l.flightsDirectOnly,
      l.flightsAlertMaxShort(
        FlightFormat.price(alert.maxPrice, alert.currency),
      ),
    ];
    final muted = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);

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
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.md,
          DonySpacing.base,
          DonySpacing.md + DonySpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
          boxShadow: DonyShadow.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Une alerte en pause s'efface : trajet et détails pâlissent,
            // l'interrupteur reste net pour la relancer.
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: alert.active ? 1 : 0.55,
                    child: Text(
                      FlightFormat.route(
                        l,
                        alert.originDisplay,
                        alert.destinationDisplay,
                        roundTrip: alert.isRoundTrip,
                      ),
                      style: tt.titleLarge,
                    ),
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
            Opacity(
              opacity: alert.active ? 1 : 0.55,
              child: Text(
                details.join(' · '),
                style: muted?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.sm + DonySpacing.xxs),
            _AlertResult(alert: alert),
          ],
        ),
      ),
    );
  }
}

/// Où en est l'alerte, sous ses informations : vert avec le prix trouvé et
/// « Voir », gris avec le meilleur prix du moment, « En pause » ou « Pas
/// encore vérifiée », et « Voir les vols ». Tout le bloc ouvre les vols de
/// l'alerte, quel que soit son état.
class _AlertResult extends StatelessWidget {
  const _AlertResult({required this.alert});

  final FlightAlert alert;

  Future<void> _openOffers(BuildContext context) async {
    await context.push<Object?>(
      flightAlertOffersLocation(alert.id),
      extra: alert,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final price = alert.lastSeenPrice;
    final checkedAt = alert.lastCheckedAt;
    final checked = checkedAt == null
        ? null
        : l.flightsAlertCheckedAgo(
            FlightFormat.age(l, checkedAt.toLocal(), DateTime.now()),
          );
    final textStyle = tt.bodySmall?.copyWith(
      height: 1.35,
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final priceStyle = tt.headlineSmall?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    void open() => _openOffers(context);
    final seeAll = _SeeButton(
      key: Key('flight-alert-see-${alert.id}'),
      label: l.flightsAlertSeeFlights,
    );

    if (!alert.active) {
      return _ResultBox(
        key: const Key('flight-alert-result-paused'),
        dim: true,
        onTap: open,
        children: [
          Expanded(child: Text(l.flightsAlertResultPaused, style: textStyle)),
          const SizedBox(width: DonySpacing.sm),
          seeAll,
        ],
      );
    }
    if (!alert.checked) {
      return _ResultBox(
        key: const Key('flight-alert-result-pending'),
        onTap: open,
        children: [
          Expanded(child: Text(l.flightsAlertNotChecked, style: textStyle)),
          const SizedBox(width: DonySpacing.sm),
          seeAll,
        ],
      );
    }
    if (alert.hasHit) {
      final count = alert.matchCount;
      final headline = count != null && count > 0
          ? l.flightsAlertResultHit(count)
          : l.flightsAlertResultHitNoCount;
      return _ResultBox(
        key: const Key('flight-alert-result-hit'),
        color: cs.successLight,
        onTap: open,
        children: [
          if (price != null) ...[
            Text(
              FlightFormat.price(price, alert.currency),
              style: priceStyle?.copyWith(color: cs.success),
            ),
            const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          ],
          Expanded(
            child: Text(
              [headline, ?checked].join('\n'),
              style: textStyle?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          _SeeButton(
            key: Key('flight-alert-see-${alert.id}'),
            label: l.flightsAlertSeeOffers,
            highlight: true,
          ),
        ],
      );
    }
    // Au-dessus du seuil, ou plus rien de trouvé : le dernier prix vu ne
    // s'affiche que s'il est encore crédible ([FlightAlert.currentPrice]).
    final current = alert.currentPrice;
    final status = Text(
      [
        if (current != null)
          l.flightsAlertResultAbove(
            FlightFormat.price(alert.maxPrice, alert.currency),
          )
        else
          l.flightsAlertResultNoFlight,
        ?checked,
      ].join('\n'),
      style: textStyle,
    );
    return _ResultBox(
      key: const Key('flight-alert-result-above'),
      onTap: open,
      children: [
        // Le prix passe au-dessus du texte : la pilule « Voir les vols »
        // laisse trop peu de place pour les trois côte à côte.
        Expanded(
          child: current == null
              ? status
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FlightFormat.price(current, alert.currency),
                      style: priceStyle?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    status,
                  ],
                ),
        ),
        const SizedBox(width: DonySpacing.sm),
        seeAll,
      ],
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({
    super.key,
    required this.children,
    required this.onTap,
    this.color,
    this.dim = false,
  });

  final List<Widget> children;
  final VoidCallback onTap;

  /// Fond du bloc, gris doux par défaut.
  final Color? color;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: DonyPressable(
        onTap: onTap,
        scale: 0.98,
        child: Opacity(
          opacity: dim ? 0.7 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.all(DonySpacing.sm + DonySpacing.xxs),
            decoration: BoxDecoration(
              color: color ?? cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }
}

/// Pilule « Voir › » (verte, vols sous le prix) ou « Voir les vols › »
/// (neutre) : signale que le bloc ouvre les vols de l'alerte, le tap est
/// porté par tout le bloc ([_ResultBox]).
class _SeeButton extends StatelessWidget {
  const _SeeButton({super.key, required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = highlight ? cs.onPrimary : cs.onSurface;
    return Container(
      height: 32,
      padding: const EdgeInsetsDirectional.fromSTEB(
        DonySpacing.md,
        0,
        DonySpacing.sm,
        0,
      ),
      decoration: BoxDecoration(
        color: highlight ? cs.success : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: highlight ? null : Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: tt.labelLarge?.copyWith(fontSize: 12, color: fg)),
          const SizedBox(width: DonySpacing.xxs),
          DonyIcon('chevron-right', size: 14, color: fg),
        ],
      ),
    );
  }
}
