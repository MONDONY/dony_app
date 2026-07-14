import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/presentation/widgets/dispute_card.dart';
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
      appBar: AppBar(title: const Text('Mes litiges')),
      body: BlocBuilder<DisputeListBloc, DisputeListState>(
        builder: (context, state) => switch (state) {
          DisputeListInitial() || DisputeListLoading() => Center(
            child: CircularProgressIndicator(color: cs.primary),
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
    );
  }
}
