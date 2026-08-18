import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Mes abonnements'),
      ),
      body: BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
        builder: (context, state) {
          if (state.status == SubscriptionsStatus.loading &&
              state.items.isEmpty) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.md,
                DonySpacing.base,
                DonySpacing.huge,
              ),
              itemCount: 5,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DonySpacing.sm),
              itemBuilder: (_, _) => const DonyUserCardSkeleton(),
            );
          }
          if (state.status == SubscriptionsStatus.error &&
              state.items.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.erreurLegere,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () => context.read<SubscriptionsBloc>().add(
                const LoadSubscriptions(),
              ),
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
                      _SubscriptionStoryRow(items: recent),
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
          CustomSlidableAction(
            onPressed: (_) => context.read<SubscriptionsBloc>().add(
              UnsubscribeTraveler(item.travelerId),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DonyIcon('trash-2', color: Colors.white),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Désabonner',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      child: SubscriptionTile(
        item: item,
        onTap: () => context.push('/travelers/${item.travelerId}'),
        onToggleBell: () => context.read<SubscriptionsBloc>().add(
          ToggleSubscriptionPush(item.travelerId, !item.pushEnabled),
        ),
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

class _SubscriptionStoryRow extends StatelessWidget {
  const _SubscriptionStoryRow({required this.items});

  final List<SubscriptionItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: DonySpacing.md),
        itemBuilder: (context, index) => _StoryAvatar(item: items[index]),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      label: 'Nouveau trajet publié par ${item.travelerName}',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/travelers/${item.travelerId}'),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [cs.primary, DonyColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: DonyAvatar(
                  name: item.travelerName,
                  imageUrl: item.avatarUrl,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                item.travelerName,
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
