import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/bloc/flight_alerts_summary.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_alert_sheet.dart';
import 'package:dony/features/flights/presentation/widgets/flight_price_ticket.dart';
import 'package:dony/features/settings/presentation/widgets/flights_visible_builder.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Mes alertes prix », hors shell.
const kFlightAlertsRoute = '/flights/alerts';

/// La ligne des alertes prix a sa place : billets activés et vrai compte (un
/// visiteur n'a pas d'alerte, le serveur la refuserait).
bool flightAlertsRowAvailable() =>
    flightsShown() &&
    getIt.isRegistered<FirebaseSessionProbe>() &&
    getIt<FirebaseSessionProbe>().hasRealSession;

/// Ligne « Alertes prix vols », en tête des Outils d'Activités : de la
/// hauteur d'un outil, avec à droite une étiquette en forme de billet.
///
/// - un prix trouvé : icône verte, logos des compagnies, trajet et nombre
///   de vols ; billet vert avec le prix et l'écart avec le seuil ;
/// - rien sous le seuil : icône bleue, nombre d'alertes actives ; billet
///   gris avec le meilleur prix vu (aucun billet sans prix connu) ;
/// - aucune alerte : billet bleu « Créer », qui ouvre la feuille de
///   création.
///
/// Toucher la ligne ouvre « Mes alertes ». Le [FlightAlertsCubit] vient du
/// hub, qui le recharge au retour sur l'onglet et au tirer pour rafraîchir.
/// Masquée tant que le flag `flights_enabled` est éteint, quand l'utilisateur
/// a coupé « Afficher les billets d'avion » dans les Paramètres, et pour un
/// visiteur.
class ActivitesFlightAlertsRow extends StatelessWidget {
  const ActivitesFlightAlertsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return FlightsVisibleBuilder(
      builder: (context, _) {
        if (!flightAlertsRowAvailable()) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(bottom: DonySpacing.md),
          child: _AlertsRowLoader(),
        );
      },
    );
  }
}

/// Lance le premier chargement quand la ligne apparaît : le flag peut
/// s'allumer après le montage du hub.
class _AlertsRowLoader extends StatefulWidget {
  const _AlertsRowLoader();

  @override
  State<_AlertsRowLoader> createState() => _AlertsRowLoaderState();
}

class _AlertsRowLoaderState extends State<_AlertsRowLoader> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<FlightAlertsCubit>();
    if (cubit.state.status == FlightAlertsStatus.initial) {
      unawaited(cubit.load());
    }
  }

  @override
  Widget build(BuildContext context) => const _AlertsRow();
}

class _AlertsRow extends StatelessWidget {
  const _AlertsRow();

  Future<void> _openAlerts(BuildContext context) async {
    final cubit = context.read<FlightAlertsCubit>()..trackHubOpened();
    await context.push<Object?>(kFlightAlertsRoute);
    // Une alerte créée, coupée ou supprimée là-bas doit se voir ici.
    if (!cubit.isClosed) unawaited(cubit.load(silent: true));
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<FlightAlertsCubit>();
    final created = await FlightAlertSheet.show(
      context,
      currencyCode: FlightsRepository.displayCurrencyFromHive() ?? 'EUR',
      onSubmit: (draft) async {
        final ok = await cubit.create(draft, source: 'hub');
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
    return BlocBuilder<FlightAlertsCubit, FlightAlertsState>(
      builder: (context, state) {
        final loading =
            (state.status == FlightAlertsStatus.initial ||
                state.status == FlightAlertsStatus.loading) &&
            state.alerts.isEmpty;
        if (loading) return const _RowSkeleton();
        // Échec du chargement : une ligne neutre qui mène quand même aux
        // alertes, sans billet ni état inventé.
        final failed =
            state.status == FlightAlertsStatus.error && state.alerts.isEmpty;
        return _RowContent(
          summary: failed ? null : state.summary,
          onTap: () => _openAlerts(context),
          onCreate: () => _create(context),
        );
      },
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.summary,
    required this.onTap,
    required this.onCreate,
  });

  /// `null` : chargement en échec, ligne neutre.
  final FlightAlertsSummary? summary;
  final VoidCallback onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = summary;
    final hit = s?.kind == FlightAlertsSummaryKind.hit;

    final subStyle = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget subtitle;
    final Widget trailing;
    final String state;
    switch (s?.kind) {
      case FlightAlertsSummaryKind.hit:
        state = 'hit';
        final best = s!.best!;
        final many = s.hitCount > 1;
        final route = FlightFormat.route(
          l,
          best.originDisplay,
          best.destinationDisplay,
          roundTrip: best.isRoundTrip,
        );
        final price = s.price;
        final count = best.matchCount ?? 0;
        Text line(String text) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subStyle,
        );
        subtitle = Row(
          children: [
            if (many && price != null)
              Flexible(
                child: line(
                  l.activityFlightAlertsHitMany(
                    s.hitCount,
                    FlightFormat.alertPrice(price, s.currency!),
                  ),
                ),
              )
            else
              Expanded(
                child: _RouteLine(
                  route: route,
                  flights: count > 0
                      ? ' · ${l.activityFlightAlertsHitFlights(count)}'
                      : null,
                  codes: best.matchAirlineCodes,
                  style: subStyle,
                ),
              ),
          ],
        );
        trailing = price == null
            ? const _Chevron()
            : FlightPriceTicket(
                key: const Key('hub-flight-alerts-ticket-hit'),
                tone: FlightPriceTicketTone.hit,
                label: FlightFormat.alertPrice(price, s.currency!),
                caption: _savingsCaption(l, s),
              );
      case FlightAlertsSummaryKind.noHit:
        state = 'no_hit';
        subtitle = Text(
          l.activityFlightAlertsActive(s!.activeCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subStyle,
        );
        final price = s.price;
        trailing = price == null
            ? const _Chevron()
            : FlightPriceTicket(
                key: const Key('hub-flight-alerts-ticket-neutral'),
                tone: FlightPriceTicketTone.neutral,
                label: FlightFormat.alertPrice(price, s.currency!),
                caption: l.activityFlightAlertsBestSeen,
              );
      case FlightAlertsSummaryKind.empty:
        state = 'empty';
        subtitle = Text(
          l.activityFlightAlertsEmpty,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subStyle,
        );
        trailing = Semantics(
          button: true,
          child: DonyPressable(
            key: const Key('hub-flight-alerts-create'),
            onTap: onCreate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
              child: Center(
                widthFactor: 1,
                child: FlightPriceTicket(
                  tone: FlightPriceTicketTone.create,
                  label: l.activityFlightAlertsCreate,
                ),
              ),
            ),
          ),
        );
      case null:
        state = 'error';
        subtitle = Text(
          l.activityFlightAlertsEmpty,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subStyle,
        );
        trailing = const _Chevron();
    }

    final radius = BorderRadius.circular(DonyRadius.card);
    return Container(
      key: Key('hub-flight-alerts-$state'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadow.xs,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('hub-flight-alerts-row'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  _BellIcon(hit: hit),
                  const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.activityFlightAlertsTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall,
                        ),
                        const SizedBox(height: DonySpacing.xxs),
                        subtitle,
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs + DonySpacing.xxs),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// « −61 € sous votre prix », ou « à votre prix » quand le prix trouvé
  /// est pile le seuil.
  static String _savingsCaption(AppLocalizations l, FlightAlertsSummary s) {
    final savings = s.savings ?? 0;
    if (savings < 1) return l.flightsAlertAtYourPrice;
    return l.activityFlightAlertsBelowByTicket(
      FlightFormat.alertPrice(savings, s.currency!),
    );
  }
}

/// Trajet et nombre de vols d'une alerte qui a trouvé, précédés des logos
/// des compagnies quand la place le permet. Le trajet complet passe avant
/// les logos : trois, puis un, puis aucun, avant de couper le trajet ; le
/// nombre de vols reste toujours lu.
class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.route,
    required this.flights,
    required this.codes,
    required this.style,
  });

  final String route;
  final String? flights;
  final List<String> codes;
  final TextStyle? style;

  static const _gap = DonySpacing.xs + DonySpacing.xxs;

  /// Logos affichés pour une largeur [available] : le plus grand nombre
  /// parmi 3, 1 et 0 qui laisse le trajet entier.
  static int logosFor({
    required double available,
    required double textWidth,
    required int codes,
  }) {
    for (final n in const [3, 1]) {
      if (n > codes) continue;
      final logos = AirlineLogoStack.widthFor(n) + _gap;
      if (logos + textWidth <= available) return n;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: '$route${flights ?? ''}', style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final n = logosFor(
          available: constraints.maxWidth,
          textWidth: painter.width,
          codes: codes.length,
        );
        // Nombre de vols démesuré face à la place (texte agrandi, écran
        // très étroit) : il se coupe aussi plutôt que de déborder.
        painter
          ..text = TextSpan(text: flights ?? '', style: style)
          ..layout();
        final flightsFit = painter.width <= constraints.maxWidth / 2;
        painter.dispose();
        final count = flights == null
            ? null
            : Text(
                flights!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              );
        return Row(
          children: [
            if (n > 0) ...[
              AirlineLogoStack(codes: codes.take(n).toList()),
              const SizedBox(width: _gap),
            ],
            // Le trajet se coupe le premier : le nombre de vols reste lu.
            Flexible(
              child: Text(
                route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (count != null)
              if (flightsFit) count else Flexible(child: count),
          ],
        );
      },
    );
  }
}

/// Cloche dans un carré arrondi de teinte douce unie : verte quand un prix
/// est trouvé, bleue sinon.
class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.hit});

  final bool hit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final soft = hit ? cs.successLight : cs.primaryContainer;
    final strong = hit ? cs.success : cs.primary;
    return Container(
      key: Key(hit ? 'hub-flight-alerts-icon-hit' : 'hub-flight-alerts-icon'),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DonyRadius.md),
        color: soft,
      ),
      child: DonyIcon('bell', size: 18, color: strong),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => DonyIcon(
    'chevron-right',
    size: 20,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// Chargement discret : la ligne garde sa hauteur, sans billet.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyShimmer(
      child: Container(
        key: const Key('hub-flight-alerts-loading'),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: const Row(
          children: [
            DonySkeletonBox(width: 36, height: 36, radius: DonyRadius.md),
            SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonySkeletonBox(width: 120),
                  SizedBox(height: DonySpacing.xs + DonySpacing.xxs),
                  DonySkeletonBox(width: 160, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
