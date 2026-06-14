import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ShipmentsHistoryScreen extends StatelessWidget {
  const ShipmentsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DonyPageScaffold(
      title: 'Historique des livraisons',
      body: BlocBuilder<BidBloc, BidState>(
        builder: (context, state) {
          if (state is BidLoading) {
            return const _ShimmerList();
          }
          if (state is BidError) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              mascotte: DonyMascotteType.assis,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.error.message,
              actionLabel: 'Réessayer',
              onAction: () => context.read<BidBloc>().add(BidMyListRequested()),
            );
          }
          if (state is BidListLoaded) {
            // Statut terminal back-end d'une livraison réussie = COMPLETED
            // (le back n'émet jamais DELIVERED).
            final delivered = state.bids
                .where((b) => b.status == 'COMPLETED')
                .toList()
              ..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));

            if (delivered.isEmpty) {
              return const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Aucune livraison terminée',
                description: 'Tes livraisons terminées s\'afficheront ici.',
              );
            }
            return _DeliveredList(bids: delivered);
          }
          return const DonyEmptyState(
            type: DonyEmptyStateType.loading,
            title: '',
          );
        },
      ),
    );
  }
}

class _DeliveredList extends StatelessWidget {
  const _DeliveredList({required this.bids});

  final List<BidModel> bids;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bids.length,
      separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm),
      itemBuilder: (context, i) => _DeliveryCard(bid: bids[i])
          .animate()
          .fadeIn(delay: (i * 60).ms, duration: 280.ms)
          .slideY(begin: 0.03, curve: Curves.easeOutCubic),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.bid});

  final BidModel bid;

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final travelerName = bid.travelerName ?? 'Voyageur';
    final route = [
      bid.departureCity,
      bid.arrivalCity,
    ].where((c) => c != null).join(' → ');
    final weight = (bid.weightKg ?? 0) > 0 ? '${bid.weightKg} kg' : null;
    final description = bid.description;
    final price = bid.pricePerKg != null
        ? '${(bid.pricePerKg! * (bid.weightKg ?? 0)).toStringAsFixed(0)} €'
        : null;

    return GestureDetector(
      onTap: () => context.push('/bids/${bid.id}', extra: bid),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DonyAvatar(name: travelerName, imageUrl: bid.travelerAvatarUrl, size: DonyAvatarSize.sm),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        travelerName,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bid.travelerAverageRating != null)
                        Row(
                          children: [
                            DonyIcon(
                              'star',
                              size: 14,
                              color: cs.tertiary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              bid.travelerAverageRating!.toStringAsFixed(1),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  _relativeDate(bid.updatedAt),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (route.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              Row(
                children: [
                  DonyIcon('route', size: 16, color: cs.primary),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    route,
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                ],
              ),
            ],
            if (description != null || weight != null) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                [description, weight].where((s) => s != null).join(' · '),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (price != null) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                price,
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: DonySpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DonyButton(
                  label: 'Voir détails',
                  variant: DonyButtonVariant.ghost,
                  fullWidth: false,
                  onPressed: () => context.push('/bids/${bid.id}', extra: bid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
          ).animate().fadeIn(delay: (i * 60).ms, duration: 300.ms),
        ),
      ),
    );
  }
}
