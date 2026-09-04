import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_actions_sheet.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_card.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran liste des alertes corridor.
///
/// [direction] filtre les alertes affichées et verrouille la direction à la
/// création :
/// - `travelerWantsPackages` → alertes « Colis » (atteint depuis le bloc
///   Voyageur).
/// - `senderWantsTrips` → alertes « Trajets » (atteint depuis le bloc/​hub
///   Expéditeur).
/// - `null` → toutes les alertes (hub Activités, modèle double rôle),
///   groupées par direction ; le formulaire montre alors son segment.
class CorridorAlertListScreen extends StatelessWidget {
  const CorridorAlertListScreen({super.key, this.direction});

  final AlertDirection? direction;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CorridorAlertListBloc>()..add(CorridorAlertListRequested()),
      child: _CorridorAlertListView(direction: direction),
    );
  }
}

class _CorridorAlertListView extends StatelessWidget {
  const _CorridorAlertListView({required this.direction});

  final AlertDirection? direction;

  bool get _isPackages => direction == AlertDirection.travelerWantsPackages;

  // Une direction verrouille la création (segment masqué, direction forcée) ;
  // sans direction, les deux rôles sont passés au form → segment visible.
  bool get _formIsTraveler => direction == null || _isPackages;
  bool get _formIsSender => direction == null || !_isPackages;

  void _reload(BuildContext ctx) =>
      ctx.read<CorridorAlertListBloc>().add(CorridorAlertListRequested());

  Future<void> _create(BuildContext ctx) async {
    await CorridorAlertFormSheet.show(
      ctx,
      isTraveler: _formIsTraveler,
      isSender: _formIsSender,
    );
    if (!ctx.mounted) return;
    _reload(ctx);
  }

  Future<void> _edit(BuildContext ctx, CorridorAlertModel alert) async {
    await CorridorAlertFormSheet.show(
      ctx,
      alert: alert,
      isTraveler: _formIsTraveler,
      isSender: _formIsSender,
    );
    if (!ctx.mounted) return;
    _reload(ctx);
  }

  Future<void> _openMatches(BuildContext ctx, CorridorAlertModel alert) async {
    await ctx.push('/corridor-alerts/${alert.id}/matches', extra: alert);
    // Ouvrir les correspondances les marque comme vues : la carte doit
    // repasser à « rien de neuf » au retour.
    if (!ctx.mounted) return;
    _reload(ctx);
  }

  void _toggle(BuildContext ctx, CorridorAlertModel alert, bool active) {
    ctx.read<CorridorAlertListBloc>().add(
      CorridorAlertActiveToggled(alert.id, active),
    );
  }

  Future<void> _menu(BuildContext ctx, CorridorAlertModel alert) async {
    final action = await CorridorAlertActionsSheet.show(ctx, alert: alert);
    if (action == null || !ctx.mounted) return;
    switch (action) {
      case CorridorAlertAction.edit:
        await _edit(ctx, alert);
      case CorridorAlertAction.pause:
        _toggle(ctx, alert, false);
      case CorridorAlertAction.resume:
        _toggle(ctx, alert, true);
      case CorridorAlertAction.delete:
        ctx.read<CorridorAlertListBloc>().add(CorridorAlertDeleted(alert.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final emptyDescription = switch (direction) {
      AlertDirection.travelerWantsPackages =>
        'Crée une alerte pour être prévenu dès qu\'un colis apparaît sur ton corridor.',
      AlertDirection.senderWantsTrips =>
        'Crée une alerte pour être prévenu dès qu\'un trajet apparaît sur ton corridor.',
      null =>
        'Crée une alerte pour être prévenu dès qu\'un trajet ou un colis apparaît sur ton corridor.',
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: switch (direction) {
          AlertDirection.travelerWantsPackages => 'Mes alertes colis',
          AlertDirection.senderWantsTrips => 'Mes alertes trajets',
          null => 'Mes alertes',
        },
      ),
      floatingActionButton: Builder(
        builder: (fabCtx) => FloatingActionButton.extended(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer'),
          onPressed: () => _create(fabCtx),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.lg,
              0,
            ),
            child: ContextualTutorialCard(
              context: TutorialContext.corridorAlerts,
            ),
          ),
          Expanded(
            child: BlocBuilder<CorridorAlertListBloc, CorridorAlertListState>(
              builder: (ctx, state) {
                // Filtre mono-direction ; sans direction, tout est visible.
                final visible = direction == null
                    ? state.alerts
                    : state.alerts
                          .where((a) => a.direction == direction)
                          .toList();

                if (state.status == CorridorAlertListStatus.loading &&
                    visible.isEmpty) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      DonySpacing.md,
                      DonySpacing.lg,
                      DonySpacing.huge,
                    ),
                    itemCount: 4,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DonySpacing.md),
                    itemBuilder: (_, _) => const DonyListCardSkeleton(),
                  );
                }
                if (state.status == CorridorAlertListStatus.error &&
                    visible.isEmpty) {
                  return DonyEmptyState(
                    mascotte: DonyMascotteType.erreurLegere,
                    type: DonyEmptyStateType.error,
                    iconAsset: 'circle-alert',
                    title: 'Erreur de chargement',
                    description:
                        state.errorMessage ?? 'Une erreur est survenue.',
                    actionLabel: 'Réessayer',
                    onAction: () => _reload(ctx),
                  );
                }
                if (visible.isEmpty) {
                  return DonyEmptyState(
                    mascotte: DonyMascotteType.assis,
                    title: 'Aucune alerte corridor',
                    description: emptyDescription,
                    actionLabel: 'Créer une alerte',
                    onAction: () => _create(ctx),
                  );
                }

                final trips = visible
                    .where(
                      (a) => a.direction == AlertDirection.senderWantsTrips,
                    )
                    .toList();
                final packages = visible
                    .where(
                      (a) =>
                          a.direction == AlertDirection.travelerWantsPackages,
                    )
                    .toList();
                // Les en-têtes de groupe n'ont de sens que lorsque les deux
                // directions cohabitent (hub) : un écran mono-direction dit
                // déjà tout dans son titre.
                final grouped = direction == null;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.md,
                    DonySpacing.lg,
                    DonySpacing.huge * 2,
                  ),
                  children: [
                    if (trips.isNotEmpty) ...[
                      if (grouped) const _GroupHeader('Trajets surveillés'),
                      for (final a in trips) _row(ctx, a),
                    ],
                    if (packages.isNotEmpty) ...[
                      if (grouped) ...[
                        if (trips.isNotEmpty)
                          const SizedBox(height: DonySpacing.sm),
                        const _GroupHeader('Colis surveillés'),
                      ],
                      for (final a in packages) _row(ctx, a),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, CorridorAlertModel alert) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.md),
      child: Dismissible(
        key: ValueKey(alert.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => ctx.read<CorridorAlertListBloc>().add(
          CorridorAlertDeleted(alert.id),
        ),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: DonySpacing.xl),
          decoration: BoxDecoration(
            color: cs.error,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: DonyIcon('trash-2', color: cs.onError),
        ),
        child: CorridorAlertCard(
          alert: alert,
          onTap: () => _openMatches(ctx, alert),
          onMenu: () => _menu(ctx, alert),
          onResume: () => _toggle(ctx, alert, true),
          onExtend: () => _edit(ctx, alert),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs,
        0,
        DonySpacing.xs,
        DonySpacing.md,
      ),
      child: Text(
        label.toUpperCase(),
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
