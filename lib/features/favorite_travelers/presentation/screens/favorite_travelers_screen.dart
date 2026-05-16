import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/favorite_travelers/bloc/favorite_traveler_bloc.dart';
import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FavoriteTravelersScreen extends StatefulWidget {
  const FavoriteTravelersScreen({super.key});

  @override
  State<FavoriteTravelersScreen> createState() => _FavoriteTravelersScreenState();
}

class _FavoriteTravelersScreenState extends State<FavoriteTravelersScreen> {
  @override
  void initState() {
    super.initState();
    getIt<FavoriteTravelerBloc>().add(const FavoriteTravelerLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return DonyPageScaffold(
      title: 'Voyageurs favoris',
      scrollable: false,
      body: BlocBuilder<FavoriteTravelerBloc, FavoriteTravelerState>(
        builder: (context, state) {
          if (state.status == FavoriteTravelerStatus.loading &&
              state.travelers.isEmpty) {
            return const DonyEmptyState(
              type: DonyEmptyStateType.loading,
              title: '',
            );
          }
          if (state.status == FavoriteTravelerStatus.error &&
              state.travelers.isEmpty) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              icon: Icons.error_outline_rounded,
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<FavoriteTravelerBloc>()
                  .add(const FavoriteTravelerLoaded()),
            );
          }
          if (state.travelers.isEmpty) {
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun voyageur favori',
              description:
                  'Les voyageurs avec qui tu as envoyé apparaîtront ici. Re-contacte-les facilement !',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.paddingOf(context).bottom + 100,
            ),
            itemCount: state.travelers.length,
            separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, i) {
              final traveler = state.travelers[i];
              return _FavoriteTravelerCard(traveler: traveler)
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                  .slideY(begin: 0.03, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}

class _FavoriteTravelerCard extends StatelessWidget {
  const _FavoriteTravelerCard({required this.traveler});

  final FavoriteTraveler traveler;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: InkWell(
        onTap: () => context.push('/travelers/${traveler.travelerId}'),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            children: [
              DonyAvatar(
                name: traveler.travelerName,
                size: DonyAvatarSize.md,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      traveler.travelerName,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (traveler.travelerAverageRating != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: cs.tertiary),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            traveler.travelerAverageRating!.toStringAsFixed(1),
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                    if (traveler.notes != null) ...[
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        traveler.notes!,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _KebabMenu(traveler: traveler),
            ],
          ),
        ),
      ),
    );
  }
}

class _KebabMenu extends StatelessWidget {
  const _KebabMenu({required this.traveler});

  final FavoriteTraveler traveler;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<_FavoriteAction>(
      icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      onSelected: (action) async {
        switch (action) {
          case _FavoriteAction.remove:
            final confirmed = await DonyDialog.show(
              context,
              title: 'Retirer des favoris',
              message:
                  'Es-tu sûr de vouloir retirer "${traveler.travelerName}" de tes favoris ?',
              icon: Icons.favorite_border_rounded,
              confirmLabel: 'Retirer',
              variant: DonyDialogVariant.destructive,
              cancelLabel: 'Annuler',
            );
            if ((confirmed ?? false) && context.mounted) {
              context
                  .read<FavoriteTravelerBloc>()
                  .add(FavoriteTravelerRemoved(traveler.travelerId));
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _FavoriteAction.remove,
          child: Row(
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Retirer des favoris',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _FavoriteAction { remove }
