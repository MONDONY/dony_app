import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MyNegotiationsScreen extends StatefulWidget {
  const MyNegotiationsScreen({super.key});

  @override
  State<MyNegotiationsScreen> createState() => _MyNegotiationsScreenState();
}

class _MyNegotiationsScreenState extends State<MyNegotiationsScreen> {
  @override
  void initState() {
    super.initState();
    getIt<NegotiationListBloc>().add(const NegotiationListFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Aligné sur la tuile « Discussions de prix » du hub Activités : le
      // libellé tapé doit être celui de l'écran qui s'ouvre.
      appBar: const DonyAppBar(title: 'Discussions de prix'),
      body: BlocProvider<NegotiationListBloc>.value(
        value: getIt<NegotiationListBloc>(),
        child: const MyNegotiationsBody(),
      ),
    );
  }
}

// ── Body avec filtre ──────────────────────────────────────────────────────────

class MyNegotiationsBody extends StatefulWidget {
  const MyNegotiationsBody({super.key});
  @override
  State<MyNegotiationsBody> createState() => _MyNegotiationsBodyState();
}

class _MyNegotiationsBodyState extends State<MyNegotiationsBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late final NegotiationFilterCubit _filterCubit;

  @override
  void initState() {
    super.initState();
    _filterCubit = getIt<NegotiationFilterCubit>();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _filterCubit.setQuery(q),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _filterCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _filterCubit,
      child: BlocBuilder<NegotiationFilterCubit, NegotiationFilterState>(
        builder: (context, filter) =>
            BlocBuilder<NegotiationListBloc, NegotiationListState>(
              builder: (context, state) {
                if (state.status == NegotiationListStatus.loading &&
                    state.threads.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: DonyColors.primary),
                  );
                }
                if (state.status == NegotiationListStatus.error) {
                  return _ErrorState(
                    message: state.errorMessage ?? 'Erreur',
                    onRetry: () => context.read<NegotiationListBloc>().add(
                      const NegotiationListRefreshRequested(),
                    ),
                  );
                }
                if (state.threads.isEmpty) {
                  return const DonyEmptyState(
                    title: 'Aucune négociation',
                    description:
                        "Tes négociations actives apparaîtront ici dès qu'un voyageur fait une offre.",
                    mascotte: DonyMascotteType.assis,
                  );
                }

                final all = state.threads;
                final activeCount = all
                    .where(
                      (t) =>
                          t.status == NegotiationThreadStatus.open ||
                          t.status == NegotiationThreadStatus.awaitingTrip ||
                          t.status == NegotiationThreadStatus.awaitingPayment,
                    )
                    .length;
                final terminalCount = all.length - activeCount;
                final filtered = applyNegotiationFilters(all, filter);

                return Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.base,
                        DonySpacing.sm,
                        DonySpacing.base,
                        0,
                      ),
                      child: DonySearchField(
                        hint: 'Voyageur, ville…',
                        controller: _searchController,
                        onChanged: _onQuery,
                        onClear: () => _filterCubit.setQuery(''),
                      ),
                    ),
                    // Filter chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.base,
                        DonySpacing.md,
                        DonySpacing.base,
                        DonySpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FilterChip(
                              label: 'Toutes (${all.length})',
                              active: filter.preset == NegoQuickFilter.all,
                              onTap: () =>
                                  _filterCubit.setPreset(NegoQuickFilter.all),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs + 2),
                          Expanded(
                            child: _FilterChip(
                              label: 'En cours ($activeCount)',
                              active: filter.preset == NegoQuickFilter.active,
                              onTap: () => _filterCubit.setPreset(
                                NegoQuickFilter.active,
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs + 2),
                          Expanded(
                            child: _FilterChip(
                              label: 'Terminées ($terminalCount)',
                              active: filter.preset == NegoQuickFilter.terminal,
                              onTap: () => _filterCubit.setPreset(
                                NegoQuickFilter.terminal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? _FilterEmptyState(
                              preset: filter.preset,
                              hasQuery: filter.query.isNotEmpty,
                            )
                          : RefreshIndicator(
                              color: DonyColors.primary,
                              onRefresh: () async => context
                                  .read<NegotiationListBloc>()
                                  .add(const NegotiationListRefreshRequested()),
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  DonySpacing.base,
                                  DonySpacing.sm,
                                  DonySpacing.base,
                                  MediaQuery.of(context).padding.bottom + 100,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, i) =>
                                    const SizedBox(height: DonySpacing.sm),
                                itemBuilder: (_, i) =>
                                    _NegoCard(thread: filtered[i], index: i),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? DonyColors.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: active ? DonyColors.primary : cs.outline,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter empty ──────────────────────────────────────────────────────────────

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.preset, required this.hasQuery});
  final NegoQuickFilter preset;
  final bool hasQuery;

  String get _msg {
    if (hasQuery) {
      return 'Aucun résultat pour cette recherche';
    }
    return switch (preset) {
      NegoQuickFilter.active => 'Aucune négociation en cours',
      NegoQuickFilter.terminal => 'Aucune négociation terminée',
      NegoQuickFilter.all => 'Aucune négociation',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyEmoji.parcel(size: 48),
            const SizedBox(height: DonySpacing.sm + 4),
            Text(
              _msg,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nego Card — Proposition A (Route First) ───────────────────────────────────

class _NegoCard extends StatelessWidget {
  const _NegoCard({required this.thread, required this.index});
  final NegotiationThread thread;
  final int index;

  bool get _isNew =>
      thread.status == NegotiationThreadStatus.open &&
      thread.messages.isNotEmpty;

  bool get _isTerminal =>
      thread.status == NegotiationThreadStatus.rejected ||
      thread.status == NegotiationThreadStatus.autoRejected ||
      thread.status == NegotiationThreadStatus.expired ||
      thread.status == NegotiationThreadStatus.cancelled;

  Color get _stripColor => switch (thread.status) {
    NegotiationThreadStatus.open => DonyColors.primary,
    NegotiationThreadStatus.awaitingTrip => DonyColors.threadStatusAmber,
    NegotiationThreadStatus.awaitingPayment => DonyColors.threadStatusViolet,
    NegotiationThreadStatus.accepted => DonyColors.threadStatusGreen,
    _ => DonyColors.neutral300,
  };

  String get _priceLabel => switch (thread.status) {
    NegotiationThreadStatus.open => 'proposition',
    NegotiationThreadStatus.awaitingTrip => 'accord',
    NegotiationThreadStatus.awaitingPayment => 'à payer',
    NegotiationThreadStatus.accepted => 'payé',
    _ => 'terminé',
  };

  String _buildRoute() {
    final dep = thread.departureCity;
    final arr = thread.arrivalCity;
    if (dep != null && arr != null) {
      return '$dep → $arr';
    }
    return thread.isTravelerKgFree
        ? 'Kg libre'
        : '${thread.travelerAvailableKg.toStringAsFixed(0)} kg dispo';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name =
        thread.travelerName ?? 'Voyageur ${thread.travelerId.substring(0, 4)}';
    final rounds = thread.roundsCount.clamp(0, 5);

    // L'expéditeur voit TOUJOURS le prix qu'il paie (net + commission = gross),
    // cash comme stripe ; le voyageur voit son net.
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : authState is AuthProfileUpdated
        ? authState.user.id
        : '';
    final isTraveler = currentUserId == thread.travelerId;
    final displayPrice = isTraveler
        ? thread.currentPriceEur
        : (thread.grossPriceEur ??
              PriceDisplay.grossFromNet(thread.currentPriceEur));

    return Opacity(
          opacity: _isTerminal ? 0.65 : 1.0,
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: () => context.push('/negotiations/${thread.id}'),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(
                    color: _isNew
                        ? DonyColors.primary.withValues(alpha: 0.30)
                        : cs.outline,
                    width: _isNew ? 1.5 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Bande colorée gauche via Positioned (hauteur automatique)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 4, color: _stripColor),
                    ),
                    // Contenu — padding gauche 16 = 4 (strip) + 12 (espacement)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ligne 1 : route + prix
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _buildRoute(),
                                  style: tt.titleLarge?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _isTerminal
                                        ? cs.onSurfaceVariant
                                        : cs.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    PriceDisplay.eur(displayPrice),
                                    style: tt.headlineMedium?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _isTerminal
                                          ? cs.onSurfaceVariant
                                          : cs.onSurface,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    _priceLabel,
                                    style: tt.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Ligne 2 : avatar + nom + badge statut
                          Row(
                            children: [
                              DonyAvatar(
                                name: name,
                                imageUrl: thread.travelerPhotoUrl,
                                size: DonyAvatarSize.sm,
                                verified: (thread.travelerTripsCount ?? 0) > 0,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusPill(status: thread.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Ligne 3 : round dots + méta + badge NOUVEAU
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Container(
                                  width: 16,
                                  height: 3,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: i < rounds
                                        ? (_isTerminal
                                              ? DonyColors.neutral300
                                              : cs.onSurface)
                                        : cs.outline,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  'R.${thread.roundsCount}/5 · ${_timeAgo(thread.lastActivityAt)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_isNew)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DonyColors.primary,
                                    borderRadius: BorderRadius.circular(
                                      DonyRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    'NOUVEAU',
                                    style: tt.bodySmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 220.ms, delay: (50 * index).ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final NegotiationThreadStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      NegotiationThreadStatus.open => (
        'EN COURS',
        DonyColors.primary,
        const Color(0xFFEEF3FF),
      ),
      NegotiationThreadStatus.awaitingTrip => (
        'ATT. TRAJET',
        DonyColors.threadStatusAmber,
        const Color(0xFFFEF3C7),
      ),
      NegotiationThreadStatus.awaitingPayment => (
        'PAIEMENT',
        DonyColors.threadStatusViolet,
        const Color(0xFFF5F3FF),
      ),
      NegotiationThreadStatus.accepted => (
        'ACCEPTÉE',
        DonyColors.threadStatusGreen,
        const Color(0xFFDCFCE7),
      ),
      _ => ('TERMINÉ', const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

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
            const DonyIcon(
              'circle-alert',
              size: 48,
              color: DonyColors.danger500,
            ),
            const SizedBox(height: DonySpacing.sm + 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) {
    return "à l'instant";
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours}h';
  }
  return 'il y a ${diff.inDays}j';
}
