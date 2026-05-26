import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscription_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

class MesAbonnementsScreen extends StatefulWidget {
  const MesAbonnementsScreen({super.key});
  @override
  State<MesAbonnementsScreen> createState() => _MesAbonnementsScreenState();
}

class _MesAbonnementsScreenState extends State<MesAbonnementsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsBloc>().add(const LoadSubscriptions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes abonnements')),
      body: BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
        builder: (context, state) {
          if (state.status == SubscriptionsStatus.loading &&
              state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SubscriptionsStatus.error &&
              state.items.isEmpty) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              icon: Icons.error_outline_rounded,
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<SubscriptionsBloc>()
                  .add(const LoadSubscriptions()),
            );
          }
          if (state.items.isEmpty) {
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun abonnement',
              description:
                  'Abonne-toi à un voyageur depuis son profil pour suivre ses trajets.',
            );
          }
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? state.items
              : state.items
                  .where((i) => i.travelerName.toLowerCase().contains(q))
                  .toList();
          final recent = filtered.where((i) => i.hasNew).toList();
          final others = filtered.where((i) => !i.hasNew).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.base,
                  DonySpacing.md,
                  DonySpacing.base,
                  DonySpacing.sm,
                ),
                child: DonySearchField(
                  hint: 'Rechercher un voyageur…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (recent.isNotEmpty) ...[
                      const _SectionLabel('🆕 Ont publié récemment'),
                      ...recent.map((i) => _slidable(context, i)),
                    ],
                    if (others.isNotEmpty) ...[
                      const _SectionLabel('Tous mes abonnements'),
                      ...others.map((i) => _slidable(context, i)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _slidable(BuildContext context, SubscriptionItem item) {
    return Slidable(
      key: ValueKey(item.travelerId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => context
                .read<SubscriptionsBloc>()
                .add(UnsubscribeTraveler(item.travelerId)),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Désabonner',
          ),
        ],
      ),
      child: SubscriptionTile(
        item: item,
        onTap: () => context.push('/travelers/${item.travelerId}'),
        onToggleBell: () => context
            .read<SubscriptionsBloc>()
            .add(ToggleSubscriptionPush(item.travelerId, !item.pushEnabled)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
