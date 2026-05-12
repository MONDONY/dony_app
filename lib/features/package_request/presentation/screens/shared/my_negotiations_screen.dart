import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MyNegotiationsScreen extends StatelessWidget {
  const MyNegotiationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => context.pop(),
        ),
        title: Text('Mes négociations',
            style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
      ),
      body: BlocProvider<NegotiationListBloc>(
        create: (_) => getIt<NegotiationListBloc>()
          ..add(const NegotiationListFetchRequested()),
        child: const MyNegotiationsBody(),
      ),
    );
  }
}

class MyNegotiationsBody extends StatelessWidget {
  const MyNegotiationsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NegotiationListBloc, NegotiationListState>(
      builder: (context, state) {
        if (state.status == NegotiationListStatus.loading &&
            state.threads.isEmpty) {
          return Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary));
        }
        if (state.status == NegotiationListStatus.error) {
          return _ErrorState(
            message: state.errorMessage ?? 'Erreur',
            onRetry: () => context
                .read<NegotiationListBloc>()
                .add(const NegotiationListRefreshRequested()),
          );
        }
        if (state.threads.isEmpty) return const _EmptyState();

        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            context
                .read<NegotiationListBloc>()
                .add(const NegotiationListRefreshRequested());
          },
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.of(context).padding.bottom + 100,
            ),
            itemCount: state.threads.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: DonySpacing.sm + 4),
            itemBuilder: (_, i) => _NegoCard(
              thread: state.threads[i],
              index: i,
            ),
          ),
        );
      },
    );
  }
}

// ── Nego Card ─────────────────────────────────────────────────────────────────

class _NegoCard extends StatelessWidget {
  const _NegoCard({required this.thread, required this.index});
  final NegotiationThread thread;
  final int index;

  bool get _isNew =>
      thread.status == NegotiationThreadStatus.open &&
      thread.messages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final travelerDisplayName =
        thread.travelerName ?? 'Voyageur ${thread.travelerId.substring(0, 4)}';

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => context.push('/negotiations/${thread.id}'),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: _isNew ? cs.primary.withValues(alpha: 0.3) : cs.outline,
              width: _isNew ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 : avatar + nom + prix
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyAvatar(
                        name: travelerDisplayName,
                        imageUrl: thread.travelerPhotoUrl,
                        size: DonyAvatarSize.md,
                        verified: (thread.travelerTripsCount ?? 0) > 0,
                      ),
                      const SizedBox(width: DonySpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              travelerDisplayName,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _timeAgo(thread.lastActivityAt),
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                                Text(
                                  ' · Round ${thread.roundsCount}/5',
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      // Prix + label
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${thread.currentPriceEur.toStringAsFixed(0)} €',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              fontSize: 20,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _priceLabel(thread.status),
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Row 2 : route + date
                  if (_routeLine != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      _routeLine!,
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ],
              ),
              // Badge NOUVEAU top-right
              if (_isNew)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius:
                          BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      'NOUVEAU',
                      style: tt.bodyMedium!.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (50 * index).ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  String _priceLabel(NegotiationThreadStatus s) => switch (s) {
        NegotiationThreadStatus.open => 'proposition',
        NegotiationThreadStatus.awaitingTrip => 'accord',
        NegotiationThreadStatus.awaitingPayment => 'à payer',
        NegotiationThreadStatus.accepted => 'payé',
        _ => 'terminé',
      };

  String? get _routeLine {
    final dep = thread.departureCity;
    final arr = thread.arrivalCity;
    final date =
        DateFormat('d MMM', 'fr').format(thread.travelerTravelDate);
    final kg = thread.weightKg;

    if (dep != null && arr != null) {
      return [
        '$dep → $arr',
        if (kg != null) '${kg.toStringAsFixed(0)} kg',
        date,
      ].join(' · ');
    }
    return ['${thread.travelerAvailableKg.toStringAsFixed(0)} kg dispo', date]
        .join(' · ');
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl + 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DonyColors.primarySoft,
                borderRadius: BorderRadius.circular(DonyRadius.xl),
              ),
              child: const Center(
                  child: Text('🤝', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: DonySpacing.xl),
            Text(
              'Aucune négociation',
              style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Tes négociations actives apparaîtront ici dès qu\'un voyageur fait une offre.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl + 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: DonyColors.danger500),
            const SizedBox(height: DonySpacing.sm + 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
  return 'il y a ${diff.inDays}j';
}
