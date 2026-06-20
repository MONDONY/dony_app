import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CorridorAlertListScreen extends StatelessWidget {
  const CorridorAlertListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CorridorAlertListBloc>()..add(CorridorAlertListRequested()),
      child: const _CorridorAlertListView(),
    );
  }
}

class _CorridorAlertListView extends StatelessWidget {
  const _CorridorAlertListView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
            await CorridorAlertFormSheet.show(fabCtx);
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
          if (state.status == CorridorAlertListStatus.loading &&
              state.alerts.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: cs.primary));
          }
          if (state.status == CorridorAlertListStatus.error &&
              state.alerts.isEmpty) {
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
          if (state.alerts.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune alerte corridor',
              description:
                  'Crée une alerte pour être prévenu dès qu\'un colis apparaît sur ton corridor.',
              actionLabel: 'Créer une alerte',
              onAction: () async {
                await CorridorAlertFormSheet.show(ctx);
                if (ctx.mounted) {
                  ctx
                      .read<CorridorAlertListBloc>()
                      .add(CorridorAlertListRequested());
                }
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            itemCount: state.alerts.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: DonySpacing.md),
            itemBuilder: (lCtx, i) {
              final alert = state.alerts[i];
              return Dismissible(
                key: ValueKey(alert.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => lCtx
                    .read<CorridorAlertListBloc>()
                    .add(CorridorAlertDeleted(alert.id)),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: DonySpacing.xl),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                  ),
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
