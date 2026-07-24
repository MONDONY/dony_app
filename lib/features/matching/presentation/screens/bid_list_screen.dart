import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── Status constants (demandes « à traiter ») ─────────────────────────────────
const _kPending = 'PENDING';
const _kPaymentEscrowed = 'PAYMENT_ESCROWED';

// ─────────────────────────────────────────────────────────────────────────────
// BidListScreen — liste des demandes reçues sur une annonce (vue voyageur).
// Un seul écran : les demandes acceptées / en cours / clôturées, avec recherche
// et filtres. Les demandes « à traiter » (en attente) sont accessibles via le
// bouton de l'app bar → PendingBidsScreen.
// ─────────────────────────────────────────────────────────────────────────────

class BidListScreen extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;

  /// Conservé pour compatibilité de route. Ignoré depuis la suppression des
  /// onglets (un seul écran désormais).
  final int initialTabIndex;

  /// Titre de l'app bar. « Demandes » par défaut ; « Colis » quand l'écran est
  /// ouvert depuis le bouton « Colis » du détail trajet.
  final String title;

  const BidListScreen({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
    this.title = 'Demandes',
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<BidBloc>()..add(BidListRequested(announcementId)),
        ),
        BlocProvider(create: (_) => getIt<BidListFilterCubit>()),
      ],
      child: _BidListView(
        announcementId: announcementId,
        departureCityCode: departureCityCode,
        arrivalCityCode: arrivalCityCode,
        departureDate: departureDate,
        title: title,
      ),
    );
  }
}

/// Variante de test : `BidBloc` doit être fourni par le contexte parent.
/// `BidListFilterCubit` est créé ici (Cubit déterministe). Utilisé en tests.
@visibleForTesting
class BidListScreenTesting extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final String title;

  const BidListScreenTesting({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.title = 'Demandes',
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BidListFilterCubit(),
    child: _BidListView(
      announcementId: announcementId,
      departureCityCode: departureCityCode,
      arrivalCityCode: arrivalCityCode,
      departureDate: departureDate,
      title: title,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidListView — app bar (titre + bouton À traiter + Scanner) + liste
// ─────────────────────────────────────────────────────────────────────────────

class _BidListView extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final String title;

  const _BidListView({
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.title = 'Demandes',
  });

  String _buildSubtitle() {
    final parts = <String>[];
    if (departureCityCode != null && arrivalCityCode != null) {
      parts.add('$departureCityCode → $arrivalCityCode');
    }
    if (departureDate != null) {
      parts.add(DateFormat('EEE d MMMM', 'fr').format(departureDate!));
    }
    return parts.join(' · ');
  }

  Future<void> _openPending(BuildContext context) async {
    await context.push('/announcements/$announcementId/bids/pending');
    if (context.mounted) {
      context.read<BidBloc>().add(BidListRequested(announcementId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = _buildSubtitle();

    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidNotFound) {
          DonySnackbar.show(
            context,
            message: 'Cette annonce n\'existe plus',
            type: DonySnackbarType.warning,
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      builder: (context, state) {
        final allBids = state is BidListLoaded ? state.bids : <BidModel>[];
        final pendingCount = allBids
            .where(
              (b) => b.status == _kPending || b.status == _kPaymentEscrowed,
            )
            .length;
        final acceptedBids = allBids.where(isAcceptedTabBid).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: const DonyAppBarBackButton(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: tt.headlineLarge),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: DonySpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pendingCount > 0) ...[
                      _PendingTodoButton(
                        count: pendingCount,
                        onTap: () => _openPending(context),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                    ],
                    _ScannerChipButton(
                      onTap: () => context.push('/tracking/scan'),
                    ),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: cs.outline, height: 1),
            ),
          ),
          body: _buildBody(context, state, acceptedBids),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    BidState state,
    List<BidModel> acceptedBids,
  ) {
    if (state is BidLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (state is BidError) {
      return BidListErrorView(
        message: ErrorPresenter.resolve(state.error).message,
        onRetry: () =>
            context.read<BidBloc>().add(BidListRequested(announcementId)),
      );
    }

    if (state is BidListLoaded) {
      return _AcceptedList(
        acceptedBids: acceptedBids,
        announcementId: announcementId,
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingTodoButton — pill « À traiter » + badge compteur (app bar)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTodoButton extends StatelessWidget {
  const _PendingTodoButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$count demande${count > 1 ? 's' : ''} à traiter',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('inbox', size: 16, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'À traiter',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AcceptedList — recherche + filtre + liste des demandes acceptées / clôturées
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptedList extends StatefulWidget {
  final List<BidModel> acceptedBids;
  final String announcementId;
  const _AcceptedList({
    required this.acceptedBids,
    required this.announcementId,
  });

  @override
  State<_AcceptedList> createState() => _AcceptedListState();
}

class _AcceptedListState extends State<_AcceptedList> {
  /// L'animation en cascade ne se joue qu'au premier affichage de la liste,
  /// jamais à chaque frappe de recherche (sinon scintillement).
  bool _hasAnimatedOnce = false;

  @override
  Widget build(BuildContext context) {
    if (widget.acceptedBids.isEmpty) {
      return const DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande acceptée',
        description: "Vous n'avez accepté aucune demande pour l'instant.",
      ).animate().fadeIn(duration: 300.ms);
    }

    return BlocBuilder<BidListFilterCubit, BidListFilterState>(
      builder: (context, filter) {
        final queryFiltered = widget.acceptedBids
            .where((b) => bidMatchesQuery(b, filter.query))
            .toList();
        final allCount = queryFiltered.length;
        final activeCount = queryFiltered.where(isActiveBid).length;
        final closedCount = queryFiltered.where(isClosedBid).length;

        List<BidModel> displayed;
        switch (filter.filter) {
          case AcceptedStatusFilter.all:
            displayed = queryFiltered;
          case AcceptedStatusFilter.active:
            displayed = queryFiltered.where(isActiveBid).toList();
          case AcceptedStatusFilter.closed:
            displayed = queryFiltered.where(isClosedBid).toList();
        }
        displayed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final animate = !_hasAnimatedOnce;
        if (animate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hasAnimatedOnce = true;
          });
        }

        final hp = DonyLayout.hPadding(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            hp,
            DonySpacing.base,
            hp,
            DonySpacing.huge,
          ),
          children: [
            const _BidSearchField(),
            const SizedBox(height: DonySpacing.md),
            _StatusFilterChips(
              active: filter.filter,
              allCount: allCount,
              activeCount: activeCount,
              closedCount: closedCount,
            ),
            const SizedBox(height: DonySpacing.base),
            if (displayed.isEmpty)
              _SearchEmptyState(query: filter.query)
            else
              for (var i = 0; i < displayed.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == displayed.length - 1 ? 0 : DonySpacing.md,
                  ),
                  child: _maybeAnimate(
                    animate,
                    i,
                    BidCard(
                      bid: displayed[i],
                      isProcessing: false,
                      query: filter.query,
                      onTap: () => _openDetail(context, displayed[i]),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _maybeAnimate(bool animate, int index, Widget card) {
    if (!animate) return card;
    return card
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  // Recharge la liste au retour du détail : le statut d'un bid accepté peut
  // évoluer (confirmation de présence, scan, annulation) et l'écran doit se
  // mettre à jour seul (règle CLAUDE.md — rafraîchissement après navigation).
  Future<void> _openDetail(BuildContext context, BidModel bid) async {
    await context.push('/bids/${bid.id}', extra: bid);
    if (context.mounted) {
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidSearchField — barre de recherche (nom / n° de suivi)
// ─────────────────────────────────────────────────────────────────────────────

class _BidSearchField extends StatelessWidget {
  const _BidSearchField();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return DonySearchField(
      hint: 'Nom ou n° de suivi…',
      onChanged: cubit.setQuery,
      onClear: () => cubit.setQuery(''),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusFilterChips — chips Tous / Actifs / Clôturés
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  final AcceptedStatusFilter active;
  final int allCount;
  final int activeCount;
  final int closedCount;

  const _StatusFilterChips({
    required this.active,
    required this.allCount,
    required this.activeCount,
    required this.closedCount,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: [
        DonyChip(
          label: 'Tous ($allCount)',
          selected: active == AcceptedStatusFilter.all,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.all),
        ),
        DonyChip(
          label: 'Actifs ($activeCount)',
          selected: active == AcceptedStatusFilter.active,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.active),
        ),
        DonyChip(
          label: 'Clôturés ($closedCount)',
          selected: active == AcceptedStatusFilter.closed,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.closed),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchEmptyState — état vide quand recherche/filtre sans résultat
// ─────────────────────────────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxl),
      child: Column(
        children: [
          hasQuery
              ? DonyIcon('search-x', size: 44, color: cs.outlineVariant)
              : const DonyEmoji.parcel(size: 44),
          const SizedBox(height: DonySpacing.md),
          Text(
            hasQuery ? 'Aucun résultat' : 'Aucun envoi',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            hasQuery
                ? 'Aucun envoi ne correspond à « ${query.trim()} ».'
                : 'Aucun envoi dans cette catégorie.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScannerChipButton — chip QR scanner dans l'AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerChipButton extends StatelessWidget {
  const _ScannerChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('scan-line', size: 16, color: cs.onSurface),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Lire le QR',
              style: tt.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
