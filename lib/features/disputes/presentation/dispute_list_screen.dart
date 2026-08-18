import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_card.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DisputeListScreen extends StatelessWidget {
  const DisputeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Mes litiges'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ContextualTutorialCard(context: TutorialContext.dispute),
          ),
          Expanded(
            child: BlocBuilder<DisputeListBloc, DisputeListState>(
              builder: (context, state) => switch (state) {
                DisputeListInitial() ||
                DisputeListLoading() => ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const DonyListCardSkeleton(),
                ),
                DisputeListError(:final error) => DonyEmptyState(
                  type: DonyEmptyStateType.error,
                  title: 'Impossible de charger vos litiges',
                  description: error.message,
                  actionLabel: 'Réessayer',
                  onAction: () => context.read<DisputeListBloc>().add(
                    const DisputesLoadRequested(),
                  ),
                ),
                DisputeListLoaded(:final disputes) when disputes.isEmpty =>
                  DonyEmptyState(
                    iconAsset: 'scale',
                    title: 'Aucun litige',
                    description:
                        'Tant mieux ! Un litige s\'ouvre automatiquement si vous contestez l\'absence d\'un voyageur lors d\'une remise.',
                    actionLabel: 'Un problème avec un envoi ?',
                    onAction: () => context.push('/profile/help/contact'),
                  ),
                DisputeListLoaded(:final disputes) => RefreshIndicator(
                  color: cs.primary,
                  onRefresh: () async => context.read<DisputeListBloc>().add(
                    const DisputesLoadRequested(),
                  ),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: disputes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        DisputeCard(
                              dispute: disputes[i],
                              onTap: () => context.push(
                                '/disputes/detail',
                                extra: disputes[i],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (60 * i).ms)
                            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
