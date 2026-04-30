import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<AnnouncementModel> _lastList = [];
  bool _tickerWasActive = false;

  // Détecte l'activation du tab (StatefulShellRoute.indexedStack change
  // TickerMode pour le branch inactif → actif, ce qui appelle didChangeDependencies).
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasAnnouncements = _lastList.isNotEmpty;

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Mes trajets',
        showBackButton: false,
        actions: hasAnnouncements
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: DonySpacing.md),
                  child: TextButton.icon(
                    icon: Icon(Icons.add_rounded, size: 17, color: cs.primary),
                    label: Text(
                      'Nouveau trajet',
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => context.push('/announcements/create'),
                  ),
                ),
              ]
            : null,
      ),
      // FAB icône seule sur l'état vide pour permettre la création du premier trajet
      floatingActionButton: hasAnnouncements
          ? null
          : FloatingActionButton(
              backgroundColor: cs.primary,
              elevation: 2,
              onPressed: () => context.push('/announcements/create'),
              child: Icon(Icons.add_rounded, color: cs.onPrimary),
            ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          } else if (state is AnnouncementError && _lastList.isNotEmpty) {
            DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          }
        },
        builder: (context, state) {
          if (state is AnnouncementListLoaded) {
            _lastList = state.announcements;
          }

          if ((state is AnnouncementLoading || state is AnnouncementInitial) &&
              _lastList.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: cs.primary),
            );
          }

          if (state is AnnouncementError && _lastList.isEmpty) {
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
                      state.message,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      onPressed: () =>
                          context.read<AnnouncementBloc>().add(AnnouncementListRequested()),
                    ),
                  ],
                ),
              ),
            );
          }

          final list = _lastList;

          if (list.isEmpty) {
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
                      'Aucun trajet publié',
                      style: tt.headlineMedium?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      'Publiez votre premier trajet et commencez à transporter des colis.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn();
          }

          return RefreshIndicator(
            color: cs.primary,
            onRefresh: () async =>
                context.read<AnnouncementBloc>().add(AnnouncementListRequested()),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                DonyLayout.hPadding(context), DonySpacing.lg, DonyLayout.hPadding(context), 100,
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.md),
              itemBuilder: (context, index) {
                final item = list[index];
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
                    padding: const EdgeInsets.only(right: DonySpacing.xl),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, color: cs.onError, size: 26),
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
                    departureCity: item.departureCity,
                    arrivalCity: item.arrivalCity,
                    departureDate: item.departureDate,
                    availableKg: item.availableKg,
                    pricePerKg: item.pricePerKg,
                    status: item.status,
                    bidsCount: item.bidsCount ?? 0,
                    onTap: () async {
                      await context.push('/announcements/${item.id}');
                      if (context.mounted) {
                        context
                            .read<AnnouncementBloc>()
                            .add(AnnouncementListRequested());
                      }
                    },
                    index: index,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;
  final String status;
  final int bidsCount;
  final VoidCallback onTap;
  final int index;

  const _AnnouncementCard({
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
    required this.status,
    required this.bidsCount,
    required this.onTap,
    required this.index,
  });

  DonyBadgeType get _badgeType => switch (status) {
        'ACTIVE' => DonyBadgeType.success,
        'FULL' => DonyBadgeType.warning,
        'COMPLETED' => DonyBadgeType.info,
        'CANCELLED' => DonyBadgeType.error,
        _ => DonyBadgeType.info,
      };

  String get _statusLabel => switch (status) {
        'ACTIVE' => 'Actif',
        'FULL' => 'Complet',
        'COMPLETED' => 'Terminé',
        'CANCELLED' => 'Annulé',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr = DateFormat('EEE d MMM yyyy', 'fr').format(departureDate);

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône trajet (remplace l'avatar dans la vue expéditeur)
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
                    // Ligne 1 : route + badge statut
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '$departureCity → $arrivalCity',
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

                    // Ligne 2 : date
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),

                    // Ligne 3 : capacité + prix + demandes + gérer
                    Row(
                      children: [
                        // Chips à gauche : flexibles pour ne pas déborder
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _InfoChip(
                                icon: Icons.scale_rounded,
                                label: '${availableKg.toStringAsFixed(0)} kg',
                              ),
                              _InfoChip(
                                icon: Icons.euro_rounded,
                                label: '${pricePerKg.toStringAsFixed(0)}/kg',
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        // Badge demandes + bouton Gérer ancrés à droite
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bidsCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DonyColors.violetLight,
                                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inbox_rounded,
                                        size: 11, color: DonyColors.violet),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$bidsCount',
                                      style: tt.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: DonyColors.violet,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(DonyRadius.sm),
                                border: Border.all(color: cs.primary),
                              ),
                              child: Text(
                                'Gérer →',
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoChip({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: highlight ? null : Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 13,
              color: highlight ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: highlight ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
