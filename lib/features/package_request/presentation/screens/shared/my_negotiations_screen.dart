import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
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
    getIt<BidNegotiationListBloc>().add(
      const BidNegotiationListFetchRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Aligné sur la tuile « Discussions de prix » du hub Activités : le
      // libellé tapé doit être celui de l'écran qui s'ouvre.
      appBar: const DonyAppBar(title: 'Discussions de prix'),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: ContextualTutorialCard(context: TutorialContext.negotiation),
          ),
          Expanded(
            child: MultiBlocProvider(
              providers: [
                BlocProvider<NegotiationListBloc>.value(
                  value: getIt<NegotiationListBloc>(),
                ),
                BlocProvider<BidNegotiationListBloc>.value(
                  value: getIt<BidNegotiationListBloc>(),
                ),
              ],
              child: const MyNegotiationsBody(),
            ),
          ),
        ],
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
              builder: (context, state) =>
                  BlocBuilder<BidNegotiationListBloc, BidNegotiationListState>(
                    builder: (context, tripState) {
                      // Les deux sources sont indépendantes : tant que l'une a
                      // quelque chose à montrer, l'écran la montre. Chargement,
                      // erreur et vide ne concernent donc que le cas où les deux
                      // sont muettes.
                      final bothEmpty =
                          state.threads.isEmpty && tripState.summaries.isEmpty;
                      final anyLoading =
                          state.status == NegotiationListStatus.loading ||
                          tripState.status == BidNegotiationListStatus.loading;
                      final anyError =
                          state.status == NegotiationListStatus.error ||
                          tripState.status == BidNegotiationListStatus.error;

                      if (bothEmpty && anyLoading) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.lg,
                            DonySpacing.lg,
                            DonySpacing.lg,
                            DonySpacing.huge,
                          ),
                          itemCount: 4,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (_, _) => const DonyUserCardSkeleton(),
                        );
                      }
                      if (bothEmpty && anyError) {
                        return _ErrorState(
                          message:
                              state.errorMessage ??
                              tripState.errorMessage ??
                              'Erreur',
                          onRetry: () {
                            context.read<NegotiationListBloc>().add(
                              const NegotiationListRefreshRequested(),
                            );
                            context.read<BidNegotiationListBloc>().add(
                              const BidNegotiationListRefreshRequested(),
                            );
                          },
                        );
                      }
                      if (bothEmpty) {
                        return const DonyEmptyState(
                          title: 'Aucune négociation',
                          description:
                              "Tes négociations actives apparaîtront ici dès qu'un voyageur fait une offre.",
                          mascotte: DonyMascotteType.assis,
                        );
                      }

                      final all = <NegoEntry>[
                        ...state.threads.map(NegoEntry.fromRequest),
                        ...tripState.summaries.map(NegoEntry.fromTrip),
                      ];
                      final activeCount = all.where((e) => e.isActive).length;
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
                                    active:
                                        filter.preset == NegoQuickFilter.all,
                                    onTap: () => _filterCubit.setPreset(
                                      NegoQuickFilter.all,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.xs + 2),
                                Expanded(
                                  child: _FilterChip(
                                    label: 'En cours ($activeCount)',
                                    active:
                                        filter.preset == NegoQuickFilter.active,
                                    onTap: () => _filterCubit.setPreset(
                                      NegoQuickFilter.active,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.xs + 2),
                                Expanded(
                                  child: _FilterChip(
                                    label: 'Terminées ($terminalCount)',
                                    active:
                                        filter.preset ==
                                        NegoQuickFilter.terminal,
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
                                    onRefresh: () async {
                                      context.read<NegotiationListBloc>().add(
                                        const NegotiationListRefreshRequested(),
                                      );
                                      context.read<BidNegotiationListBloc>().add(
                                        const BidNegotiationListRefreshRequested(),
                                      );
                                    },
                                    child: ListView.separated(
                                      padding: EdgeInsets.fromLTRB(
                                        DonySpacing.base,
                                        DonySpacing.sm,
                                        DonySpacing.base,
                                        MediaQuery.of(context).padding.bottom +
                                            100,
                                      ),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, i) =>
                                          const SizedBox(
                                            height: DonySpacing.sm,
                                          ),
                                      itemBuilder: (_, i) =>
                                          switch (filtered[i]) {
                                            RequestNegoEntry(:final thread) =>
                                              _NegoCard(
                                                thread: thread,
                                                index: i,
                                              ),
                                            TripNegoEntry(:final summary) =>
                                              _TripNegoCard(
                                                summary: summary,
                                                index: i,
                                              ),
                                          },
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
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

  /// Un fil est terminal quand il n'est plus actif sans avoir abouti. Dérivé de
  /// `isActive`, qui fait autorité sur les statuts en cours : réénumérer les
  /// statuts morts ici les ferait diverger au prochain ajout côté serveur.
  bool get _isTerminal =>
      !thread.status.isActive &&
      thread.status != NegotiationThreadStatus.accepted;

  Color get _stripColor => switch (thread.status) {
    NegotiationThreadStatus.open => DonyColors.primary,
    NegotiationThreadStatus.awaitingTrip => DonyColors.threadStatusAmber,
    NegotiationThreadStatus.awaitingPayment => DonyColors.threadStatusViolet,
    NegotiationThreadStatus.awaitingCommission => DonyColors.threadStatusOrange,
    NegotiationThreadStatus.accepted => DonyColors.threadStatusGreen,
    _ => DonyColors.neutral300,
  };

  String get _priceLabel => switch (thread.status) {
    NegotiationThreadStatus.open => 'proposition',
    NegotiationThreadStatus.awaitingTrip => 'accord',
    NegotiationThreadStatus.awaitingPayment => 'à payer',
    NegotiationThreadStatus.awaitingCommission => 'commission due',
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

    return _NegoCardShell(
      stripColor: _stripColor,
      dimmed: _isTerminal,
      highlighted: _isNew,
      index: index,
      onTap: () => context.push('/negotiations/${thread.id}'),
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
                    color: _isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PriceDisplay.money(displayPrice, thread.currency),
                    style: tt.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _isTerminal ? cs.onSurfaceVariant : cs.onSurface,
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
              const _SourcePill(kind: NegoEntryKind.request),
              const SizedBox(width: 4),
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
                        ? (_isTerminal ? DonyColors.neutral300 : cs.onSurface)
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
                    borderRadius: BorderRadius.circular(DonyRadius.full),
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
    );
  }
}

// ── Carte d'une négociation de prix de trajet ────────────────────────────────

/// Pendant de [_NegoCard] pour les fils de trajet.
///
/// Volontairement plus sobre : un résumé de trajet ne porte ni rounds détaillés
/// ni statut de paiement, seulement de quoi reconnaître la discussion et
/// l'ouvrir.
class _TripNegoCard extends StatelessWidget {
  const _TripNegoCard({required this.summary, required this.index});

  final BidNegotiationSummary summary;
  final int index;

  /// Le résumé ne porte que le brut. L'afficher au voyageur lui montrerait un
  /// montant qui n'est pas le sien : côté voyageur, le chiffre attend le fil.
  bool get _showsAmount => summary.role != 'TRAVELER';

  String get _route {
    final dep = summary.departureCity;
    final arr = summary.arrivalCity;
    if (dep != null && arr != null) return '$dep → $arr';
    return 'Trajet';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTerminal = summary.isClosed;

    return _NegoCardShell(
      key: Key('trip-nego-card-${summary.bidId}'),
      stripColor: isTerminal ? DonyColors.neutral300 : DonyColors.primary,
      dimmed: isTerminal,
      highlighted: summary.hasUnread,
      index: index,
      onTap: () => context.push('/bids/${summary.bidId}/negotiation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _route,
                  style: tt.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_showsAmount)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PriceDisplay.money(
                        summary.proposedGrossEur,
                        summary.currency,
                      ),
                      style: tt.headlineMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isTerminal ? cs.onSurfaceVariant : cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      isTerminal ? 'terminé' : 'proposition',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.counterpartyName ?? 'Interlocuteur',
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _SourcePill(kind: NegoEntryKind.trip),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tour ${summary.round} · ${_timeAgo(summary.updatedAt ?? DateTime.now())}',
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chassis commun aux deux cartes ───────────────────────────────────────────

/// Enveloppe partagee par [_NegoCard] et [_TripNegoCard].
///
/// Les deux cartes n affichent pas la meme chose, mais elles sont le meme
/// objet a l ecran : meme bordure, meme bande de statut a gauche, meme
/// estompage une fois le fil termine, meme entree en cascade. Ecrite deux
/// fois, cette identite se serait defaite au premier reglage applique d un
/// seul cote.
class _NegoCardShell extends StatelessWidget {
  const _NegoCardShell({
    super.key,
    required this.stripColor,
    required this.dimmed,
    required this.highlighted,
    required this.onTap,
    required this.index,
    required this.child,
  });

  /// Bande verticale de gauche : la couleur porte le statut du fil.
  final Color stripColor;

  /// Fil termine : la carte reste lisible mais recule.
  final bool dimmed;

  /// Fil qui reclame l attention (non lu, offre fraiche) : bordure accentuee.
  final bool highlighted;

  final VoidCallback onTap;

  /// Rang dans la liste, pour l entree en cascade.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Opacity(
          opacity: dimmed ? 0.65 : 1.0,
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: onTap,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(
                    color: highlighted
                        ? DonyColors.primary.withValues(alpha: 0.30)
                        : cs.outline,
                    width: highlighted ? 1.5 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Bande colorée gauche via Positioned (hauteur automatique)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 4, color: stripColor),
                    ),
                    // Contenu — padding gauche 16 = 4 (strip) + 12 (espacement)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: child,
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

// ── Marqueur de source ───────────────────────────────────────────────────────

/// Distingue les deux natures de discussion mélangées dans la même liste :
/// sans lui, une carte « Paris → Dakar » ne dit pas si l'on négocie sa demande
/// d'envoi ou le prix d'un trajet.
class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.kind});

  final NegoEntryKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTrip = kind == NegoEntryKind.trip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        isTrip ? 'Trajet' : 'Demande',
        style: tt.bodySmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
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
        DonyColors.threadPillAmberFg,
        const Color(0xFFFEF3C7),
      ),
      NegotiationThreadStatus.awaitingPayment => (
        'PAIEMENT',
        DonyColors.threadStatusViolet,
        const Color(0xFFF5F3FF),
      ),
      NegotiationThreadStatus.awaitingCommission => (
        'COMMISSION',
        DonyColors.threadPillOrangeFg,
        const Color(0xFFFFEDD5),
      ),
      NegotiationThreadStatus.accepted => (
        'ACCEPTÉE',
        DonyColors.threadStatusGreen,
        const Color(0xFFDCFCE7),
      ),
      _ => ('TERMINÉ', DonyColors.threadPillNeutralFg, const Color(0xFFF3F4F6)),
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
