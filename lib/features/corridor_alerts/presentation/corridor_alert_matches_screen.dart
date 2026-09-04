import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_card.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_match_card.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Correspondances d'une alerte. Reçoit l'alerte entière depuis la liste, ou
/// seulement son id depuis un push : le cubit la charge alors lui-même.
///
/// Les correspondances apparues depuis la dernière consultation viennent en
/// tête sous « Nouveaux », le reste sous « Déjà vus », atténué.
class CorridorAlertMatchesScreen extends StatelessWidget {
  const CorridorAlertMatchesScreen({super.key, this.alert, String? alertId})
    : assert(alert != null || alertId != null, 'alert ou alertId requis'),
      _alertId = alertId;

  final CorridorAlertModel? alert;
  final String? _alertId;

  String get alertId => alert?.id ?? _alertId!;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CorridorAlertMatchesCubit>(param1: alertId, param2: alert)
            ..load(),
      child: _CorridorAlertMatchesView(initialAlert: alert),
    );
  }
}

class _CorridorAlertMatchesView extends StatelessWidget {
  const _CorridorAlertMatchesView({this.initialAlert});

  /// Alerte connue avant tout chargement (depuis la liste) ; l'état du cubit
  /// prend le relais dès qu'il en porte une, notamment après « vu ».
  final CorridorAlertModel? initialAlert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<CorridorAlertMatchesCubit>().state;
    final alert = state.alert ?? initialAlert;
    final isTrip =
        (alert?.direction ?? state.result?.direction) ==
        AlertDirection.senderWantsTrips;

    // Resolve role flags for the edit sheet.
    // watch ensures build() re-runs on auth state change so the edit callback captures fresh flags.
    final authState = context.watch<AuthBloc>().state;
    final isTraveler = switch (authState) {
      final AuthAuthenticated s => s.user.isTraveler,
      final AuthProfileUpdated s => s.user.isTraveler,
      _ => false,
    };
    final isSender = switch (authState) {
      final AuthAuthenticated s => s.user.isSender,
      final AuthProfileUpdated s => s.user.isSender,
      _ => false,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          alert?.corridorLabel ?? 'Mes alertes',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (alert != null)
            IconButton(
              tooltip: 'Modifier l\'alerte',
              icon: DonyIcon('square-pen', size: 22, color: cs.primary),
              onPressed: () => CorridorAlertFormSheet.show(
                context,
                alert: alert,
                isTraveler: isTraveler,
                isSender: isSender,
              ),
            ),
        ],
      ),
      body: BlocBuilder<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
        builder: (ctx, state) {
          switch (state.status) {
            case CorridorAlertMatchesStatus.initial:
            case CorridorAlertMatchesStatus.loading:
              return Center(
                child: CircularProgressIndicator(color: cs.primary),
              );
            case CorridorAlertMatchesStatus.error:
              return DonyEmptyState(
                mascotte: DonyMascotteType.erreurLegere,
                type: DonyEmptyStateType.error,
                iconAsset: 'circle-alert',
                title: 'Erreur de chargement',
                description: state.errorMessage ?? 'Une erreur est survenue.',
                actionLabel: 'Réessayer',
                onAction: () => ctx.read<CorridorAlertMatchesCubit>().load(),
              );
            case CorridorAlertMatchesStatus.empty:
              return Column(
                children: [
                  if (alert != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg,
                        DonySpacing.md,
                        DonySpacing.lg,
                        0,
                      ),
                      child: _AlertSummaryBanner(alert: alert),
                    ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.huge,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const DonyMascotteAnimated(
                              type: DonyMascotteType.aucunResultat,
                              size: DonyMascotteSize.lg,
                            ),
                            const SizedBox(height: DonySpacing.base),
                            Text(
                              isTrip
                                  ? 'Aucun trajet pour l\'instant'
                                  : 'Aucun colis pour l\'instant',
                              textAlign: TextAlign.center,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Text(
                              isTrip
                                  ? 'Aucun trajet ne correspond à cette alerte pour l\'instant.'
                                  : 'Aucun colis ne correspond à cette alerte pour l\'instant.',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            case CorridorAlertMatchesStatus.loaded:
              return isTrip
                  ? _MatchList<TripMatchModel>(
                      alert: alert,
                      items: state.result!.trips,
                      noun: 'trajet',
                      isNew: (t) => state.isNew(t.publishedAt),
                      keyOf: (t) => t.announcementId,
                      itemBuilder: (lCtx, t, i) => TripMatchCard(
                        match: t,
                        index: i,
                        onTap: () => lCtx.push('/traveler/${t.announcementId}'),
                      ),
                    )
                  : _MatchList<MatchingRequestModel>(
                      alert: alert,
                      items: state.result!.packages,
                      noun: 'colis',
                      isNew: (m) => state.isNew(m.requestedAt),
                      keyOf: (m) => m.id,
                      itemBuilder: (lCtx, m, i) =>
                          MatchingRequestCard(
                                match: m,
                                index: i,
                                onTap: () => lCtx.push(
                                  '/package-requests/${m.id}/public',
                                ),
                              )
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 60 * i),
                                duration: 280.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .slideY(
                                begin: 0.04,
                                delay: Duration(milliseconds: 60 * i),
                                duration: 280.ms,
                                curve: Curves.easeOutCubic,
                              ),
                    );
          }
        },
      ),
    );
  }
}

/// Bandeau résumé de l'alerte en tête de l'écran : état et filtres, pour
/// savoir ce que l'on regarde sans revenir à la liste.
class _AlertSummaryBanner extends StatelessWidget {
  const _AlertSummaryBanner({required this.alert});

  final CorridorAlertModel alert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTrips = alert.direction == AlertDirection.senderWantsTrips;
    final (iconAsset, iconBg, iconFg) = isTrips
        ? ('plane', cs.primaryContainer, cs.primary)
        : ('package', cs.secondaryContainer, cs.secondary);
    final (title, subtitle) = !alert.active
        ? ('Alerte en pause', 'Aucune notification')
        : alert.isExpired
        ? ('Alerte expirée', 'La fenêtre de dates est passée')
        : ('Alerte active', 'Push instantané, digest à 9 h');

    return DonyCard(
      key: const Key('alert-summary-banner'),
      padding: const EdgeInsets.all(DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                iconAsset: iconAsset,
                size: DonyIconContainerSize.sm,
                backgroundColor: iconBg,
                iconColor: iconFg,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleSmall),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          CorridorAlertFilterChips(alert: alert),
        ],
      ),
    );
  }
}

/// Liste des correspondances, scindée « Nouveaux » / « Déjà vus » dès qu'il
/// y a du nouveau. Sans nouveauté (ou sans seuil connu), un seul compteur.
class _MatchList<T> extends StatelessWidget {
  const _MatchList({
    required this.alert,
    required this.items,
    required this.noun,
    required this.isNew,
    required this.keyOf,
    required this.itemBuilder,
  });

  final CorridorAlertModel? alert;
  final List<T> items;
  final String noun;
  final bool Function(T) isNew;
  final String Function(T) keyOf;
  final Widget Function(BuildContext, T, int) itemBuilder;

  String _count(int n) => '$n $noun${noun == 'colis' || n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fresh = items.where(isNew).toList();
    final seen = items.where((i) => !isNew(i)).toList();
    final split = fresh.isNotEmpty && seen.isNotEmpty;

    Widget header(String label, {bool highlight = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        DonySpacing.base,
        0,
        DonySpacing.sm,
      ),
      child: Row(
        children: [
          if (highlight) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: DonyColors.amberDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: highlight ? DonyColors.amberDark : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final children = <Widget>[
      if (alert != null) _AlertSummaryBanner(alert: alert!),
    ];
    var index = 0;
    Widget row(T item, {required bool faded}) {
      final w = Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.md),
        child: KeyedSubtree(
          key: ValueKey(keyOf(item)),
          child: itemBuilder(context, item, index++),
        ),
      );
      return faded ? Opacity(opacity: 0.7, child: w) : w;
    }

    if (split) {
      children.add(
        header('Nouveaux · ${_count(fresh.length)}', highlight: true),
      );
      for (final f in fresh) {
        children.add(row(f, faded: false));
      }
      children.add(header('Déjà vus · ${_count(seen.length)}'));
      for (final s in seen) {
        children.add(row(s, faded: true));
      }
    } else {
      final onlyNew = fresh.isNotEmpty;
      children.add(
        header(
          onlyNew ? 'Nouveaux · ${_count(items.length)}' : _count(items.length),
          highlight: onlyNew,
        ),
      );
      for (final i in items) {
        children.add(row(i, faded: false));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: children,
    );
  }
}
