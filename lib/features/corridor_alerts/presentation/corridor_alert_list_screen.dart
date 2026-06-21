import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran liste des alertes corridor, mono-direction.
///
/// [direction] filtre les alertes affichées et verrouille la direction à la
/// création :
/// - `travelerWantsPackages` → alertes « Colis » (atteint depuis le bloc
///   Voyageur).
/// - `senderWantsTrips` → alertes « Trajets » (atteint depuis le bloc/​hub
///   Expéditeur).
class CorridorAlertListScreen extends StatelessWidget {
  const CorridorAlertListScreen({
    super.key,
    this.direction = AlertDirection.travelerWantsPackages,
  });

  final AlertDirection direction;

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

  final AlertDirection direction;

  bool get _isPackages => direction == AlertDirection.travelerWantsPackages;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // La direction de l'écran verrouille la direction à la création : exactement
    // un rôle est passé au form → segment masqué, direction forcée.
    final formIsTraveler = _isPackages;
    final formIsSender = !_isPackages;

    final emptyDescription = _isPackages
        ? 'Crée une alerte pour être prévenu dès qu\'un colis apparaît sur ton corridor.'
        : 'Crée une alerte pour être prévenu dès qu\'un trajet apparaît sur ton corridor.';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Mes alertes corridor',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: Builder(
        builder: (fabCtx) => FloatingActionButton.extended(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer'),
          onPressed: () async {
            await CorridorAlertFormSheet.show(
              fabCtx,
              isTraveler: formIsTraveler,
              isSender: formIsSender,
            );
            if (fabCtx.mounted) {
              fabCtx
                  .read<CorridorAlertListBloc>()
                  .add(CorridorAlertListRequested());
            }
          },
        ),
      ),
      body: BlocBuilder<CorridorAlertListBloc, CorridorAlertListState>(
        builder: (ctx, state) {
          // Filtre mono-direction : seules les alertes de cet écran sont visibles.
          final visible =
              state.alerts.where((a) => a.direction == direction).toList();

          if (state.status == CorridorAlertListStatus.loading &&
              visible.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: cs.primary));
          }
          if (state.status == CorridorAlertListStatus.error &&
              visible.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.errorMessage ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () => ctx
                  .read<CorridorAlertListBloc>()
                  .add(CorridorAlertListRequested()),
            );
          }
          if (visible.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune alerte corridor',
              description: emptyDescription,
              actionLabel: 'Créer une alerte',
              onAction: () async {
                await CorridorAlertFormSheet.show(
                  ctx,
                  isTraveler: formIsTraveler,
                  isSender: formIsSender,
                );
                if (ctx.mounted) {
                  ctx
                      .read<CorridorAlertListBloc>()
                      .add(CorridorAlertListRequested());
                }
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(
              top: DonySpacing.sm,
              bottom: DonySpacing.huge,
            ),
            itemCount: visible.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              indent: DonySpacing.lg + 44 + DonySpacing.md,
              color: cs.outline.withValues(alpha: 0.5),
            ),
            itemBuilder: (lCtx, i) {
              final alert = visible[i];
              return Dismissible(
                key: ValueKey(alert.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => lCtx
                    .read<CorridorAlertListBloc>()
                    .add(CorridorAlertDeleted(alert.id)),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: DonySpacing.xl),
                  color: cs.error,
                  // size: 24 is the DonyIcon default — matches the brief.
                  child: DonyIcon('trash-2', color: cs.onError),
                ),
                child: CorridorAlertTile(
                  alert: alert,
                  onToggle: (next) => lCtx
                      .read<CorridorAlertListBloc>()
                      .add(CorridorAlertActiveToggled(alert.id, next)),
                  onTap: () async {
                    await lCtx.push(
                      '/corridor-alerts/${alert.id}/matches',
                      extra: alert,
                    );
                    if (lCtx.mounted) {
                      lCtx
                          .read<CorridorAlertListBloc>()
                          .add(CorridorAlertListRequested());
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
