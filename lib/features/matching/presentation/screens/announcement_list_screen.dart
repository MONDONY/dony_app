import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _TripsTab { upcoming, history, cancelled }

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<AnnouncementModel> _lastList = [];
  bool _tickerWasActive = false;
  _TripsTab _tab = _TripsTab.upcoming;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.of(context);
    if (isActive && !_tickerWasActive) {
      context.read<AnnouncementBloc>().add(AnnouncementListRequested());
    }
    _tickerWasActive = isActive;
  }

  Future<bool?> _confirmDeleteDialog(BuildContext ctx) {
    return DonyDialog.show(
      ctx,
      title: 'Supprimer ce trajet ?',
      message:
          'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_outline_rounded,
    );
  }

  // Filtrage pur sur statut — pas de fallback date.
  List<AnnouncementModel> _inProgress() =>
      _lastList.where((a) => a.status == 'IN_PROGRESS').toList()
        ..sort((a, b) => a.departureDate.compareTo(b.departureDate));

  List<AnnouncementModel> _filtered() {
    final list = switch (_tab) {
      _TripsTab.upcoming =>
        _lastList.where((a) => a.status == 'ACTIVE' || a.status == 'FULL').toList()
          ..sort((a, b) => a.departureDate.compareTo(b.departureDate)),
      _TripsTab.history =>
        _lastList.where((a) => a.status == 'COMPLETED').toList()
          ..sort((a, b) => b.departureDate.compareTo(a.departureDate)),
      _TripsTab.cancelled =>
        _lastList.where((a) => a.status == 'CANCELLED').toList()
          ..sort((a, b) => b.departureDate.compareTo(a.departureDate)),
    };
    return list;
  }

  ({int upcoming, int history, int cancelled}) _counts() {
    int u = 0, h = 0, c = 0;
    for (final a in _lastList) {
      if (a.status == 'CANCELLED') {
        c++;
      } else if (a.status == 'ACTIVE' || a.status == 'FULL') {
        u++;
      } else if (a.status == 'COMPLETED') {
        h++;
      }
      // IN_PROGRESS shown separately — not counted in tabs
    }
    return (upcoming: u, history: h, cancelled: c);
  }

  String _emptyTitle() => switch (_tab) {
        _TripsTab.upcoming => 'Aucun trajet à venir',
        _TripsTab.history => 'Aucun historique',
        _TripsTab.cancelled => 'Aucune annulation',
      };

  String _emptyDescription() => switch (_tab) {
        _TripsTab.upcoming =>
          'Publiez votre premier trajet et commencez à transporter des colis.',
        _TripsTab.history => 'Vos trajets passés et terminés apparaîtront ici.',
        _TripsTab.cancelled => 'Vos trajets annulés apparaîtront ici.',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(
        title: 'Mes trajets',
        showBackButton: false,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: cs.primary,
        elevation: 2,
        onPressed: () => CreateAnnouncementBottomSheet.show(context),
        child: Icon(Icons.add_rounded, color: cs.onPrimary),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          } else if (state is AnnouncementError && _lastList.isNotEmpty) {
            DonySnackbar.show(context,
                message: state.message, type: DonySnackbarType.error);
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          }
        },
        builder: (context, state) {
          if (state is AnnouncementListLoaded) {
            _lastList = state.announcements;
          }

          if ((state is AnnouncementLoading || state is AnnouncementInitial) &&
              _lastList.isEmpty) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (state is AnnouncementError && _lastList.isEmpty) {
            return _ErrorView(message: state.message);
          }

          final inProgressList = _inProgress();
          final counts = _counts();
          final filtered = _filtered();

          return Column(
            children: [
              // "En cours" section — pinned above tabs, visible only when at least one trip is IN_PROGRESS
              if (inProgressList.isNotEmpty) ...[
                _InProgressSection(announcements: inProgressList, tt: tt, cs: cs),
              ],
              _TabBar(
                current: _tab,
                upcomingCount: counts.upcoming,
                historyCount: counts.history,
                cancelledCount: counts.cancelled,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyView(
                        title: _emptyTitle(),
                        description: _emptyDescription(),
                      )
                    : RefreshIndicator(
                        color: cs.primary,
                        onRefresh: () async => context
                            .read<AnnouncementBloc>()
                            .add(AnnouncementListRequested()),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            DonyLayout.hPadding(context),
                            DonySpacing.md,
                            DonyLayout.hPadding(context),
                            100,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: DonySpacing.md),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isCancelled = item.status == 'CANCELLED';

                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: isCancelled
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              confirmDismiss: isCancelled
                                  ? (_) => _confirmDeleteDialog(context)
                                  : null,
                              onDismissed: (_) {
                                context
                                    .read<AnnouncementBloc>()
                                    .add(AnnouncementDeleteRequested(item.id));
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(
                                    right: DonySpacing.xl),
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.card),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_rounded,
                                        color: cs.onError, size: 26),
                                    const SizedBox(height: DonySpacing.xs),
                                    Text(
                                      'Supprimer',
                                      style: tt.labelMedium?.copyWith(
                                        color: cs.onError,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              child: _AnnouncementCard(
                                announcement: item,
                                index: index,
                                onTap: () async {
                                  await AnnouncementDetailBottomSheet.show(context, announcementId: item.id);
                                  if (context.mounted) {
                                    context
                                        .read<AnnouncementBloc>()
                                        .add(AnnouncementListRequested());
                                  }
                                },
                                onBidsTap: () => context.push(
                                  '/announcements/${item.id}/bids',
                                  extra: {'initialTabIndex': 1},
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── "En cours" pinned section ────────────────────────────────────────────────

class _InProgressSection extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final TextTheme tt;
  final ColorScheme cs;

  const _InProgressSection({
    required this.announcements,
    required this.tt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, DonySpacing.md, h, DonySpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'En cours',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.success,
                  ),
                ),
              ],
            ),
          ),
          ...announcements.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.fromLTRB(h, 0, h, DonySpacing.sm),
                child: _InProgressCard(
                  announcement: e.value,
                  index: e.key,
                  onDetailTap: () async {
                    await AnnouncementDetailBottomSheet.show(context, announcementId: e.value.id);
                    if (context.mounted) {
                      context.read<AnnouncementBloc>().add(AnnouncementListRequested());
                    }
                  },
                  onScanTap: () => context.push('/tracking/scan'),
                  onBidsTap: () => context.push(
                    '/announcements/${e.value.id}/bids',
                    extra: {'initialTabIndex': 1},
                  ),
                ),
              )),
          Divider(height: 1, color: cs.outlineVariant),
        ],
      ),
    );
  }
}

class _InProgressCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final int index;
  final VoidCallback onDetailTap;
  final VoidCallback onScanTap;
  final VoidCallback onBidsTap;

  const _InProgressCard({
    required this.announcement,
    required this.index,
    required this.onDetailTap,
    required this.onScanTap,
    required this.onBidsTap,
  });

  String _formatDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(date);
    final diff = d.difference(today).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Demain';
    if (diff < 0) return 'Parti il y a ${-diff} jour${-diff > 1 ? 's' : ''}';
    return DateFormat('EEE d MMM', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = announcement.totalKg;
    final remaining = announcement.availableKg;
    final booked = (total - remaining).clamp(0, total);
    final progress = total > 0 ? (booked / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onDetailTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.successLight,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.success.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${announcement.departureCity} → ${announcement.arrivalCity}',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDate(announcement.departureDate),
                        style: tt.bodySmall?.copyWith(
                            color: cs.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onScanTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                      border: Border.all(color: cs.success),
                    ),
                    child: Text(
                      'Scanner →',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.success,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: cs.success.withValues(alpha: 0.15),
                valueColor:
                    AlwaysStoppedAnimation<Color>(cs.success),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${booked.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg livrés',
                  style: tt.bodySmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: onBidsTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 12, color: cs.success),
                        const SizedBox(width: 4),
                        Text(
                          'Voir les colis',
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final _TripsTab current;
  final int upcomingCount;
  final int historyCount;
  final int cancelledCount;
  final ValueChanged<_TripsTab> onChanged;

  const _TabBar({
    required this.current,
    required this.upcomingCount,
    required this.historyCount,
    required this.cancelledCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DonyLayout.hPadding(context),
        DonySpacing.md,
        DonyLayout.hPadding(context),
        DonySpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(DonyRadius.xl),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _TabSegment(
              label: 'À venir',
              count: upcomingCount,
              selected: current == _TripsTab.upcoming,
              onTap: () => onChanged(_TripsTab.upcoming),
            ),
            _TabSegment(
              label: 'Historique',
              count: historyCount,
              selected: current == _TripsTab.history,
              onTap: () => onChanged(_TripsTab.history),
            ),
            _TabSegment(
              label: 'Annulés',
              count: cancelledCount,
              selected: current == _TripsTab.cancelled,
              onTap: () => onChanged(_TripsTab.cancelled),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: DonyColors.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Text(
                    '$count',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onTap;
  final VoidCallback? onBidsTap;
  final int index;

  const _AnnouncementCard({
    required this.announcement,
    required this.onTap,
    this.onBidsTap,
    required this.index,
  });

  bool get _hasAcceptedBids =>
      announcement.status == 'COMPLETED' ||
      announcement.status == 'FULL' ||
      announcement.availableKg < announcement.totalKg;

  DonyBadgeType get _badgeType => switch (announcement.status) {
        'ACTIVE' => DonyBadgeType.success,
        'FULL' => DonyBadgeType.warning,
        'IN_PROGRESS' => DonyBadgeType.success,
        'COMPLETED' => DonyBadgeType.info,
        'CANCELLED' => DonyBadgeType.error,
        _ => DonyBadgeType.info,
      };

  String get _statusLabel => switch (announcement.status) {
        'ACTIVE' => 'Actif',
        'FULL' => 'Complet',
        'IN_PROGRESS' => 'En cours',
        'COMPLETED' => 'Terminé',
        'CANCELLED' => 'Annulé',
        _ => announcement.status,
      };

  String _formatDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(date);
    final diff = d.difference(today).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Demain';
    if (diff > 1 && diff <= 6) return 'Dans $diff jours';
    return DateFormat('EEE d MMM yyyy', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateLabel = _formatDate(announcement.departureDate);
    final total = announcement.totalKg;
    final remaining = announcement.availableKg;
    final booked = (total - remaining).clamp(0, total);
    final progress = total > 0 ? (booked / total).clamp(0.0, 1.0) : 0.0;
    final bidsCount = announcement.bidsCount ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
          boxShadow: [
            BoxShadow(
              color: DonyColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [DonyColors.blue700, cs.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.flight_takeoff_rounded,
                        color: cs.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '${announcement.departureCity} → ${announcement.arrivalCity}',
                                style: tt.titleMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            DonyBadge(label: _statusLabel, type: _badgeType),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateLabel,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? DonyColors.violet
                        : cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${booked.toStringAsFixed(0)} kg réservés sur ${total.toStringAsFixed(0)} kg',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                    style: tt.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (bidsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DonyColors.violetLight,
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_rounded,
                              size: 12, color: DonyColors.violet),
                          const SizedBox(width: 4),
                          Text(
                            '$bidsCount demande${bidsCount > 1 ? 's' : ''}',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DonyColors.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _hasAcceptedBids ? onBidsTap : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Text(
                        _hasAcceptedBids ? 'Voir les colis →' : 'Gérer →',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 60 * index),
          ).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Impossible de charger vos trajets',
              style: tt.titleLarge?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              onPressed: () => context
                  .read<AnnouncementBloc>()
                  .add(AnnouncementListRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String description;
  const _EmptyView({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.xl),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 48,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: DonySpacing.lg),
            Text(
              title,
              style: tt.headlineMedium?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              description,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}
